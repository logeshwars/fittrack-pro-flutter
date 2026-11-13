import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
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
  final signIn = context.t('workout:spSignIn');
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
      SnackBar(content: Text(signIn)),
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
    final picked = await showFitTrackSheet<Exercise>(
      context: context,
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
    final noMatch = context.t('workout:sdRepeatNoMatch');
    final exercises = toPresetExercises(_items(all));
    if (exercises.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(noMatch)));
      return;
    }
    setState(() => _busy = true);
    final ids = {for (final e in exercises) e.exerciseId};
    await startSessionFor(
      context,
      ref,
      _name,
      exercises,
      [
        for (final e in all)
          if (ids.contains(e.id)) e
      ],
    );
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _savePreset(List<Exercise> all) async {
    final messenger = ScaffoldMessenger.of(context);
    final noSave = context.t('workout:spNoSave');
    final name = await showFitTrackSheet<String>(
      context: context,
      builder: (_) => _NameSheet(initial: _name),
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    final exercises = toPresetExercises(_items(all));
    if (exercises.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(noSave)));
      return;
    }
    final added = context.t('workout:spAdded', args: {'name': name});
    await ref.read(presetServiceProvider)?.create(name, exercises);
    ref.invalidate(presetsProvider);
    messenger.showSnackBar(SnackBar(content: Text(added)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final split = _split;
    final all = ref.watch(allExercisesProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: all.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: c.accent),
          ),
          error: (_, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(FitTrackSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('workout:spLoadFailed'),
                    style: FitTrackText.body.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: FitTrackSpacing.lg),
                  FitTrackButton(
                    label: context.t('common:retry'),
                    onPressed: () => ref.invalidate(allExercisesProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (exercises) {
            final items = _items(exercises);
            return ListView(
              padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
              children: [
                DetailHeader(
                  title: split.name,
                  subtitle: split.frequency,
                  onBack: () => context.pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FitTrackSpacing.lg,
                    FitTrackSpacing.md,
                    FitTrackSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FitTrackCard(
                        padding: const EdgeInsets.all(FitTrackSpacing.md + 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                context.t('workout:spAbout'),
                                style: FitTrackText.title.copyWith(
                                  color: c.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: FitTrackSpacing.xs),
                            Text(
                              split.description,
                              style: FitTrackText.label.copyWith(
                                color: c.muted,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: FitTrackSpacing.md),
                      FitTrackCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < split.days.length; i++)
                              _DayRow(
                                index: i,
                                day: split.days[i],
                                selected: i == _day,
                                first: i == 0,
                                onTap: () => setState(() => _day = i),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: FitTrackSpacing.lg),
                      Semantics(
                        header: true,
                        child: Text(
                          '${split.days[_day].label} · ${split.days[_day].focus}'
                              .toUpperCase(),
                          style: FitTrackText.caption.copyWith(
                            color: c.muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: FitTrackSpacing.sm),
                      for (var i = 0; i < items.length; i++)
                        _ExerciseTile(
                          item: items[i],
                          onSwap: () => _swap(i, exercises),
                        ),
                      const SizedBox(height: FitTrackSpacing.xs),
                      FitTrackButton(
                        label: context.t('workout:spStart'),
                        icon: Icons.play_arrow,
                        size: FitTrackButtonSize.lg,
                        fullWidth: true,
                        loading: _busy,
                        onPressed: _busy ? null : () => _start(exercises),
                      ),
                      const SizedBox(height: FitTrackSpacing.sm + 2),
                      FitTrackButton(
                        label: context.t('workout:spCopy'),
                        icon: Icons.bookmark_add_outlined,
                        variant: FitTrackButtonVariant.secondary,
                        size: FitTrackButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => _savePreset(exercises),
                      ),
                    ],
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

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.index,
    required this.day,
    required this.selected,
    required this.first,
    required this.onTap,
  });

  final int index;
  final SplitDay day;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final meta = context.t(
      'workout:spDayMeta',
      args: {'focus': day.focus, 'count': day.exercises.length},
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${day.label}, $meta',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.md + 2,
              vertical: FitTrackSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? c.accentTint : null,
              border: first ? null : Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : c.accentTint,
                    borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: FitTrackText.body.copyWith(
                      color: selected ? c.accentText : c.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: FitTrackSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.label,
                        style: FitTrackText.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check, size: 18, color: c.accent),
              ],
            ),
          ),
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
    final c = AppPalette.of(context);
    final p = item.predefined;
    final missing = item.exerciseId == null;
    final detail = missing
        ? context.t('workout:spNotFound')
        : p.repsRange.isEmpty
            ? context.t('workout:setsCount', args: {'count': p.sets})
            : context.t(
                'workout:spSetsLine',
                args: {
                  'sets': p.sets,
                  'reps': p.repsRange,
                  'rest': formatRest(p.restSecs),
                },
              );
    return Container(
      margin: const EdgeInsets.only(bottom: FitTrackSpacing.sm + 2),
      padding: const EdgeInsetsDirectional.fromSTEB(
        FitTrackSpacing.md + 2,
        FitTrackSpacing.sm,
        FitTrackSpacing.xs,
        FitTrackSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FitTrackRadius.lg),
        border: Border.all(color: item.isSwapped ? c.accent : c.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FitTrackSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: FitTrackText.body.copyWith(
                      color: missing ? c.muted : c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xs),
                  Text(
                    detail,
                    style: FitTrackText.caption.copyWith(
                      color: missing ? c.textBad : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onSwap != null)
            FitTrackIconButton(
              icon: Icons.swap_horiz,
              color: c.accent,
              semanticLabel: context.t('workout:spSwap'),
              onPressed: onSwap,
            ),
        ],
      ),
    );
  }
}

/// Name-entry sheet body; owns its text controller.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.t('workout:spSaveTitle'),
              style: FitTrackText.titleLg.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackTextField(
            label: context.t('workout:spNameLabel'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          FitTrackButton(
            label: context.t('common:save'),
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          ),
          const SizedBox(height: FitTrackSpacing.sm),
          FitTrackButton(
            label: context.t('common:cancel'),
            variant: FitTrackButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
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
    final c = AppPalette.of(context);
    final options = swapOptions(widget.target, widget.all, _query);
    final alts = widget.target.predefined.alternatives.toSet();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            FitTrackTextField(
              label: context.t(
                'workout:spSwapHint',
                args: {'name': widget.target.name},
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: FitTrackSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final e = options[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(e),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                        vertical: FitTrackSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: FitTrackText.body.copyWith(
                                    color: c.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  e.equipment,
                                  style: FitTrackText.caption
                                      .copyWith(color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          if (alts.contains(e.name))
                            FitTrackBadge(
                              label: context.t('workout:spSuggested'),
                              tone: FitTrackBadgeTone.ok,
                            ),
                        ],
                      ),
                    ),
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
      [
        for (final e in all)
          if (ids.contains(e.id)) e
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WorkoutPreset preset,
  ) async {
    final router = GoRouter.of(context);
    final ok = await showFitTrackConfirm(
      context: context,
      title: context.t('workout:reDeleteTitle'),
      message: context.t('workout:reDeleteMsg', args: {'name': preset.name}),
      confirmLabel: context.t('common:delete'),
      cancelLabel: context.t('common:cancel'),
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await ref.read(presetServiceProvider)?.delete(preset.id);
    ref.invalidate(presetsProvider);
    router.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final presets = ref.watch(presetsProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: presets.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: c.accent),
          ),
          error: (_, __) => _CenterMessage(
            text: context.t('workout:reLoadFailed'),
            action: context.t('common:retry'),
            onAction: () => ref.invalidate(presetsProvider),
          ),
          data: (list) {
            WorkoutPreset? preset;
            for (final p in list) {
              if (p.id == presetId) {
                preset = p;
              }
            }
            if (preset == null) {
              return _CenterMessage(
                text: context.t('workout:reNotFound'),
                action: context.t('workout:sdGoBack'),
                onAction: () => context.pop(),
              );
            }
            final current = preset;
            return ListView(
              padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
              children: [
                DetailHeader(
                  title: current.name,
                  subtitle: context.t(
                    'workout:exercisesCount',
                    args: {'count': current.exercises.length},
                  ),
                  onBack: () => context.pop(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FitTrackIconButton(
                        icon: Icons.edit_outlined,
                        color: c.ink,
                        semanticLabel: context.t('workout:reEdit'),
                        onPressed: () =>
                            context.push('/workout/preset-edit/${current.id}'),
                      ),
                      FitTrackIconButton(
                        icon: Icons.delete_outline,
                        color: c.textBad,
                        semanticLabel: context.t('common:delete'),
                        onPressed: () => _delete(context, ref, current),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FitTrackSpacing.lg,
                    FitTrackSpacing.md,
                    FitTrackSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      const SizedBox(height: FitTrackSpacing.xs),
                      FitTrackButton(
                        label: context.t('workout:spStart'),
                        icon: Icons.play_arrow,
                        size: FitTrackButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => _start(context, ref, current),
                      ),
                    ],
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

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.text,
    required this.action,
    required this.onAction,
  });
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FitTrackSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: FitTrackText.body.copyWith(color: c.muted),
            ),
            const SizedBox(height: FitTrackSpacing.lg),
            FitTrackButton(
              label: action,
              variant: FitTrackButtonVariant.secondary,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// Create or edit a routine: name it, pick exercises and set counts.
///
/// With a [presetId] the saved routine is loaded and updated in place.
class PresetEditorScreen extends ConsumerStatefulWidget {
  const PresetEditorScreen({this.presetId, super.key});
  final String? presetId;

  @override
  ConsumerState<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends ConsumerState<PresetEditorScreen> {
  final _name = TextEditingController();
  final List<PresetExercise> _items = [];
  bool _saving = false;
  bool _loading = false;
  bool _missing = false;
  String? _nameError;
  int _rest = 90;

  bool get _editing => widget.presetId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final rest = prefs.getInt('fittrack_default_rest') ?? 90;
    if (!_editing) {
      if (mounted) {
        setState(() => _rest = rest);
      }
      return;
    }
    setState(() => _loading = true);
    WorkoutPreset? found;
    try {
      final list = await ref.read(presetsProvider.future);
      for (final p in list) {
        if (p.id == widget.presetId) {
          found = p;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _rest = rest;
          _loading = false;
          if (found == null) {
            _missing = true;
          } else {
            _name.text = found.name;
            _items
              ..clear()
              ..addAll(found.exercises);
          }
        });
      }
    }
  }

  Future<void> _setRest(int value) async {
    final next = value.clamp(15, 300);
    setState(() => _rest = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fittrack_default_rest', next);
  }

  Future<void> _add() async {
    final all = await ref.read(allExercisesProvider.future);
    if (!mounted) {
      return;
    }
    final picked = await showFitTrackSheet<Exercise>(
      context: context,
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

  void _setSets(int i, int sets) {
    final e = _items[i];
    setState(() => _items[i] = PresetExercise(
          exerciseId: e.exerciseId,
          exerciseName: e.exerciseName,
          muscleGroup: e.muscleGroup,
          defaultSets: sets,
          cdnName: e.cdnName,
        ));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final nameRequired = context.t('workout:reNameError');
    final needItems = context.t('workout:reNeedItems');
    final signIn = context.t('workout:spSignIn');
    final saved = context.t('workout:reSaved');
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = nameRequired);
      return;
    }
    if (_items.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(needItems)));
      return;
    }
    final service = ref.read(presetServiceProvider);
    if (service == null) {
      messenger.showSnackBar(SnackBar(content: Text(signIn)));
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    try {
      if (_editing) {
        await service.update(widget.presetId!, name, _items);
      } else {
        await service.create(name, _items);
      }
      ref.invalidate(presetsProvider);
      messenger.showSnackBar(SnackBar(content: Text(saved)));
      router.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final router = GoRouter.of(context);
    final ok = await showFitTrackConfirm(
      context: context,
      title: context.t('workout:reDeleteTitle'),
      message: context.t('workout:reDeleteMsg', args: {'name': _name.text}),
      confirmLabel: context.t('common:delete'),
      cancelLabel: context.t('common:cancel'),
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await ref.read(presetServiceProvider)?.delete(widget.presetId!);
    ref.invalidate(presetsProvider);
    // Leave the editor and the routine detail underneath it.
    if (router.canPop()) {
      router.pop();
    }
    if (router.canPop()) {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final totalSets = _items.fold<int>(0, (sum, e) => sum + e.defaultSets);

    Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: c.accent));
    } else if (_missing) {
      body = _CenterMessage(
        text: context.t('workout:reNotFound'),
        action: context.t('workout:sdGoBack'),
        onAction: () => context.pop(),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          FitTrackSpacing.lg,
          FitTrackSpacing.md,
          FitTrackSpacing.lg,
          FitTrackSpacing.xxl,
        ),
        children: [
          FitTrackTextField(
            label: context.t('workout:reNameLabel'),
            controller: _name,
            errorText: _nameError,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_nameError != null) {
                setState(() => _nameError = null);
              }
            },
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SizedBox(
                  height: FitTrackSpacing.touchMin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FitTrackSpacing.md + 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            context.t('workout:exercisesLabel'),
                            style: FitTrackText.title.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          context.t(
                            'workout:reSummary',
                            args: {'count': _items.length, 'sets': totalSets},
                          ),
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(FitTrackSpacing.lg),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.line)),
                    ),
                    child: Text(
                      context.t('workout:reNeedItems'),
                      style: FitTrackText.body.copyWith(color: c.muted),
                    ),
                  ),
                for (var i = 0; i < _items.length; i++)
                  _EditorRow(
                    item: _items[i],
                    onSets: (v) => _setSets(i, v),
                    onRemove: () => setState(() => _items.removeAt(i)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackButton(
            label: context.t('workout:reAdd'),
            icon: Icons.add,
            variant: FitTrackButtonVariant.secondary,
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            onPressed: _add,
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackCard(
            padding: const EdgeInsets.all(FitTrackSpacing.md + 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('workout:reRestTitle'),
                        style: FitTrackText.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.t('workout:reRestHint'),
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                _StepperButton(
                  icon: Icons.remove,
                  label: context.t('workout:reRestDown'),
                  onTap: _rest > 15 ? () => unawaited(_setRest(_rest - 15)) : null,
                ),
                Semantics(
                  liveRegion: true,
                  child: SizedBox(
                    width: 52,
                    child: Text(
                      context.t('workout:reRestValue', args: {'sec': _rest}),
                      textAlign: TextAlign.center,
                      style: FitTrackText.titleLg.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  label: context.t('workout:reRestUp'),
                  onTap: _rest < 300 ? () => unawaited(_setRest(_rest + 15)) : null,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: c.line)),
        leading: FitTrackIconButton(
          icon: Icons.arrow_back,
          color: c.ink,
          semanticLabel: context.t('settings:backLabel'),
          onPressed: () => context.pop(),
        ),
        title: Semantics(
          header: true,
          child: Text(
            context.t(_editing ? 'workout:reEditTitle' : 'workout:reNewTitle'),
            style: FitTrackText.titleLg.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: _loading || _missing
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.lg,
                FitTrackSpacing.md,
                FitTrackSpacing.lg,
                FitTrackSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (_editing) ...[
                      Expanded(
                        child: FitTrackButton(
                          label: context.t('common:delete'),
                          variant: FitTrackButtonVariant.secondary,
                          size: FitTrackButtonSize.lg,
                          fullWidth: true,
                          onPressed: () => unawaited(_delete()),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: _editing ? 2 : 1,
                      child: FitTrackButton(
                        label: context.t('workout:reSave'),
                        size: FitTrackButtonSize.lg,
                        fullWidth: true,
                        loading: _saving,
                        onPressed: _saving ? null : () => unawaited(_save()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EditorRow extends StatelessWidget {
  const _EditorRow({
    required this.item,
    required this.onSets,
    required this.onRemove,
  });

  final PresetExercise item;
  final ValueChanged<int> onSets;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final name = item.exerciseName;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.only(
        start: FitTrackSpacing.md + 2,
        end: 2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FitTrackSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: FitTrackText.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.muscleGroup.isEmpty
                        ? context.t(
                            'workout:setsCount',
                            args: {'count': item.defaultSets},
                          )
                        : context.t(
                            'workout:reRowMeta',
                            args: {
                              'group': item.muscleGroup,
                              'count': item.defaultSets,
                            },
                          ),
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.remove,
            label: context.t('workout:reSetsDown', args: {'name': name}),
            onTap: item.defaultSets > 1 ? () => onSets(item.defaultSets - 1) : null,
          ),
          Semantics(
            liveRegion: true,
            child: SizedBox(
              width: 24,
              child: Text(
                '${item.defaultSets}',
                textAlign: TextAlign.center,
                style: FitTrackText.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            label: context.t('workout:reSetsUp', args: {'name': name}),
            onTap: () => onSets(item.defaultSets + 1),
          ),
          FitTrackIconButton(
            icon: Icons.close,
            color: c.textBad,
            semanticLabel: context.t('workout:reRemove', args: {'name': name}),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Bordered 44px stepper button used for set counts and rest time.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: FitTrackSpacing.touchMin,
            height: FitTrackSpacing.touchMin,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                  border: Border.all(color: c.lineStrong),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? c.ink : c.faint,
                ),
              ),
            ),
          ),
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
    final c = AppPalette.of(context);
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
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            FitTrackTextField(
              label: context.t('workout:rePickSearch'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: FitTrackSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () => Navigator.of(context).pop(shown[i]),
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
                          shown[i].name,
                          style: FitTrackText.body.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${shown[i].muscleGroup} · ${shown[i].equipment}',
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
