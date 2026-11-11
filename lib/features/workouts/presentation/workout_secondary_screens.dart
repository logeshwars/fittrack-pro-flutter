import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../data/workout_repository.dart';
import '../domain/workout_models.dart';

final _workoutDetailProvider =
    FutureProvider.autoDispose.family<Workout?, String>((ref, id) async {
  if (!AppConfig.hasSupabase) return null;
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;
  final items = await WorkoutRepository(client).getHistory(
    authenticatedUserId: user.id,
    pageSize: 100,
  );
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
});

class WorkoutHistoryDetailScreen extends ConsumerWidget {
  const WorkoutHistoryDetailScreen({required this.workoutId, super.key});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final detail = ref.watch(_workoutDetailProvider(workoutId));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: detail.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
          error: (_, __) => _Missing(onBack: () => context.pop()),
          data: (workout) =>
              workout == null
                  ? _Missing(onBack: () => context.pop())
                  : _WorkoutDetail(workout: workout),
        ),
      ),
    );
  }
}

class _WorkoutDetail extends StatelessWidget {
  const _WorkoutDetail({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final duration = workout.finishedAt == null
        ? 0
        : workout.finishedAt!.difference(workout.startedAt).inMinutes;
    final exercises = <String, List<WorkoutSet>>{};
    for (final set in workout.sets) {
      exercises.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 44),
      children: [
        _DetailHeader(
          title: workout.name,
          subtitle: DateFormat('EEEE, MMM d').format(workout.startedAt),
          onBack: () => context.pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${workout.sets.length}',
                  label: 'SETS',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: '$duration',
                  label: 'MIN',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: '${workout.totalVolumeKg.round()}',
                  label: 'KG VOL',
                  color: AppColors.workout,
                ),
              ),
            ],
          ),
        ),
        for (final entry in exercises.entries)
          _ExerciseHistory(name: entry.key, sets: entry.value),
      ],
    );
  }
}

class WorkoutSplitScreen extends StatelessWidget {
  const WorkoutSplitScreen({required this.splitId, super.key});
  final String splitId;

  @override
  Widget build(BuildContext context) {
    final split = _split(splitId);
    return _TemplateScreen(
      title: split.name,
      subtitle: split.subtitle,
      days: split.days,
    );
  }
}

class WorkoutPresetScreen extends StatelessWidget {
  const WorkoutPresetScreen({required this.presetId, super.key});
  final String presetId;

  @override
  Widget build(BuildContext context) {
    final preset = _preset(presetId);
    return _TemplateScreen(
      title: preset.name,
      subtitle: preset.subtitle,
      days: preset.days,
    );
  }
}

class _TemplateScreen extends StatelessWidget {
  const _TemplateScreen({
    required this.title,
    required this.subtitle,
    required this.days,
  });

  final String title;
  final String subtitle;
  final List<_Day> days;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _DetailHeader(
              title: title,
              subtitle: subtitle,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                'PROGRAM DAYS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.muted,
                  letterSpacing: 2,
                ),
              ),
            ),
            for (final day in days)
              InkWell(
                onTap: () => context.push('/workout/draft'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.workout.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.fitness_center,
                          color: AppColors.workout,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              day.focus,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.play_arrow_rounded,
                        color: colors.accent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: FilledButton.icon(
                onPressed: () => context.push('/workout/draft'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('START WORKOUT'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.accentText,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.arrow_back, color: colors.text, size: 19),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color ?? colors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: colors.faint,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseHistory extends StatelessWidget {
  const _ExerciseHistory({required this.name, required this.sets});
  final String name;
  final List<WorkoutSet> sets;

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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            color: colors.cardAlt,
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    'SET',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ),
                Expanded(
                  child: Text(
                    'WEIGHT',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ),
                Expanded(
                  child: Text(
                    'REPS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < sets.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${sets[i].weightKg?.toStringAsFixed(1) ?? '—'} kg',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${sets[i].reps ?? '—'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
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

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: colors.border2),
            const SizedBox(height: 12),
            Text(
              'Workout not found',
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}

_Template _split(String id) => switch (id) {
  'upper-lower' => const _Template(
      'Upper / Lower',
      '4 days · Strength and hypertrophy',
      [
        _Day('Upper A', 'Chest · Back · Shoulders · Arms'),
        _Day('Lower A', 'Quads · Hamstrings · Calves'),
        _Day('Upper B', 'Chest · Back · Shoulders · Arms'),
        _Day('Lower B', 'Glutes · Hamstrings · Quads'),
      ],
    ),
  'full-body' => const _Template(
      'Full Body',
      '3 days · Efficient total-body training',
      [
        _Day('Full Body A', 'Squat · Press · Row'),
        _Day('Full Body B', 'Hinge · Pull · Press'),
        _Day('Full Body C', 'Legs · Push · Pull'),
      ],
    ),
  _ => const _Template(
      'Push / Pull / Legs',
      '3 days · Balanced strength split',
      [
        _Day('Push', 'Chest · Shoulders · Triceps'),
        _Day('Pull', 'Back · Biceps · Rear delts'),
        _Day('Legs', 'Quads · Hamstrings · Glutes · Calves'),
      ],
    ),
};

_Template _preset(String id) => switch (id) {
  'upper' => const _Template(
      'Upper Body',
      'Balanced upper-body strength session',
      [_Day('Upper Body', 'Chest · Back · Shoulders · Arms')],
    ),
  'lower' => const _Template(
      'Lower Body',
      'Lower-body strength session',
      [_Day('Lower Body', 'Quads · Hamstrings · Glutes · Calves')],
    ),
  _ => const _Template(
      'Full Body',
      'Efficient full-body session',
      [_Day('Full Body', 'Legs · Push · Pull')],
    ),
};

class _Template {
  const _Template(this.name, this.subtitle, this.days);
  final String name;
  final String subtitle;
  final List<_Day> days;
}

class _Day {
  const _Day(this.name, this.focus);
  final String name;
  final String focus;
}
