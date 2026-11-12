import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
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
    final controller = ref.read(sessionControllerProvider.notifier);
    final resumed = await controller.restore();
    if (resumed) {
      return;
    }
    final started = await controller.start('Workout');
    if (!started && mounted) {
      setState(() => _error = 'Sign in to start a workout.');
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

    String? problem;
    switch (exercise.logType) {
      case 'duration':
        if (seconds == null || seconds <= 0) {
          problem = 'Enter the duration in seconds.';
        }
      case 'reps_only':
        if (reps == null || reps <= 0) {
          problem = 'Enter the number of reps.';
        }
      default:
        if (reps == null || reps <= 0) {
          problem = 'Enter the number of reps.';
        } else if (weight == null || weight < 0) {
          problem = 'Enter the weight in kg.';
        }
    }
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      problem = 'RPE must be between 1 and 10.';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New personal record!')),
        );
      }
      await _startRest();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not log the set. Try again.');
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

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  Future<void> _addExercise() async {
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Text(
          session.totalSets == 0
              ? 'No sets were logged, so this workout will be discarded.'
              : '${session.totalSets} sets logged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
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
          _error = 'Could not finish the workout. Try again.';
        });
      }
    }
  }

  Future<void> _showSummary(SessionSummary summary) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${_clock(summary.duration)}'),
            Text('Sets: ${summary.totalSets}'),
            Text('Volume: ${_kg(summary.volumeKg)} kg'),
            if (summary.prCount > 0)
              Text('Personal records: ${summary.prCount}'),
            Text('XP earned: +${summary.xpEarned}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('All sets logged in this workout will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
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
        appBar: AppBar(
          backgroundColor: c.header,
          foregroundColor: c.text,
          leading: BackButton(onPressed: _leave),
          title: const Text('Workout'),
        ),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: c.muted)),
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

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: c.text,
        elevation: 0,
        leading: BackButton(onPressed: _leave),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name, style: const TextStyle(fontSize: 16)),
            Text(
              _clock(DateTime.now().difference(session.startedAt)),
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'discard') {
                _discard();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _busy ? null : _finish,
              child: const Text('FINISH'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _StatsRow(session: session),
                  const SizedBox(height: 12),
                  _ExerciseChips(
                    session: session,
                    onSelect: (i) =>
                        ref.read(sessionControllerProvider.notifier).select(i),
                    onAdd: _addExercise,
                  ),
                  const SizedBox(height: 12),
                  if (exercise == null)
                    _EmptyState(onAdd: _addExercise)
                  else
                    _ExerciseCard(
                      exercise: exercise,
                      weight: _weight,
                      reps: _reps,
                      rpe: _rpe,
                      duration: _duration,
                      busy: _busy,
                      error: _error,
                      onLog: () => _logSet(exercise),
                      onRemove: (id) => ref
                          .read(sessionControllerProvider.notifier)
                          .removeSet(id),
                    ),
                ],
              ),
            ),
            if (_restRemaining > 0)
              _RestBanner(seconds: _restRemaining, onSkip: _skipRest),
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
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          cell('SETS', '${session.totalSets}'),
          cell('VOLUME KG', _kg(session.volumeKg)),
          cell('PRS', '${session.prCount}'),
        ],
      ),
    );
  }
}

class _ExerciseChips extends StatelessWidget {
  const _ExerciseChips({
    required this.session,
    required this.onSelect,
    required this.onAdd,
  });

  final SessionState session;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < session.exercises.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(session.exercises[i].name),
                selected: i == session.currentIndex,
                onSelected: (_) => onSelect(i),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add exercise'),
            onPressed: onAdd,
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text('Add your first exercise',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Pick from the exercise library to start logging sets.',
              style: TextStyle(color: c.muted), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('ADD EXERCISE'),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
          Text(exercise.muscleGroup.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.workout)),
          if (hint != null &&
              hint.lastWeightKg != null &&
              hint.lastReps != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last: ${_kg(hint.lastWeightKg!)} kg × ${hint.lastReps}'
              '${hint.suggestedWeightKg != null && hint.suggestedWeightKg != hint.lastWeightKg ? '  •  Try ${_kg(hint.suggestedWeightKg!)} kg' : ''}',
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (exercise.logType == 'weight_reps') ...[
                Expanded(
                    child: _NumberField(
                        controller: weight,
                        label: 'Weight (kg)',
                        decimal: true)),
                const SizedBox(width: 8),
              ],
              if (exercise.logType != 'duration')
                Expanded(child: _NumberField(controller: reps, label: 'Reps'))
              else
                Expanded(
                    child:
                        _NumberField(controller: duration, label: 'Seconds')),
              const SizedBox(width: 8),
              Expanded(
                  child: _NumberField(
                      controller: rpe, label: 'RPE', decimal: true)),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: c.danger, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onLog,
              child: Text('LOG SET ${exercise.nextSetNumber}'),
            ),
          ),
          if (exercise.sets.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final set in exercise.sets)
              _SetRow(
                  set: set,
                  logType: exercise.logType,
                  onRemove: () => onRemove(set.id)),
          ],
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow(
      {required this.set, required this.logType, required this.onRemove});

  final SessionSet set;
  final String logType;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final detail = switch (logType) {
      'duration' => '${set.durationSeconds ?? 0} s',
      'reps_only' => '${set.reps ?? 0} reps',
      _ => '${_kg(set.weightKg ?? 0)} kg × ${set.reps ?? 0}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${set.setNumber}',
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(detail, style: TextStyle(color: c.text))),
          if (set.rpe != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('RPE ${_kg(set.rpe!)}',
                  style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          if (set.isPersonalRecord)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.emoji_events, size: 18, color: AppColors.xp),
            ),
          IconButton(
            tooltip: 'Delete set',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: c.muted),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField(
      {required this.controller, required this.label, this.decimal = false});

  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: TextStyle(color: c.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.muted),
        filled: true,
        fillColor: c.inputBg,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.seconds, required this.onSkip});

  final int seconds;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.workout),
          const SizedBox(width: 10),
          Text('Rest  ${_clock(Duration(seconds: seconds))}',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
          const Spacer(),
          TextButton(onPressed: onSkip, child: const Text('SKIP')),
        ],
      ),
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
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search exercises',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final g in _groups)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(g),
                        selected: _group == g,
                        onSelected: (on) =>
                            setState(() => _group = on ? g : null),
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
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Could not load exercises.',
                          style: TextStyle(color: c.muted)),
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
                        child: Text('No exercises found.',
                            style: TextStyle(color: c.muted)));
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return ListTile(
                        title: Text(e.name),
                        subtitle: Text('${e.muscleGroup} • ${e.equipment}'),
                        onTap: () => Navigator.pop(context, e),
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
