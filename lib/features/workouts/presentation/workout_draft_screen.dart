import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../data/workout_draft_store.dart';
import '../domain/workout_draft.dart';

class WorkoutDraftScreen extends StatefulWidget {
  const WorkoutDraftScreen({super.key});

  @override
  State<WorkoutDraftScreen> createState() => _WorkoutDraftScreenState();
}

class _WorkoutDraftScreenState extends State<WorkoutDraftScreen> {
  final _exercise = TextEditingController();
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  WorkoutDraft? _draft;
  WorkoutDraftStore? _store;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initialize();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = WorkoutDraftStore(prefs);
      if (!mounted) return;
      setState(() {
        _store = store;
        _draft = store.load() ??
            WorkoutDraft(name: 'New workout', startedAt: DateTime.now());
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to open local draft');
    }
  }

  Future<void> _addSet() async {
    final exercise = _exercise.text.trim();
    final weight = double.tryParse(_weight.text);
    final reps = int.tryParse(_reps.text);

    if (exercise.isEmpty ||
        weight == null ||
        !weight.isFinite ||
        weight < 0 ||
        reps == null ||
        reps < 1 ||
        reps > 1000) {
      setState(() => _error = 'Enter an exercise, valid weight and reps');
      return;
    }

    final draft = _draft;
    final store = _store;
    if (draft == null || store == null) return;

    final updated = draft.addSet(
      DraftSet(exerciseName: exercise, weightKg: weight, reps: reps),
    );

    try {
      await store.save(updated);
      if (!mounted) return;
      setState(() {
        _draft = updated;
        _error = null;
      });
      _weight.clear();
      _reps.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save local draft');
    }
  }

  Future<void> _removeSet(int index) async {
    final draft = _draft;
    final store = _store;
    if (draft == null || store == null) return;

    try {
      final updated = draft.removeSet(index);
      await store.save(updated);
      if (mounted) {
        setState(() {
          _draft = updated;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save local draft');
    }
  }

  Future<void> _discard() async {
    final store = _store;
    if (store == null) return;

    try {
      await store.clear();
      if (!mounted) return;
      setState(() {
        _draft = WorkoutDraft(name: 'New workout', startedAt: DateTime.now());
        _error = null;
        _exercise.clear();
        _weight.clear();
        _reps.clear();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to discard draft');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _exercise.dispose();
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final draft = _draft;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: draft == null
            ? Center(
                child: Text(
                  _error ?? 'Loading workout…',
                  style: TextStyle(color: colors.muted),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 36),
                children: [
                  _WorkoutHeader(
                    draft: draft,
                    onBack: () => context.pop(),
                  ),
                  _SessionStats(draft: draft),
                  _SetEntryCard(
                    exercise: _exercise,
                    weight: _weight,
                    reps: _reps,
                    error: _error,
                    onAdd: _addSet,
                  ),
                  if (draft.sets.isEmpty)
                    _EmptyExerciseState(colors: colors)
                  else
                    ..._groupSets(draft).map(
                      (group) => _ExerciseCard(
                        group: group,
                        onRemove: _removeSet,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: OutlinedButton.icon(
                      onPressed: _discard,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Discard local workout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.muted,
                        side: BorderSide(color: colors.border2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Text(
                      'This session is saved only on this device. Cloud workout writes remain disabled until account identity migration is verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: colors.faint,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<_ExerciseGroup> _groupSets(WorkoutDraft draft) {
    final groups = <String, List<_IndexedSet>>{};
    for (var i = 0; i < draft.sets.length; i++) {
      final set = draft.sets[i];
      groups.putIfAbsent(set.exerciseName, () => []).add(
            _IndexedSet(index: i, set: set),
          );
    }
    return groups.entries
        .map((entry) => _ExerciseGroup(name: entry.key, sets: entry.value))
        .toList();
  }
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({required this.draft, required this.onBack});

  final WorkoutDraft draft;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final elapsed = DateTime.now().difference(draft.startedAt);
    final totalSeconds = elapsed.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final timer = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border2),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back, size: 18, color: colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 11, color: colors.accent),
                    const SizedBox(width: 4),
                    Text(
                      timer,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colors.accent,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.workout.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: AppColors.workout.withValues(alpha: .25),
              ),
            ),
            child: const Text(
              'LOCAL',
              style: TextStyle(
                color: AppColors.workout,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.draft});

  final WorkoutDraft draft;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final exercises = draft.sets.map((s) => s.exerciseName).toSet().length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border2),
      ),
      child: Row(
        children: [
          _Stat(value: '${draft.sets.length}', label: 'SETS'),
          _Stat(
            value: draft.totalVolumeKg.round().toString(),
            label: 'KG VOL',
            divider: true,
          ),
          _Stat(
            value: '$exercises',
            label: 'EXERCISES',
            divider: true,
            accent: true,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.divider = false,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool divider;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border:
              divider ? Border(left: BorderSide(color: colors.border2)) : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: accent ? AppColors.workout : colors.text,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: colors.faint,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetEntryCard extends StatelessWidget {
  const _SetEntryCard({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.error,
    required this.onAdd,
  });

  final TextEditingController exercise;
  final TextEditingController weight;
  final TextEditingController reps;
  final String? error;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 18,
                  color: AppColors.workout,
                ),
                const SizedBox(width: 8),
                Text(
                  'ADD SET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.muted,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: exercise,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Exercise name',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'WEIGHT (KG)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: reps,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'REPS',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      width: 56,
                      child: FilledButton(
                        onPressed: onAdd,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: colors.accent,
                          foregroundColor: colors.accentText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.check, size: 22),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.group, required this.onRemove});

  final _ExerciseGroup group;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final volume = group.sets.fold<double>(
      0,
      (sum, item) => sum + item.set.volumeKg,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                ),
                Text(
                  '${volume.round()} kg',
                  style: TextStyle(fontSize: 10, color: colors.faint),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: colors.border2),
              ),
            ),
            child: Row(
              children: [
                _ColumnLabel(width: 42, text: 'SET'),
                const Expanded(child: _ColumnLabel(text: 'WEIGHT (KG)')),
                const Expanded(child: _ColumnLabel(text: 'REPS')),
                const SizedBox(width: 42),
              ],
            ),
          ),
          for (var i = 0; i < group.sets.length; i++)
            _SetRow(
              number: i + 1,
              item: group.sets[i],
              first: i == 0,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel({required this.text, this.width});
  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final child = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: colors.faint,
        letterSpacing: .8,
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.item,
    required this.first,
    required this.onRemove,
  });

  final int number;
  final _IndexedSet item;
  final bool first;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.subtext,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.set.weightKg.toStringAsFixed(
                item.set.weightKg == item.set.weightKg.roundToDouble() ? 0 : 1,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${item.set.reps}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: IconButton(
              onPressed: () => onRemove(item.index),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                size: 16,
                color: colors.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyExerciseState extends StatelessWidget {
  const _EmptyExerciseState({required this.colors});

  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 40, color: colors.border2),
          const SizedBox(height: 10),
          Text(
            'No sets recorded',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first exercise and set above.',
            style: TextStyle(fontSize: 11, color: colors.faint),
          ),
        ],
      ),
    );
  }
}

class _IndexedSet {
  const _IndexedSet({required this.index, required this.set});
  final int index;
  final DraftSet set;
}

class _ExerciseGroup {
  const _ExerciseGroup({required this.name, required this.sets});
  final String name;
  final List<_IndexedSet> sets;
}
