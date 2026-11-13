import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../application/session_controller.dart';
import '../data/exercise_repository.dart';
import '../domain/session_models.dart';

String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String _kg(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Active workout: pick exercises, log sets, rest timer, finish with XP.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({required this.workoutId, super.key});

  /// `new` starts a fresh workout; an active session is always resumed first.
  final String workoutId;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _rpe = TextEditingController();
  final _duration = TextEditingController();

  Timer? _tick;
  Timer? _restTimer;
  int _restRemaining = 0;
  bool _busy = false;
  String? _error;
  String? _prefilledFor;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _restTimer?.cancel();
    _weight.dispose();
    _reps.dispose();
    _rpe.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final signIn = context.t('workout:spSignIn');
    final controller = ref.read(sessionControllerProvider.notifier);
    final resumed = await controller.restore();
    if (resumed) {
      return;
    }
    final started = await controller.start('Workout');
    if (!started && mounted) {
      setState(() => _error = signIn);
    }
  }

  Future<void> _prefill(SessionExercise exercise) async {
    _prefilledFor = exercise.exerciseId;
    _weight.clear();
    _reps.clear();
    _rpe.clear();
    _duration.clear();
    final previous =
        await ref.read(previousSetsProvider(exercise.exerciseId).future);
    if (!mounted || _prefilledFor != exercise.exerciseId) {
      return;
    }
    final hint = suggestOverload(previous);
    if (hint == null) {
      return;
    }
    final weight = hint.suggestedWeightKg ?? hint.lastWeightKg;
    if (weight != null && weight > 0) {
      _weight.text = _kg(weight);
    }
    if (hint.lastReps != null) {
      _reps.text = '${hint.lastReps}';
    }
  }

  Future<void> _logSet(SessionExercise exercise) async {
    final weight = double.tryParse(_weight.text.trim());
    final reps = int.tryParse(_reps.text.trim());
    final rpe = double.tryParse(_rpe.text.trim());
    final seconds = int.tryParse(_duration.text.trim());
    final errDuration = context.t('workout:wsErrDuration');
    final errReps = context.t('workout:wsErrReps');
    final errWeight = context.t('workout:wsErrWeight');
    final errRpe = context.t('workout:wsErrRpe');
    final errLog = context.t('workout:wsErrLog');
    final prToast = context.t('workout:wsPrToast');
    final messenger = ScaffoldMessenger.of(context);

    String? problem;
    switch (exercise.logType) {
      case 'duration':
        if (seconds == null || seconds <= 0) {
          problem = errDuration;
        }
      case 'reps_only':
        if (reps == null || reps <= 0) {
          problem = errReps;
        }
      default:
        if (reps == null || reps <= 0) {
          problem = errReps;
        } else if (weight == null || weight < 0) {
          problem = errWeight;
        }
    }
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      problem = errRpe;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(sessionControllerProvider.notifier).logSet(
            weightKg: exercise.logType == 'weight_reps' ? weight : null,
            reps: exercise.logType == 'duration' ? null : reps,
            rpe: rpe,
            durationSeconds: exercise.logType == 'duration' ? seconds : null,
          );
      if (!mounted) {
        return;
      }
      HapticFeedback.lightImpact();
      if (result != null && result.isPersonalRecord) {
        messenger.showSnackBar(SnackBar(content: Text(prToast)));
      }
      await _startRest();
    } catch (_) {
      if (mounted) {
        setState(() => _error = errLog);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startRest() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('fittrack_default_rest') ?? 90;
    _restTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _restRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restRemaining <= 1) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        setState(() => _restRemaining = 0);
      } else {
        setState(() => _restRemaining -= 1);
      }
    });
  }

  void _adjustRest(int delta) {
    if (_restRemaining <= 0) {
      return;
    }
    setState(() => _restRemaining = (_restRemaining + delta).clamp(1, 3600));
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  Future<void> _addExercise() async {
    final picked = await showFitTrackSheet<Exercise>(
      context: context,
      builder: (_) => const _ExercisePicker(),
    );
    if (picked == null) {
      return;
    }
    await ref.read(sessionControllerProvider.notifier).addExercise(picked);
  }

  Future<void> _finish() async {
    final session = ref.read(sessionControllerProvider);
    if (session == null) {
      return;
    }
    final errFinish = context.t('workout:wsErrFinish');
    final confirmed = await showFitTrackConfirm(
      context: context,
      title: context.t('workout:wsFinishTitle'),
      message: session.totalSets == 0
          ? context.t('workout:wsFinishNone')
          : context.t('workout:wsFinishSets', args: {'count': session.totalSets}),
      confirmLabel: context.t('workout:wsFinish'),
      cancelLabel: context.t('workout:wsKeepGoing'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final summary =
          await ref.read(sessionControllerProvider.notifier).finish();
      if (!mounted) {
        return;
      }
      if (summary != null) {
        await _showSummary(summary);
      }
      if (mounted) {
        context.go('/workout');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errFinish;
        });
      }
    }
  }

  Future<void> _showSummary(SessionSummary summary) {
    return showFitTrackSheet<void>(
      context: context,
      builder: (ctx) => _SummarySheet(summary: summary),
    );
  }

  Future<void> _discard() async {
    final confirmed = await showFitTrackConfirm(
      context: context,
      title: context.t('workout:wsDiscardTitle'),
      message: context.t('workout:wsDiscardMsg'),
      confirmLabel: context.t('workout:wsDiscard'),
      cancelLabel: context.t('common:cancel'),
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(sessionControllerProvider.notifier).discard();
    if (mounted) {
      context.go('/workout');
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/workout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final session = ref.watch(sessionControllerProvider);
    final back = FitTrackIconButton(
      icon: Icons.arrow_back,
      color: c.ink,
      semanticLabel: context.t('settings:backLabel'),
      onPressed: _leave,
    );

    if (session == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.header,
          foregroundColor: c.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: c.line)),
          leading: back,
          title: Text(
            context.t('workout:wsTitle'),
            style: FitTrackText.titleLg.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: _error == null
              ? CircularProgressIndicator(color: c.accent)
              : Padding(
                  padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: FitTrackText.body.copyWith(color: c.muted),
                  ),
                ),
        ),
      );
    }

    final exercise = session.current;
    if (exercise != null && _prefilledFor != exercise.exerciseId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prefill(exercise);
        }
      });
    }

    // Exercises before and after the current one render as compact rows;
    // the current one expands into the logging card.
    final children = <Widget>[];
    var pending = <Widget>[];
    void flush() {
      if (pending.isEmpty) {
        return;
      }
      final rows = pending;
      pending = [];
      children
        ..add(const SizedBox(height: FitTrackSpacing.md))
        ..add(FitTrackCard(
          padding: EdgeInsets.zero,
          child: Column(children: rows),
        ));
    }

    for (var i = 0; i < session.exercises.length; i++) {
      if (i == session.currentIndex && exercise != null) {
        flush();
        children
          ..add(const SizedBox(height: FitTrackSpacing.md))
          ..add(_ExerciseCard(
            exercise: exercise,
            weight: _weight,
            reps: _reps,
            rpe: _rpe,
            duration: _duration,
            busy: _busy,
            error: _error,
            onLog: () => unawaited(_logSet(exercise)),
            onRemove: (id) =>
                ref.read(sessionControllerProvider.notifier).removeSet(id),
          ));
      } else {
        pending.add(_ExerciseRow(
          exercise: session.exercises[i],
          first: pending.isEmpty,
          onTap: () => ref.read(sessionControllerProvider.notifier).select(i),
        ));
      }
    }
    flush();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: c.line)),
        leading: back,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                session.name,
                style: FitTrackText.titleLg.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              context.t(
                'workout:wsElapsed',
                args: {
                  'time': _clock(DateTime.now().difference(session.startedAt)),
                },
              ),
              style: FitTrackText.label.copyWith(color: c.muted),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.t('workout:sdMore'),
            icon: Icon(Icons.more_vert, color: c.ink),
            color: c.surface,
            onSelected: (value) {
              if (value == 'discard') {
                unawaited(_discard());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'discard',
                child: Text(
                  context.t('workout:wsMenuDiscard'),
                  style: TextStyle(color: c.textBad),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: FitTrackSpacing.sm),
            child: FitTrackButton(
              label: context.t('workout:wsFinish'),
              size: FitTrackButtonSize.sm,
              onPressed: _busy ? null : () => unawaited(_finish()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.md,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xxl,
                ),
                children: [
                  _StatsRow(session: session),
                  if (exercise == null) ...[
                    const SizedBox(height: FitTrackSpacing.md),
                    _EmptyState(onAdd: _addExercise),
                  ],
                  ...children,
                  if (exercise != null) ...[
                    const SizedBox(height: FitTrackSpacing.md),
                    FitTrackButton(
                      label: context.t('workout:reAdd'),
                      icon: Icons.add,
                      variant: FitTrackButtonVariant.secondary,
                      size: FitTrackButtonSize.lg,
                      fullWidth: true,
                      onPressed: _addExercise,
                    ),
                  ],
                ],
              ),
            ),
            if (_restRemaining > 0)
              _RestBar(
                seconds: _restRemaining,
                onAdjust: _adjustRest,
                onSkip: _skipRest,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    Widget cell(String label, String value, String unit, {bool first = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FitTrackSpacing.md + 2,
            vertical: FitTrackSpacing.md,
          ),
          decoration: BoxDecoration(
            border: first
                ? null
                : BorderDirectional(start: BorderSide(color: c.line)),
          ),
          child: Semantics(
            container: true,
            label: '$label, $value $unit',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: FitTrackText.caption.copyWith(
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xs),
                  Text.rich(
                    TextSpan(
                      text: value,
                      style: FitTrackText.stat.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: ' $unit',
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FitTrackRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          cell(
            context.t('workout:volumeLabel'),
            _kg(session.volumeKg),
            context.t('workout:kgUnit'),
            first: true,
          ),
          cell(
            context.t('workout:sdSets'),
            '${session.totalSets}',
            context.t('workout:wsLoggedUnit'),
          ),
          cell(
            context.t('workout:sdRecords'),
            '${session.prCount}',
            context.t('workout:prBadge'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.first,
    required this.onTap,
  });

  final SessionExercise exercise;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final done = exercise.sets.isNotEmpty;
    final hasPr = exercise.sets.any((s) => s.isPersonalRecord);
    final meta = done
        ? context.t(
            'workout:wsSetsMeta',
            args: {
              'count': exercise.sets.length,
              'group': exercise.muscleGroup,
            },
          )
        : exercise.muscleGroup;
    return Semantics(
      button: true,
      label: '${exercise.name}, $meta',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.md + 2,
              vertical: FitTrackSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: first ? null : Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: FitTrackText.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasPr) ...[
                  FitTrackBadge(
                    label: context.t('workout:prBadge'),
                    tone: FitTrackBadgeTone.warn,
                    icon: Icons.emoji_events_outlined,
                  ),
                  const SizedBox(width: FitTrackSpacing.sm),
                ],
                if (done)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.ok,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 16, color: c.bg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: const EdgeInsets.all(FitTrackSpacing.xxl),
      child: Column(
        children: [
          Text(
            context.t('workout:wsEmptyTitle'),
            style: FitTrackText.title.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: FitTrackSpacing.xs),
          Text(
            context.t('workout:wsEmptySub'),
            textAlign: TextAlign.center,
            style: FitTrackText.body.copyWith(color: c.muted),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          FitTrackButton(
            label: context.t('workout:reAdd'),
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.rpe,
    required this.duration,
    required this.busy,
    required this.error,
    required this.onLog,
    required this.onRemove,
  });

  final SessionExercise exercise;
  final TextEditingController weight;
  final TextEditingController reps;
  final TextEditingController rpe;
  final TextEditingController duration;
  final bool busy;
  final String? error;
  final VoidCallback onLog;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final previous = ref.watch(previousSetsProvider(exercise.exerciseId));
    final hint = previous.valueOrNull == null
        ? null
        : suggestOverload(previous.valueOrNull!);
    final showHint = hint != null &&
        hint.lastWeightKg != null &&
        hint.lastReps != null;
    final tryWeight = hint?.suggestedWeightKg;
    final hintText = !showHint
        ? null
        : [
            context.t(
              'workout:wsLast',
              args: {'weight': _kg(hint.lastWeightKg!), 'reps': hint.lastReps!},
            ),
            if (tryWeight != null && tryWeight != hint.lastWeightKg)
              context.t('workout:wsTry', args: {'weight': _kg(tryWeight)}),
          ].join('  ·  ');

    Widget field(TextEditingController ctl, String label, {bool decimal = false}) {
      return Expanded(
        child: FitTrackTextField(
          label: label,
          controller: ctl,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FitTrackRadius.lg),
        border: Border.all(color: c.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitTrackSpacing.md + 2,
              FitTrackSpacing.md,
              FitTrackSpacing.md + 2,
              FitTrackSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          exercise.name,
                          style: FitTrackText.titleLg.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      context.t(
                        'workout:wsSetsLogged',
                        args: {'count': exercise.sets.length},
                      ),
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
                if (exercise.muscleGroup.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    exercise.muscleGroup,
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
                if (hintText != null) ...[
                  const SizedBox(height: FitTrackSpacing.sm + 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: FitTrackSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentTint,
                      borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                    ),
                    child: Text(
                      hintText,
                      style: FitTrackText.label.copyWith(color: c.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (exercise.sets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FitTrackSpacing.md + 2,
              ),
              child: Column(
                children: [
                  for (final set in exercise.sets)
                    _SetRow(
                      set: set,
                      logType: exercise.logType,
                      onRemove: () => onRemove(set.id),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitTrackSpacing.md + 2,
              FitTrackSpacing.sm,
              FitTrackSpacing.md + 2,
              FitTrackSpacing.md + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exercise.logType == 'weight_reps') ...[
                      field(
                        weight,
                        context.t('workout:wsKgLabel'),
                        decimal: true,
                      ),
                      const SizedBox(width: FitTrackSpacing.sm),
                    ],
                    if (exercise.logType != 'duration')
                      field(reps, context.t('workout:wsRepsLabel'))
                    else
                      field(duration, context.t('workout:wsSecondsLabel')),
                    const SizedBox(width: FitTrackSpacing.sm),
                    field(rpe, context.t('workout:wsRpeLabel'), decimal: true),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: FitTrackSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 16, color: c.textBad),
                      const SizedBox(width: FitTrackSpacing.xs + 2),
                      Expanded(
                        child: Text(
                          error!,
                          style: FitTrackText.caption.copyWith(color: c.textBad),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackButton(
                  label: context.t(
                    'workout:wsLogSet',
                    args: {'n': exercise.nextSetNumber},
                  ),
                  icon: Icons.check,
                  fullWidth: true,
                  loading: busy,
                  onPressed: busy ? null : onLog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.logType,
    required this.onRemove,
  });

  final SessionSet set;
  final String logType;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final kg = context.t('workout:kgUnit');
    final detail = switch (logType) {
      'duration' =>
        context.t('workout:wsSecs', args: {'n': set.durationSeconds ?? 0}),
      'reps_only' =>
        context.t('workout:wsRepsN', args: {'n': set.reps ?? 0}),
      _ => '${_kg(set.weightKg ?? 0)} $kg × ${set.reps ?? 0}',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${set.setNumber}',
              style: FitTrackText.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: FitTrackText.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (set.rpe != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: FitTrackSpacing.sm,
              ),
              child: Text(
                context.t('workout:wsRpeValue', args: {'value': _kg(set.rpe!)}),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ),
          if (set.isPersonalRecord)
            FitTrackBadge(
              label: context.t('workout:prBadge'),
              tone: FitTrackBadgeTone.warn,
              icon: Icons.emoji_events_outlined,
            ),
          FitTrackIconButton(
            icon: Icons.close,
            color: c.muted,
            semanticLabel:
                context.t('workout:wsDeleteSet', args: {'n': set.setNumber}),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Dark rest-timer bar pinned above the system inset; stays dark in both
/// themes, as in the design.
class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.seconds,
    required this.onAdjust,
    required this.onSkip,
  });

  final int seconds;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    const onDark = AppColors.darkText;
    const outline = AppColors.darkBorder2;

    Widget action(String label, String semantic, VoidCallback onTap,
        {bool filled = false}) {
      return Semantics(
        button: true,
        label: semantic,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FitTrackRadius.sm),
            child: Container(
              height: FitTrackSpacing.touchMin,
              constraints: const BoxConstraints(minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? onDark : Colors.transparent,
                borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                border: Border.all(color: filled ? onDark : outline),
              ),
              child: Text(
                label,
                style: FitTrackText.label.copyWith(
                  color: filled ? AppColors.darkBg : onDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FitTrackSpacing.lg,
        vertical: FitTrackSpacing.md,
      ),
      decoration: const BoxDecoration(color: AppColors.darkBg),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label:
                  '${context.t('workout:wsRest')}, ${_clock(Duration(seconds: seconds))}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('workout:wsRest'),
                      style: FitTrackText.caption.copyWith(
                        color: AppColors.darkMuted,
                      ),
                    ),
                    Text(
                      _clock(Duration(seconds: seconds)),
                      style: FitTrackText.stat.copyWith(
                        color: onDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          action('−15s', context.t('workout:wsRestMinus'), () => onAdjust(-15)),
          const SizedBox(width: FitTrackSpacing.sm),
          action('+15s', context.t('workout:wsRestPlus'), () => onAdjust(15)),
          const SizedBox(width: FitTrackSpacing.sm),
          action(
            context.t('workout:wsSkip'),
            context.t('workout:wsSkip'),
            onSkip,
            filled: true,
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet summary shown after finishing a workout.
class _SummarySheet extends StatelessWidget {
  const _SummarySheet({required this.summary});
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);

    Widget row(String label, String value) => Container(
          constraints: const BoxConstraints(minHeight: FitTrackSpacing.touchMin),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: FitTrackText.body.copyWith(color: c.ink)),
              Text(
                value,
                style: FitTrackText.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: '${context.t('workout:sdComplete')}, '
              '+${summary.xpEarned} ${context.t('workout:sdXpEarned')}',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(FitTrackSpacing.md + 2),
              decoration: BoxDecoration(
                color: c.ok,
                borderRadius: BorderRadius.circular(FitTrackRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('workout:sdComplete'),
                    style: FitTrackText.caption.copyWith(
                      color: c.bg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '+${summary.xpEarned}',
                        style: FitTrackText.hero.copyWith(
                          color: c.bg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: FitTrackSpacing.sm),
                      Text(
                        context.t('workout:sdXpEarned'),
                        style: FitTrackText.body.copyWith(color: c.bg),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: FitTrackSpacing.md),
        row(context.t('workout:sdDuration'), _clock(summary.duration)),
        row(context.t('workout:sdSets'), '${summary.totalSets}'),
        row(
          context.t('workout:volumeLabel'),
          '${_kg(summary.volumeKg)} ${context.t('workout:kgUnit')}',
        ),
        if (summary.prCount > 0)
          row(context.t('workout:sdRecords'), '${summary.prCount}'),
        const SizedBox(height: FitTrackSpacing.lg),
        FitTrackButton(
          label: context.t('workout:sdDone'),
          size: FitTrackButtonSize.lg,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Searchable exercise library, filtered by muscle group.
class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  static const _groups = [
    'chest',
    'back',
    'legs',
    'shoulders',
    'arms',
    'core',
    'glutes',
    'cardio',
  ];

  late final Future<List<Exercise>> _future;
  String _query = '';
  String? _group;

  @override
  void initState() {
    super.initState();
    final service = ref.read(workoutServiceProvider);
    _future = service == null ? Future.value(const []) : service.exercises();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            FitTrackTextField(
              label: context.t('workout:rePickSearch'),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: FitTrackSpacing.sm),
            SizedBox(
              height: FitTrackSpacing.touchMin,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final g in _groups)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: FitTrackSpacing.sm,
                      ),
                      child: FitTrackChip(
                        label: g,
                        selected: _group == g,
                        onTap: () => setState(
                          () => _group = _group == g ? null : g,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Exercise>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(color: c.accent),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        context.t('workout:spLoadFailed'),
                        style: FitTrackText.body.copyWith(color: c.muted),
                      ),
                    );
                  }
                  final items =
                      (snapshot.data ?? const <Exercise>[]).where((e) {
                    if (_group != null && e.muscleGroup != _group) {
                      return false;
                    }
                    return _query.isEmpty ||
                        e.name.toLowerCase().contains(_query);
                  }).toList();
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        context.t('workout:wsPickEmpty'),
                        style: FitTrackText.body.copyWith(color: c.muted),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return InkWell(
                        onTap: () => Navigator.pop(context, e),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(
                            vertical: FitTrackSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: c.line)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                e.name,
                                style: FitTrackText.body.copyWith(
                                  color: c.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${e.muscleGroup} · ${e.equipment}',
                                style: FitTrackText.caption
                                    .copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
