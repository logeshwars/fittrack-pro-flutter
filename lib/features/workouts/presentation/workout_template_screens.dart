import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../application/session_controller.dart';
import '../data/preset_service.dart';
import '../data/exercise_repository.dart';
import '../data/workout_splits_data.dart';
import '../domain/split_models.dart';
import 'workout_screen.dart' show allExercisesProvider, presetsProvider;
import 'workout_secondary_screens.dart' show DetailHeader;

/// A planned exercise matched against the exercise table.
class ResolvedExercise {
  const ResolvedExercise({
    required this.predefined,
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.isSwapped = false,
  });

  final PredefinedExercise predefined;
  final String? exerciseId;
  final String name;
  final String muscleGroup;
  final bool isSwapped;

  ResolvedExercise swappedTo(Exercise e) => ResolvedExercise(
        predefined: predefined,
        exerciseId: e.id,
        name: e.name,
        muscleGroup: e.muscleGroup,
        isSwapped: true,
      );
}

/// Matches each planned exercise by exact name; unmatched ones keep a null id.
List<ResolvedExercise> resolveExercises(
  List<PredefinedExercise> planned,
  List<Exercise> all,
) {
  final byName = {for (final e in all) e.name: e};
  return [
    for (final p in planned)
      ResolvedExercise(
        predefined: p,
        exerciseId: byName[p.name]?.id,
        name: byName[p.name]?.name ?? p.name,
        muscleGroup: byName[p.name]?.muscleGroup ?? p.muscleGroup,
      ),
  ];
}

/// Same-muscle-group swap candidates, listing suggested alternatives first.
List<Exercise> swapOptions(
  ResolvedExercise target,
  List<Exercise> all,
  String query,
) {
  final q = query.trim().toLowerCase();
  final sameGroup = [
    for (final e in all)
      if (e.muscleGroup == target.predefined.muscleGroup &&
          e.name != target.name &&
          (q.isEmpty ||
              e.name.toLowerCase().contains(q) ||
              e.equipment.toLowerCase().contains(q)))
        e,
  ];
  final alts = target.predefined.alternatives.toSet();
  return [
    ...sameGroup.where((e) => alts.contains(e.name)),
    ...sameGroup.where((e) => !alts.contains(e.name)),
  ];
}

List<PresetExercise> toPresetExercises(List<ResolvedExercise> items) => [
      for (final r in items)
        if (r.exerciseId != null)
          PresetExercise(
            exerciseId: r.exerciseId!,
            exerciseName: r.name,
            muscleGroup: r.muscleGroup,
            defaultSets: r.predefined.sets,
          ),
    ];

WorkoutSplit splitById(String id) {
  final normalized = id.replaceAll('-', '_');
  for (final s in globalSplits) {
    if (s.id == normalized) {
      return s;
    }
  }
  return globalSplits.first;
}

/// Starts a session for [name] and opens the live workout screen.
Future<void> startSessionFor(
  BuildContext context,
  WidgetRef ref,
  String name,
  List<PresetExercise> exercises,
  List<Exercise> matched,
) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(sessionControllerProvider.notifier);
  if (ref.read(sessionControllerProvider) != null) {
    router.push('/workout/active');
    return;
  }
  final ok = await controller.start(
    name,
    preset: exercises,
    presetExercises: matched,
  );
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sign in to start a workout.')),
    );
    return;
  }
  final id = ref.read(sessionControllerProvider)?.workoutId ?? 'active';
  router.push('/workout/$id');
}

class WorkoutSplitScreen extends ConsumerStatefulWidget {
  const WorkoutSplitScreen({required this.splitId, super.key});
  final String splitId;

  @override
  ConsumerState<WorkoutSplitScreen> createState() => _WorkoutSplitScreenState();
}

class _WorkoutSplitScreenState extends ConsumerState<WorkoutSplitScreen> {
  int _day = 0;
  List<ResolvedExercise>? _resolved;
  int _resolvedDay = -1;
  bool _busy = false;

  WorkoutSplit get _split => splitById(widget.splitId);

  List<ResolvedExercise> _items(List<Exercise> all) {
    if (_resolved == null || _resolvedDay != _day) {
      _resolved = resolveExercises(_split.days[_day].exercises, all);
      _resolvedDay = _day;
    }
    return _resolved!;
  }

  String get _name => '${_split.shortName} – ${_split.days[_day].label}';

  Future<void> _swap(int index, List<Exercise> all) async {
    final items = _items(all);
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).card,
      builder: (_) => _SwapSheet(target: items[index], all: all),
    );
    if (picked == null) {
      return;
    }
    setState(() => _resolved = [
          for (var i = 0; i < items.length; i++)
            i == index ? items[i].swappedTo(picked) : items[i],
        ]);
  }

  Future<void> _start(List<Exercise> all) async {
    final messenger = ScaffoldMessenger.of(context);
    final exercises = toPresetExercises(_items(all));
    if (exercises.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No exercises matched – add them manually'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final ids = {for (final e in exercises) e.exerciseId};
    await startSessionFor(
      context,
      ref,
      _name,
      exercises,
      [for (final e in all) if (ids.contains(e.id)) e],
    );
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _savePreset(List<Exercise> all) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as preset'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    final exercises = toPresetExercises(_items(all));
    if (exercises.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No matched exercises to save')),
      );
      return;
    }
    await ref.read(presetServiceProvider)?.create(name, exercises);
    ref.invalidate(presetsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('"$name" added to your presets')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final split = _split;
    final all = ref.watch(allExercisesProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: all.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
          error: (_, __) => const Center(child: Text('Could not load exercises')),
          data: (exercises) {
            final items = _items(exercises);
            return ListView(
              padding: const EdgeInsets.only(bottom: 44),
              children: [
                DetailHeader(
                  title: split.name,
                  subtitle: '${split.frequency} · ${split.description}',
                  onBack: () => context.pop(),
                ),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    itemCount: split.days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ChoiceChip(
                      label: Text(split.days[i].label),
                      selected: i == _day,
                      onSelected: (_) => setState(() => _day = i),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Text(
                    split.days[_day].focus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: colors.muted,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                for (var i = 0; i < items.length; i++)
                  _ExerciseTile(
                    item: items[i],
                    onSwap: () => _swap(i, exercises),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _start(exercises),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('START WORKOUT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.accentText,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => _savePreset(exercises),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('SAVE AS PRESET'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.item, this.onSwap});
  final ResolvedExercise item;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final p = item.predefined;
    final missing = item.exerciseId == null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: item.isSwapped ? Border.all(color: colors.accent) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: missing ? colors.muted : colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  missing
                      ? 'Not found in exercise library'
                      : p.repsRange.isEmpty
                          ? '${p.sets} sets'
                          : '${p.sets} sets × ${p.repsRange} · rest ${formatRest(p.restSecs)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: missing ? colors.danger : colors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (onSwap != null)
            IconButton(
              tooltip: 'Swap exercise',
              onPressed: onSwap,
              icon: Icon(Icons.swap_horiz, color: colors.accent),
            ),
        ],
      ),
    );
  }
}

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.target, required this.all});
  final ResolvedExercise target;
  final List<Exercise> all;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final options = swapOptions(widget.target, widget.all, _query);
    final alts = widget.target.predefined.alternatives.toSet();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Swap ${widget.target.name}…',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final e = options[i];
                  return ListTile(
                    title: Text(e.name),
                    subtitle: Text(e.equipment),
                    trailing: alts.contains(e.name)
                        ? Text(
                            'SUGGESTED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: colors.accent,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(e),
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

class WorkoutPresetScreen extends ConsumerWidget {
  const WorkoutPresetScreen({required this.presetId, super.key});
  final String presetId;

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    WorkoutPreset preset,
  ) async {
    final all = await ref.read(allExercisesProvider.future);
    if (!context.mounted) {
      return;
    }
    final ids = {for (final e in preset.exercises) e.exerciseId};
    await startSessionFor(
      context,
      ref,
      preset.name,
      preset.exercises,
      [for (final e in all) if (ids.contains(e.id)) e],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WorkoutPreset preset,
  ) async {
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('"${preset.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await ref.read(presetServiceProvider)?.delete(preset.id);
    ref.invalidate(presetsProvider);
    router.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final presets = ref.watch(presetsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: presets.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
          error: (_, __) => const Center(child: Text('Could not load preset')),
          data: (list) {
            WorkoutPreset? preset;
            for (final p in list) {
              if (p.id == presetId) {
                preset = p;
              }
            }
            if (preset == null) {
              return Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Preset not found – go back'),
                ),
              );
            }
            final current = preset;
            return ListView(
              padding: const EdgeInsets.only(bottom: 44),
              children: [
                DetailHeader(
                  title: current.name,
                  subtitle: '${current.exercises.length} exercises',
                  onBack: () => context.pop(),
                  trailing: IconButton(
                    tooltip: 'Delete preset',
                    onPressed: () => _delete(context, ref, current),
                    icon: Icon(Icons.delete_outline, color: colors.danger),
                  ),
                ),
                const SizedBox(height: 12),
                for (final e in current.exercises)
                  _ExerciseTile(
                    item: ResolvedExercise(
                      predefined: PredefinedExercise(
                        name: e.exerciseName,
                        muscleGroup: e.muscleGroup,
                        sets: e.defaultSets,
                        repsRange: '',
                        restSecs: 90,
                        alternatives: const [],
                      ),
                      exerciseId: e.exerciseId,
                      name: e.exerciseName,
                      muscleGroup: e.muscleGroup,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.icon(
                    onPressed: () => _start(context, ref, current),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('START WORKOUT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.accentText,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Create a routine: name it, pick exercises and set counts.
class PresetEditorScreen extends ConsumerStatefulWidget {
  const PresetEditorScreen({super.key});

  @override
  ConsumerState<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends ConsumerState<PresetEditorScreen> {
  final _name = TextEditingController();
  final List<PresetExercise> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final all = await ref.read(allExercisesProvider.future);
    if (!mounted) {
      return;
    }
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).card,
      builder: (_) => _PickSheet(all: all),
    );
    if (picked == null) {
      return;
    }
    setState(() => _items.add(PresetExercise(
          exerciseId: picked.id,
          exerciseName: picked.name,
          muscleGroup: picked.muscleGroup,
          defaultSets: 3,
        )));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final name = _name.text.trim();
    if (name.isEmpty || _items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add a name and at least one exercise')),
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(presetServiceProvider)?.create(name, _items);
    ref.invalidate(presetsProvider);
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            DetailHeader(
              title: 'New routine',
              subtitle: '${_items.length} exercises',
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Routine name'),
              ),
            ),
            for (var i = 0; i < _items.length; i++)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _items[i].exerciseName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _items[i].defaultSets > 1
                          ? () => setState(() => _items[i] = PresetExercise(
                                exerciseId: _items[i].exerciseId,
                                exerciseName: _items[i].exerciseName,
                                muscleGroup: _items[i].muscleGroup,
                                defaultSets: _items[i].defaultSets - 1,
                              ))
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${_items[i].defaultSets}'),
                    IconButton(
                      onPressed: () => setState(() => _items[i] = PresetExercise(
                            exerciseId: _items[i].exerciseId,
                            exerciseName: _items[i].exerciseName,
                            muscleGroup: _items[i].muscleGroup,
                            defaultSets: _items[i].defaultSets + 1,
                          )),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _items.removeAt(i)),
                      icon: Icon(Icons.close, color: colors.danger),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('ADD EXERCISE'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.accentText,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('SAVE ROUTINE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickSheet extends StatefulWidget {
  const _PickSheet({required this.all});
  final List<Exercise> all;

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final e in widget.all)
        if (q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            e.muscleGroup.toLowerCase().contains(q))
          e,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(shown[i].name),
                  subtitle: Text('${shown[i].muscleGroup} · ${shown[i].equipment}'),
                  onTap: () => Navigator.of(context).pop(shown[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
