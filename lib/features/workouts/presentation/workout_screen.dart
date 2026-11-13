import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int tab = 0;
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final history = ref.watch(workoutHistoryProvider);
    final workouts = history.valueOrNull ?? const <Workout>[];
    final weeklyVolume = workouts
        .where((w) => w.startedAt
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .fold<double>(0, (sum, w) => sum + w.totalVolumeKg);

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.surface,
      onRefresh: () async {
        ref.invalidate(workoutHistoryProvider);
        await ref.read(workoutHistoryProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: FitTrackSpacing.tabBarClearance - 60,
        ),
        children: [
          FitTrackScreenHeader(
            title: context.t('workout:title'),
            subtitle: DateFormat('EEEE, MMM d').format(selectedDate),
            trailing: weeklyVolume > 0
                ? FitTrackBadge(
                    label: context.t(
                      'workout:kgPerWeek',
                      args: {
                        'value': NumberFormat.decimalPattern()
                            .format(weeklyVolume.round()),
                      },
                    ),
                    tone: FitTrackBadgeTone.info,
                  )
                : null,
          ),
          _DateStrip(
            selected: selectedDate,
            workouts: workouts,
            onSelected: (value) => setState(() => selectedDate = value),
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
                FitTrackSegmentedTabs(
                  labels: [
                    context.t('workout:routinesTab'),
                    context.t('workout:exercisesTab'),
                    context.t('workout:historyTab'),
                  ],
                  selectedIndex: tab,
                  onSelected: (value) => setState(() => tab = value),
                ),
                const SizedBox(height: FitTrackSpacing.md),
                if (tab == 0) ...[
                  _QuickStart(onTap: () => context.push('/workout/new')),
                  const SizedBox(height: FitTrackSpacing.md),
                  _Routines(
                    onCreate: () => context.push('/workout/preset-new'),
                    onOpenLibrary: () => setState(() => tab = 1),
                  ),
                ],
                if (tab == 1) ...[
                  _QuickStart(onTap: () => context.push('/workout/new')),
                  const SizedBox(height: FitTrackSpacing.md),
                  const _ExerciseLibrary(),
                ],
                if (tab == 2) ...[
                  _QuickStart(onTap: () => context.push('/workout/new')),
                  const SizedBox(height: FitTrackSpacing.md),
                  history.when(
                    loading: () => Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    ),
                    error: (_, __) =>
                        _Info(text: context.t('workout:loadHistoryFailed')),
                    data: (items) => _History(items: items),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.selected,
    required this.workouts,
    required this.onSelected,
  });
  final DateTime selected;
  final List<Workout> workouts;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 3));
    final activeDays = workouts
        .map((w) =>
            DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day))
        .toSet();
    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          FitTrackSpacing.lg,
          FitTrackSpacing.md,
          FitTrackSpacing.lg,
          0,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: FitTrackSpacing.sm),
        itemBuilder: (context, index) {
          final date = start.add(Duration(days: index));
          final active = date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
          final hit = activeDays.contains(date);
          final label = DateFormat('EEE d MMM').format(date);
          return Semantics(
            button: true,
            selected: active,
            label: hit
                ? '$label, ${context.t('workout:trainedDay')}'
                : label,
            child: ExcludeSemantics(
              child: Material(
                color: active ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(FitTrackRadius.md),
                child: InkWell(
                  onTap: () => onSelected(date),
                  borderRadius: BorderRadius.circular(FitTrackRadius.md),
                  child: Container(
                    width: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FitTrackRadius.md),
                      border: Border.all(color: active ? c.accent : c.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: FitTrackText.caption.copyWith(
                            color: active ? c.onAccent : c.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: FitTrackText.titleLg.copyWith(
                            color: active ? c.onAccent : c.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Icon(
                          hit ? Icons.check : Icons.circle,
                          size: hit ? 10 : 4,
                          color: hit
                              ? (active ? c.onAccent : c.workoutColor)
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
                  style: FitTrackText.title.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
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
        FitTrackCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _CardHeader(
                title: context.t('workout:myRoutines'),
                action: '+ ${context.t('workout:new')}',
                onAction: onCreate,
              ),
              if (presets.isEmpty)
                _ListRow(
                  title: context.t('workout:createFirstRoutine'),
                  subtitle: context.t('workout:buildCustomWorkout'),
                  onTap: onCreate,
                  trailing: Icon(Icons.add, size: 20, color: c.ink),
                ),
              for (final preset in presets)
                _ListRow(
                  title: preset.name,
                  subtitle: context.t(
                    'workout:routineSummary',
                    args: {
                      'exercises': preset.exercises.length,
                      'sets': preset.exercises
                          .fold<int>(0, (s, e) => s + e.defaultSets),
                    },
                  ),
                  onTap: () => context.push('/workout/preset/${preset.id}'),
                  trailing: FitTrackButton(
                    label: context.t('workout:startShort'),
                    variant: FitTrackButtonVariant.secondary,
                    onPressed: () => unawaited(_start(context, ref, preset)),
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
              _CardHeader(title: context.t('workout:workoutSplits')),
              for (final split in globalSplits)
                _ListRow(
                  title: split.name,
                  subtitle: context.t(
                    'workout:splitSummary',
                    args: {
                      'days': split.days.length,
                      'description': split.description,
                    },
                  ),
                  minHeight: 56,
                  onTap: () => context.push('/workout/split/${split.id}'),
                  trailing: Icon(Icons.chevron_right, size: 20, color: c.muted),
                ),
            ],
          ),
        ),
        const SizedBox(height: FitTrackSpacing.md),
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
                      style: FitTrackText.title.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
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
              Text(
                context.t('workout:openLibrary'),
                style: FitTrackText.label.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return SizedBox(
      height: FitTrackSpacing.touchMin,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: FitTrackText.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (action != null)
              Semantics(
                button: true,
                label: action,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onAction,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: FitTrackSpacing.touchMin,
                      ),
                      child: Center(
                        child: Text(
                          action!,
                          style: FitTrackText.label.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

/// Divider-topped row used by routines, splits, exercises and history.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration:
            BoxDecoration(border: Border(top: BorderSide(color: c.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: FitTrackText.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: FitTrackSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseLibrary extends ConsumerStatefulWidget {
  const _ExerciseLibrary();

  @override
  ConsumerState<_ExerciseLibrary> createState() => _ExerciseLibraryState();
}

class _ExerciseLibraryState extends ConsumerState<_ExerciseLibrary> {
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final all = ref.watch(allExercisesProvider);
    return all.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: c.accent)),
      ),
      error: (_, __) => _Info(text: context.t('workout:loadExercisesFailed')),
      data: (list) {
        final groups = {for (final e in list) e.muscleGroup}.toList()..sort();
        final q = _query.trim().toLowerCase();
        final shown = [
          for (final e in list)
            if ((_group == null || e.muscleGroup == _group) &&
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
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: FitTrackText.body.copyWith(color: c.ink),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(Icons.search, size: 18, color: c.muted),
                ),
              ),
            ),
            const SizedBox(height: FitTrackSpacing.md),
            SizedBox(
              height: FitTrackSpacing.touchMin,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final g in [null, ...groups])
                    Padding(
                      padding: const EdgeInsets.only(right: FitTrackSpacing.sm),
                      child: FitTrackChip(
                        label: g ?? context.t('workout:allGroups'),
                        selected: _group == g,
                        onTap: () => setState(() => _group = g),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FitTrackSpacing.sm),
            if (shown.isEmpty)
              _Info(text: context.t('workout:noMatches'))
            else
              FitTrackCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final e in shown.take(200))
                      _ListRow(
                        title: e.name,
                        subtitle: '${e.muscleGroup} · ${e.equipment}',
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.items});
  final List<Workout> items;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    if (items.isEmpty) {
      return _Info(
        text:
            '${context.t('workout:noHistory')}\n${context.t('workout:startFirstWorkout')}',
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
        FitTrackCard(
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(
              children: [
                _StatCell(
                  label: context.t('workout:thisMonth'),
                  value: '${month.length}',
                  unit: context.t('workout:workoutsUnit'),
                ),
                VerticalDivider(width: 1, thickness: 1, color: c.line),
                _StatCell(
                  label: context.t('workout:volumeLabel'),
                  value: tonnes.round().toString(),
                  unit: context.t('workout:tonnesUnit'),
                ),
                VerticalDivider(width: 1, thickness: 1, color: c.line),
                _StatCell(
                  label: context.t('workout:avgTime'),
                  value: avgMin.round().toString(),
                  unit: context.t('workout:minUnit'),
                ),
              ],
            ),
          ),
        ),
        for (final key in keys) ...[
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _CardHeader(
                  title: DateFormat('MMMM').format(byMonth[key]!.first.startedAt),
                  action: context.t(
                    'workout:sessionsCount',
                    args: {'count': byMonth[key]!.length},
                  ),
                ),
                for (final w in byMonth[key]!) _HistoryRow(workout: w),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: value,
                style: FitTrackText.stat.copyWith(color: c.ink),
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
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final minutes = workout.finishedAt?.difference(workout.startedAt).inMinutes;
    final parts = <String>[
      DateFormat('EEE d MMM').format(workout.startedAt),
      if (minutes != null)
        context.t('workout:minutesShort', args: {'minutes': minutes}),
      context.t('workout:setsCount', args: {'count': workout.sets.length}),
    ];
    final hasPr = workout.sets.any((s) => s.isPersonalRecord);
    return _ListRow(
      title: workout.name,
      subtitle: parts.join(' · '),
      onTap: () => context.push('/workout/history/${workout.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPr) ...[
            FitTrackBadge(
              label: context.t('workout:prBadge'),
              tone: FitTrackBadgeTone.ok,
              icon: Icons.emoji_events_outlined,
            ),
            const SizedBox(width: FitTrackSpacing.sm),
          ],
          if (workout.totalVolumeKg > 0)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text.rich(
                textAlign: TextAlign.end,
                TextSpan(
                  text: NumberFormat('#,##0').format(workout.totalVolumeKg.round()),
                  style: FitTrackText.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: ' ${context.t('workout:kgUnit')}',
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
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
