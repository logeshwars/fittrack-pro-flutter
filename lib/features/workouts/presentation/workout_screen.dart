import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/exercise_repository.dart';
import '../data/preset_service.dart';
import '../data/workout_splits_data.dart';
import '../domain/workout_models.dart';
import 'workout_template_screens.dart' show startSessionFor;
import '../../../core/widgets/fittrack_icons.dart';

/// Recent workouts for the history tab and date strip.
final workoutHistoryProvider =
    FutureProvider.autoDispose<List<Workout>>((ref) async {
  final service = ref.watch(workoutServiceProvider);
  if (service == null) {
    return const [];
  }
  return service.history(limit: 50);
});

/// The user's saved routines.
final presetsProvider =
    FutureProvider.autoDispose<List<WorkoutPreset>>((ref) async {
  final service = ref.watch(presetServiceProvider);
  if (service == null) {
    return const [];
  }
  return service.presets();
});

/// Every global exercise, used by the library, splits and the preset editor.
final allExercisesProvider =
    FutureProvider.autoDispose<List<Exercise>>((ref) async {
  final service = ref.watch(workoutServiceProvider);
  if (service == null) {
    return const [];
  }
  return service.exercises();
});

/// Exercises the user starred in the library. Kept on the device.
final exerciseFavoritesProvider =
    NotifierProvider<ExerciseFavorites, Set<String>>(ExerciseFavorites.new);

class ExerciseFavorites extends Notifier<Set<String>> {
  static const _key = 'fittrack_fav_exercises';

  @override
  Set<String> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = {...?prefs.getStringList(_key)};
    } on Object {
      // Favorites are a convenience; an unreadable store means none.
    }
  }

  Future<void> toggle(String exerciseId) async {
    final next = {...state};
    if (!next.remove(exerciseId)) next.add(exerciseId);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next.toList());
    } on Object {
      // Keep the in-memory choice for this run.
    }
  }
}

String _cap(String value) => value.isEmpty
    ? value
    : value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');

/// Rough session length: about two and a half minutes a set, to the
/// nearest five.
int _estimateMinutes(int sets) => ((sets * 2.6) / 5).round() * 5;

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final history = ref.watch(workoutHistoryProvider);

    return Column(
      children: [
        FitTrackScreenHeader(
          title: context.t('workout:title'),
          subtitle: switch (tab) {
            0 => context.t('workout:subRoutines'),
            1 => context.t('workout:subLibrary'),
            _ => context.t('workout:historyTab'),
          },
        ),
        Expanded(
          child: RefreshIndicator(
            color: colors.accent,
            backgroundColor: colors.surface,
            onRefresh: () async {
              ref.invalidate(workoutHistoryProvider);
              ref.invalidate(presetsProvider);
              await ref.read(workoutHistoryProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.gutter,
                FitTrackSpacing.gap,
                FitTrackSpacing.gutter,
                FitTrackSpacing.xxl,
              ),
              children: [
                FitTrackSegmentedTabs(
                  labels: [
                    context.t('workout:routinesTab'),
                    context.t('workout:exercisesTab'),
                    context.t('workout:historyTab'),
                  ],
                  selectedIndex: tab,
                  onSelected: (value) => setState(() => tab = value),
                ),
                const SizedBox(height: FitTrackSpacing.gap),
                if (tab == 0) ...[
                  _QuickStart(onTap: () => context.push('/workout/new')),
                  const SizedBox(height: FitTrackSpacing.gap),
                  _Routines(
                    onCreate: () => context.push('/workout/preset-new'),
                    onOpenLibrary: () => setState(() => tab = 1),
                  ),
                ],
                if (tab == 1) const _ExerciseLibrary(),
                if (tab == 2)
                  history.when(
                    loading: () => Padding(
                      padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                      child: Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    ),
                    error: (_, __) =>
                        _Info(text: context.t('workout:loadHistoryFailed')),
                    data: (items) => _History(
                      items: items,
                      onStart: () => context.push('/workout/new'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStart extends StatelessWidget {
  const _QuickStart({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('workout:quickStart'),
                  style: FitTrackText.title.copyWith(color: c.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t('workout:quickStartDesc'),
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: FitTrackSpacing.md),
          FitTrackButton(
            label: context.t('workout:startShort'),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _Routines extends ConsumerWidget {
  const _Routines({required this.onCreate, required this.onOpenLibrary});
  final VoidCallback onCreate;
  final VoidCallback onOpenLibrary;

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    WorkoutPreset preset,
  ) async {
    final all = await ref.read(allExercisesProvider.future);
    if (!context.mounted) return;
    final ids = {for (final e in preset.exercises) e.exerciseId};
    await startSessionFor(
      context,
      ref,
      preset.name,
      preset.exercises,
      [
        for (final e in all)
          if (ids.contains(e.id)) e,
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final presets = ref.watch(presetsProvider).valueOrNull ?? const [];
    final libraryCount = ref.watch(allExercisesProvider).valueOrNull?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitTrackListCard(
          title: context.t('workout:myRoutines'),
          actionLabel: '+ ${context.t('workout:new')}',
          onAction: onCreate,
          children: [
            if (presets.isEmpty)
              FitTrackRow(
                title: context.t('workout:createFirstRoutine'),
                subtitle: context.t('workout:buildCustomWorkout'),
                onTap: onCreate,
                chevron: true,
              ),
            for (final preset in presets)
              Builder(
                builder: (context) {
                  final sets = preset.exercises
                      .fold<int>(0, (s, e) => s + e.defaultSets);
                  return FitTrackRow(
                    title: preset.name,
                    subtitle: context.t(
                      'workout:routineSummaryTime',
                      args: {
                        'exercises': preset.exercises.length,
                        'sets': sets,
                        'minutes': _estimateMinutes(sets),
                      },
                    ),
                    onTap: () => context.push('/workout/preset/${preset.id}'),
                    trailing: FitTrackButton(
                      label: context.t('workout:startShort'),
                      variant: FitTrackButtonVariant.secondary,
                      onPressed: () =>
                          unawaited(_start(context, ref, preset)),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackListCard(
          title: context.t('workout:workoutSplits'),
          children: [
            for (final split in globalSplits)
              FitTrackRow(
                title: split.name,
                subtitle: context.t(
                  'workout:splitCycle',
                  args: {'days': split.days.length},
                ),
                minHeight: 56,
                chevron: true,
                onTap: () => context.push('/workout/split/${split.id}'),
              ),
          ],
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackCard(
          onTap: onOpenLibrary,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('workout:browseExercises'),
                      style: FitTrackText.title.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      libraryCount == null
                          ? context.t('workout:exerciseLibraryDesc')
                          : context.t(
                              'workout:libraryDesc',
                              args: {'count': libraryCount},
                            ),
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FitTrackSpacing.md),
              Text(
                context.t('workout:openLibrary'),
                style: FitTrackText.label.copyWith(color: c.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseLibrary extends ConsumerStatefulWidget {
  const _ExerciseLibrary();

  @override
  ConsumerState<_ExerciseLibrary> createState() => _ExerciseLibraryState();
}

class _ExerciseLibraryState extends ConsumerState<_ExerciseLibrary> {
  static const _favorites = '__favorites__';
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final all = ref.watch(allExercisesProvider);
    final favorites = ref.watch(exerciseFavoritesProvider);
    return all.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(FitTrackSpacing.xxl),
        child: Center(child: CircularProgressIndicator(color: c.accent)),
      ),
      error: (_, __) => _Info(text: context.t('workout:loadExercisesFailed')),
      data: (list) {
        final groups = {for (final e in list) e.muscleGroup}.toList()..sort();
        final q = _query.trim().toLowerCase();
        final shown = [
          for (final e in list)
            if ((_group == null ||
                    (_group == _favorites
                        ? favorites.contains(e.id)
                        : e.muscleGroup == _group)) &&
                (q.isEmpty || e.name.toLowerCase().contains(q)))
              e,
        ];
        final hint = context.t(
          'workout:searchCount',
          args: {'count': list.length},
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              textField: true,
              label: hint,
              child: FitTrackSearchField(
                hint: hint,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: FitTrackSpacing.gap),
            // Chips scroll edge to edge, past the screen gutter.
            SizedBox(
              height: FitTrackSpacing.touchMin,
              child: OverflowBox(
                maxWidth: MediaQuery.sizeOf(context).width,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FitTrackSpacing.gutter,
                  ),
                  children: [
                    for (final g in [
                      null,
                      if (favorites.isNotEmpty) _favorites,
                      ...groups,
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: FitTrackSpacing.sm,
                        ),
                        child: FitTrackChip(
                          label: g == null
                              ? context.t('workout:allGroups')
                              : g == _favorites
                                  ? context.t('workout:favoritesGroup')
                                  : _cap(g),
                          selected: _group == g,
                          onTap: () => setState(() => _group = g),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FitTrackSpacing.gap),
            if (shown.isEmpty)
              _Info(text: context.t('workout:noMatches'))
            else
              FitTrackListCard(
                children: [
                  for (final e in shown.take(200))
                    Builder(
                      builder: (context) {
                        final fav = favorites.contains(e.id);
                        return FitTrackRow(
                          minHeight: 60,
                          endPadding: 6,
                          title: e.name,
                          subtitle:
                              '${_cap(e.muscleGroup)} · ${_cap(e.equipment)}',
                          trailing: FitTrackIconButton(
                            icon: fav ? FitIcons.starFilled : FitIcons.star,
                            color: fav ? c.xpColor : c.muted,
                            semanticLabel: context.t(
                              fav ? 'workout:favRemove' : 'workout:favAdd',
                              args: {'name': e.name},
                            ),
                            onPressed: () => unawaited(
                              ref
                                  .read(exerciseFavoritesProvider.notifier)
                                  .toggle(e.id),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.items, required this.onStart});
  final List<Workout> items;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Info(
            text:
                '${context.t('workout:noHistory')}\n${context.t('workout:startFirstWorkout')}',
          ),
          const SizedBox(height: FitTrackSpacing.gap),
          FitTrackButton(
            label: context.t('workout:quickStart'),
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            onPressed: onStart,
          ),
        ],
      );
    }
    final now = DateTime.now();
    final month = items
        .where((w) =>
            w.startedAt.year == now.year && w.startedAt.month == now.month)
        .toList();
    final finished = month.where((w) => w.finishedAt != null).toList();
    final avgMin = finished.isEmpty
        ? 0
        : finished
                .map((w) => w.finishedAt!.difference(w.startedAt).inMinutes)
                .reduce((a, b) => a + b) /
            finished.length;
    final tonnes =
        month.fold<double>(0, (s, w) => s + w.totalVolumeKg) / 1000;

    final byMonth = <String, List<Workout>>{};
    for (final w in items) {
      byMonth
          .putIfAbsent(DateFormat('yyyy-MM').format(w.startedAt), () => [])
          .add(w);
    }
    final keys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitTrackStatStrip(
          stats: [
            FitTrackStat(
              label: context.t('workout:thisMonth'),
              value: '${month.length}',
              unit: context.t('workout:workoutsUnit'),
            ),
            FitTrackStat(
              label: context.t('workout:volumeLabel'),
              value: tonnes < 10
                  ? tonnes.toStringAsFixed(1)
                  : tonnes.round().toString(),
              unit: context.t('workout:tonnesUnit'),
            ),
            FitTrackStat(
              label: context.t('workout:avgTime'),
              value: avgMin.round().toString(),
              unit: context.t('workout:minUnit'),
            ),
          ],
        ),
        for (final key in keys) ...[
          const SizedBox(height: FitTrackSpacing.gap),
          FitTrackCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Month header: 40px, both ends 12 / 600 muted.
                SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FitTrackSpacing.cardPad,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              DateFormat('MMMM')
                                  .format(byMonth[key]!.first.startedAt),
                              style: FitTrackText.caption.copyWith(
                                color: c.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          context.t(
                            'workout:sessionsCount',
                            args: {'count': byMonth[key]!.length},
                          ),
                          style: FitTrackText.caption.copyWith(
                            color: c.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final w in byMonth[key]!)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.line)),
                    ),
                    child: _HistoryRow(workout: w),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final minutes = workout.finishedAt?.difference(workout.startedAt).inMinutes;
    final parts = <String>[
      DateFormat('EEE d MMM').format(workout.startedAt),
      if (minutes != null)
        context.t('workout:minutesShort', args: {'minutes': minutes}),
      context.t('workout:setsCount', args: {'count': workout.sets.length}),
    ];
    final hasPr = workout.sets.any((s) => s.isPersonalRecord);
    return FitTrackRow(
      title: workout.name,
      subtitle: parts.join(' · '),
      onTap: () => context.push('/workout/history/${workout.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPr) ...[
            FitTrackTag(label: context.t('workout:prBadge')),
            const SizedBox(width: FitTrackSpacing.sm),
          ],
          if (workout.totalVolumeKg > 0)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: FitTrackValue(
                value:
                    NumberFormat('#,##0').format(workout.totalVolumeKg.round()),
                unit: context.t('workout:kgUnit'),
                style: FitTrackText.rowTitle,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: const EdgeInsets.all(FitTrackSpacing.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: FitTrackText.body.copyWith(color: c.muted),
      ),
    );
  }
}
