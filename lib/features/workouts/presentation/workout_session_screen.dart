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
import '../../../core/widgets/fittrack_ui.dart';
import '../application/session_controller.dart';
import '../data/exercise_repository.dart';
import '../domain/session_models.dart';
import '../domain/workout_models.dart';
import '../../../core/widgets/fittrack_icons.dart';

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
  bool _showRpe = false;
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
      icon: FitIcons.delete,
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

    if (session == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            FitTrackTopBar(
              title: context.t('workout:wsTitle'),
              backLabel: context.t('settings:backLabel'),
              onBack: _leave,
            ),
            Expanded(
              child: Center(
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
            ),
          ],
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
        ..add(const SizedBox(height: FitTrackSpacing.gap))
        ..add(FitTrackCard(
          padding: EdgeInsets.zero,
          child: Column(children: rows),
        ));
    }

    for (var i = 0; i < session.exercises.length; i++) {
      if (i == session.currentIndex && exercise != null) {
        flush();
        children
          ..add(const SizedBox(height: FitTrackSpacing.gap))
          ..add(_ExerciseCard(
            exercise: exercise,
            weight: _weight,
            reps: _reps,
            rpe: _rpe,
            duration: _duration,
            busy: _busy,
            error: _error,
            showRpe: _showRpe,
            onToggleRpe: () => setState(() => _showRpe = !_showRpe),
            onAddSet: () => unawaited(
              ref
                  .read(sessionControllerProvider.notifier)
                  .addPlannedSet(session.currentIndex),
            ),
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
      body: Column(
        children: [
          FitTrackTopBar(
            title: session.name,
            subtitle: context.t(
              'workout:wsElapsed',
              args: {
                'time': _clock(DateTime.now().difference(session.startedAt)),
              },
            ),
            backLabel: context.t('settings:backLabel'),
            onBack: _leave,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: context.t('workout:sdMore'),
                  icon: Icon(FitIcons.more, color: c.ink),
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
                FitTrackButton(
                  label: context.t('workout:wsFinish'),
                  onPressed: _busy ? null : () => unawaited(_finish()),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.gutter,
                FitTrackSpacing.gap,
                FitTrackSpacing.gutter,
                FitTrackSpacing.xxl,
              ),
              children: [
                _StatsRow(session: session),
                if (exercise == null) ...[
                  const SizedBox(height: FitTrackSpacing.gap),
                  _EmptyState(onAdd: _addExercise),
                ],
                ...children,
                if (exercise != null) ...[
                  const SizedBox(height: FitTrackSpacing.gap),
                  FitTrackButton(
                    label: context.t('workout:reAdd'),
                    icon: FitIcons.add,
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
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context) {
    // Planned sets are known only for exercises that came from a routine;
    // with none, the strip says how many are logged instead.
    final planned = session.exercises
        .fold<int>(0, (sum, e) => sum + e.plannedSets);
    return FitTrackStatStrip(
      stats: [
        FitTrackStat(
          label: context.t('workout:volumeLabel'),
          value: _kg(session.volumeKg),
          unit: context.t('workout:kgUnit'),
        ),
        FitTrackStat(
          label: context.t('workout:sdSets'),
          value: '${session.totalSets}',
          unit: planned > 0
              ? context.t('workout:wsSetsOfShort', args: {'total': planned})
              : context.t('workout:wsLoggedUnit'),
        ),
        FitTrackStat(
          label: context.t('workout:sdRecords'),
          value: '${session.prCount}',
          unit: context.t('workout:prBadge'),
        ),
      ],
    );
  }
}

class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.first,
    required this.onTap,
  });

  final SessionExercise exercise;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final done = exercise.sets.isNotEmpty;
    final complete =
        exercise.plannedSets > 0 && exercise.sets.length >= exercise.plannedSets;
    final hasPr = exercise.sets.any((s) => s.isPersonalRecord);
    final counts = exercise.plannedSets > 0
        ? context.t(
            'workout:wsSetsOf',
            args: {'done': exercise.sets.length, 'total': exercise.plannedSets},
          )
        : done
            ? context.t(
                'workout:wsSetsLogged',
                args: {'count': exercise.sets.length},
              )
            : null;
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;
    final meta = [
      if (counts != null) counts,
      if (last != null && last.weightKg != null && last.reps != null)
        '${_kg(last.weightKg!)} ${context.t('workout:kgUnit')} × ${last.reps}'
      else if (exercise.muscleGroup.isNotEmpty)
        exercise.muscleGroup,
    ].join(' · ');

    // Board: an exercise still to come shows the weight to open with.
    String? next;
    if (!done) {
      final hint = suggestOverload(
        ref.watch(previousSetsProvider(exercise.exerciseId)).valueOrNull ??
            const [],
      );
      final weight = hint?.suggestedWeightKg;
      if (weight != null && weight > 0) {
        next = context.t('workout:wsNextWeight', args: {'weight': _kg(weight)});
      }
    }

    return Semantics(
      button: true,
      label: [exercise.name, meta, if (next != null) next].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.cardPad,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FitTrackText.rowTitle.copyWith(color: c.ink),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FitTrackSpacing.sm),
                if (hasPr) ...[
                  FitTrackTag(label: context.t('workout:prBadge')),
                  const SizedBox(width: FitTrackSpacing.sm),
                ],
                if (complete)
                  _DoneMark(label: context.t('workout:wsComplete'))
                else if (next != null)
                  Text(
                    next,
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 28px green disc with a tick: a finished exercise or a logged set.
class _DoneMark extends StatelessWidget {
  const _DoneMark({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.ok, shape: BoxShape.circle),
          child: Icon(FitIcons.check, size: 14, color: c.surface),
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
            icon: FitIcons.add,
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
    required this.showRpe,
    required this.onToggleRpe,
    required this.onAddSet,
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
  final bool showRpe;
  final VoidCallback onToggleRpe;
  final VoidCallback onAddSet;
  final VoidCallback onLog;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final previous = ref.watch(previousSetsProvider(exercise.exerciseId));
    final history = previous.valueOrNull ?? const [];
    final hint = suggestOverload(history);
    final showHint =
        hint != null && hint.lastWeightKg != null && hint.lastReps != null;
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

    // What this set number did last time. The history is newest first, so
    // the first match for a number is the most recent.
    final lastTime = <int, WorkoutSet>{};
    for (final set in history) {
      lastTime.putIfAbsent(set.setNumber, () => set);
    }
    String previousText(int setNumber) {
      final set = lastTime[setNumber];
      if (set == null) return '–';
      return switch (exercise.logType) {
        'duration' => context.t(
            'workout:wsSecs',
            args: {'n': set.durationSeconds ?? 0},
          ),
        'reps_only' =>
          context.t('workout:wsRepsN', args: {'n': set.reps ?? 0}),
        _ => '${_kg(set.weightKg ?? 0)} × ${set.reps ?? 0}',
      };
    }

    final withWeight = exercise.logType == 'weight_reps';
    final isDuration = exercise.logType == 'duration';
    final rowCount = exercise.rowCount;

    Widget cell(Widget child, {double? width, int flex = 1}) => width == null
        ? Expanded(flex: flex, child: child)
        : SizedBox(width: width, child: child);

    Widget headerCell(String label, {TextAlign? align}) => Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: FitTrackText.caption.copyWith(color: c.muted),
        );

    Widget valueCell(String value) => Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: FitTrackText.title.copyWith(
            color: c.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );

    // Header: Set · Previous · kg · Reps · (RPE) · tick column.
    final header = Padding(
      padding: const EdgeInsets.only(bottom: FitTrackSpacing.xs),
      child: Row(
        children: [
          cell(headerCell(context.t('workout:wsColSet')), width: 28),
          const SizedBox(width: FitTrackSpacing.sm),
          cell(headerCell(context.t('workout:wsColPrevious')), width: 64),
          const SizedBox(width: FitTrackSpacing.sm),
          if (withWeight) ...[
            cell(
              headerCell(context.t('workout:wsColKg'), align: TextAlign.center),
            ),
            const SizedBox(width: FitTrackSpacing.sm),
          ],
          cell(
            headerCell(
              isDuration
                  ? context.t('workout:wsColSecs')
                  : context.t('workout:wsColReps'),
              align: TextAlign.center,
            ),
          ),
          if (showRpe) ...[
            const SizedBox(width: FitTrackSpacing.sm),
            cell(
              headerCell(
                context.t('workout:wsColRpe'),
                align: TextAlign.center,
              ),
              width: 48,
            ),
          ],
          const SizedBox(width: FitTrackSpacing.sm),
          const SizedBox(width: FitTrackSpacing.touchMin),
        ],
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < rowCount; i++) {
      final number = i + 1;
      final logged = i < exercise.sets.length;
      final active = i == exercise.sets.length;
      final set = logged ? exercise.sets[i] : null;

      final cells = <Widget>[
        cell(
          Text(
            '$number',
            style: FitTrackText.rowTitle.copyWith(
              color: logged || active ? c.ink : c.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          width: 28,
        ),
        const SizedBox(width: FitTrackSpacing.sm),
        cell(
          Text(
            previousText(number),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FitTrackText.caption.copyWith(color: c.muted),
          ),
          width: 64,
        ),
        const SizedBox(width: FitTrackSpacing.sm),
      ];

      if (logged) {
        if (withWeight) {
          cells
            ..add(cell(valueCell(_kg(set!.weightKg ?? 0))))
            ..add(const SizedBox(width: FitTrackSpacing.sm));
        }
        cells.add(
          cell(
            valueCell(
              isDuration ? '${set!.durationSeconds ?? 0}' : '${set!.reps ?? 0}',
            ),
          ),
        );
        if (showRpe) {
          cells
            ..add(const SizedBox(width: FitTrackSpacing.sm))
            ..add(
              cell(
                Text(
                  set.rpe == null ? '–' : _kg(set.rpe!),
                  textAlign: TextAlign.center,
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
                width: 48,
              ),
            );
        }
        cells
          ..add(const SizedBox(width: FitTrackSpacing.sm))
          ..add(
            SizedBox(
              width: FitTrackSpacing.touchMin,
              child: Center(
                child: set.isPersonalRecord
                    ? FitTrackTag(label: context.t('workout:prBadge'))
                    : _DoneMark(
                        label: context.t(
                          'workout:wsSetComplete',
                          args: {'n': number},
                        ),
                      ),
              ),
            ),
          );
      } else if (active) {
        if (withWeight) {
          cells
            ..add(
              cell(
                _CellField(
                  controller: weight,
                  hint: tryWeight == null ? null : _kg(tryWeight),
                  decimal: true,
                  semanticLabel: context.t(
                    'workout:wsSetWeight',
                    args: {'n': number},
                  ),
                ),
              ),
            )
            ..add(const SizedBox(width: FitTrackSpacing.sm));
        }
        cells.add(
          cell(
            _CellField(
              controller: isDuration ? duration : reps,
              hint: hint?.lastReps == null || isDuration
                  ? null
                  : '${hint!.lastReps}',
              semanticLabel: context.t(
                isDuration ? 'workout:wsSetSecs' : 'workout:wsSetReps',
                args: {'n': number},
              ),
            ),
          ),
        );
        if (showRpe) {
          cells
            ..add(const SizedBox(width: FitTrackSpacing.sm))
            ..add(
              cell(
                _CellField(
                  controller: rpe,
                  decimal: true,
                  semanticLabel:
                      context.t('workout:wsSetRpe', args: {'n': number}),
                ),
                width: 48,
              ),
            );
        }
        cells
          ..add(const SizedBox(width: FitTrackSpacing.sm))
          ..add(
            _TickButton(
              label: context.t('workout:wsCompleteSet', args: {'n': number}),
              busy: busy,
              onPressed: busy ? null : onLog,
            ),
          );
      } else {
        // A planned set still to come: shown, but not editable until the
        // sets before it are logged.
        if (withWeight) {
          cells
            ..add(cell(_EmptyCell()))
            ..add(const SizedBox(width: FitTrackSpacing.sm));
        }
        cells.add(cell(_EmptyCell()));
        if (showRpe) {
          cells
            ..add(const SizedBox(width: FitTrackSpacing.sm))
            ..add(cell(_EmptyCell(), width: 48));
        }
        cells
          ..add(const SizedBox(width: FitTrackSpacing.sm))
          ..add(const SizedBox(width: FitTrackSpacing.touchMin));
      }

      final row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: cells),
      );
      rows.add(
        logged
            ? Dismissible(
                key: ValueKey(set!.id),
                direction: DismissDirection.endToStart,
                background: ColoredBox(
                  color: c.bad,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: FitTrackSpacing.md,
                      ),
                      child: Icon(FitIcons.delete, size: 18, color: c.bg),
                    ),
                  ),
                ),
                onDismissed: (_) => onRemove(set.id),
                child: Semantics(
                  label: context.t(
                    'workout:wsDeleteSet',
                    args: {'n': number},
                  ),
                  child: row,
                ),
              )
            : row,
      );
    }

    return FitTrackCard(
      borderColor: c.accent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitTrackSpacing.cardPad,
              FitTrackSpacing.md,
              FitTrackSpacing.cardPad,
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: FitTrackText.title.copyWith(color: c.ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: FitTrackSpacing.sm),
                    Text(
                      exercise.plannedSets > 0
                          ? context.t(
                              'workout:wsSetsOf',
                              args: {
                                'done': exercise.sets.length,
                                'total': exercise.plannedSets,
                              },
                            )
                          : context.t(
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
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: FitTrackSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius:
                          BorderRadius.circular(FitTrackRadius.control),
                    ),
                    child: Text(
                      hintText,
                      style: FitTrackText.label.copyWith(
                        color: c.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitTrackSpacing.cardPad,
              FitTrackSpacing.sm,
              FitTrackSpacing.cardPad,
              FitTrackSpacing.cardPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                ...rows,
                if (error != null) ...[
                  const SizedBox(height: FitTrackSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(FitIcons.error, size: 16, color: c.textBad),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error!,
                          style:
                              FitTrackText.caption.copyWith(color: c.textBad),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: FitTrackSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FitTrackButton(
                        label: context.t('workout:wsAddSet'),
                        icon: FitIcons.add,
                        variant: FitTrackButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: onAddSet,
                      ),
                    ),
                    const SizedBox(width: FitTrackSpacing.sm),
                    Expanded(
                      child: FitTrackButton(
                        label: showRpe
                            ? context.t('workout:wsRpeShown')
                            : context.t('workout:wsColRpe'),
                        variant: FitTrackButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: onToggleRpe,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One cell of the set table: 44px, radius 8, centred 15 / 600 figures.
class _CellField extends StatelessWidget {
  const _CellField({
    required this.controller,
    required this.semanticLabel,
    this.hint,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final String? hint;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final style = FitTrackText.title.copyWith(
      color: c.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: FitTrackSpacing.touchMin,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            cursorColor: c.accent,
            style: style,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: style.copyWith(color: c.muted),
              filled: true,
              fillColor: c.surface,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FitTrackRadius.control),
                borderSide: BorderSide(color: c.lineStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FitTrackRadius.control),
                borderSide: BorderSide(color: c.lineStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FitTrackRadius.control),
                borderSide: BorderSide(color: c.accent, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder cell for a planned set that cannot be filled in yet.
class _EmptyCell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Container(
      height: FitTrackSpacing.touchMin,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FitTrackRadius.control),
        border: Border.all(color: c.line),
      ),
      child: Text('–', style: FitTrackText.body.copyWith(color: c.muted)),
    );
  }
}

/// 44px square tick that logs the set in the row it sits on.
class _TickButton extends StatelessWidget {
  const _TickButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(FitTrackRadius.control),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(FitTrackRadius.control),
            child: Ink(
              width: FitTrackSpacing.touchMin,
              height: FitTrackSpacing.touchMin,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FitTrackRadius.control),
                border: Border.all(color: c.lineStrong),
              ),
              child: busy
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.accent,
                        ),
                      ),
                    )
                  : Icon(FitIcons.check, size: 18, color: c.muted),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rest timer: a dark bar pinned to the foot of the screen in both themes,
/// 84px tall including the device inset.
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
    Widget action(
      String label,
      String semantic,
      VoidCallback onTap, {
      bool filled = false,
    }) =>
        Semantics(
          button: true,
          label: semantic,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FitTrackRadius.control),
              child: Container(
                height: FitTrackSpacing.touchMin,
                constraints: const BoxConstraints(minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? AppColors.restInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(FitTrackRadius.control),
                  border: Border.all(
                    color: filled ? AppColors.restInk : AppColors.restOutline,
                  ),
                ),
                child: Text(
                  label,
                  style: FitTrackText.label.copyWith(
                    color: filled ? AppColors.restBg : AppColors.restInk,
                  ),
                ),
              ),
            ),
          ),
        );

    return ColoredBox(
      color: AppColors.restBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FitTrackSpacing.gutter,
            FitTrackSpacing.sm,
            FitTrackSpacing.gutter,
            FitTrackSpacing.cardPad,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: '${context.t('workout:wsRest')}, '
                      '${_clock(Duration(seconds: seconds))}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.t('workout:wsRest'),
                          style: FitTrackText.caption.copyWith(
                            color: AppColors.restMuted,
                          ),
                        ),
                        Text(
                          _clock(Duration(seconds: seconds)),
                          style: FitTrackText.timer.copyWith(
                            color: AppColors.restInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: FitTrackSpacing.sm),
              action(
                context.t('workout:wsMinus15'),
                context.t('workout:wsRestMinus'),
                () => onAdjust(-15),
              ),
              const SizedBox(width: FitTrackSpacing.sm),
              action(
                context.t('workout:wsPlus15'),
                context.t('workout:wsRestPlus'),
                () => onAdjust(15),
              ),
              const SizedBox(width: FitTrackSpacing.sm),
              action(
                context.t('workout:wsSkip'),
                context.t('workout:wsSkip'),
                onSkip,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                borderRadius: BorderRadius.circular(FitTrackRadius.card),
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
