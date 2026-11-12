import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../settings/data/goal_targets.dart';
import '../../workouts/domain/workout_models.dart';
import '../domain/progress_aggregates.dart';
import '../domain/progress_models.dart';
import 'weight_screen.dart' show weightHistoryProvider;

/// Everything the analytics tab needs, fetched once.
class ProgressData {
  const ProgressData({
    required this.workouts,
    required this.nutrition,
    required this.sleep,
    required this.stats,
  });

  final List<Workout> workouts;
  final List<({DateTime at, double protein, double calories})> nutrition;
  final List<SleepLog> sleep;
  final Map<String, dynamic>? stats;
}

final progressDataProvider =
    FutureProvider.autoDispose<ProgressData>((ref) async {
  final workouts = ref.watch(workoutServiceProvider);
  final nutrition = ref.watch(nutritionServiceProvider);
  final sleep = ref.watch(sleepServiceProvider);
  final gamification = ref.watch(gamificationServiceProvider);
  final results = await Future.wait([
    workouts?.history(limit: 365) ?? Future.value(const <Workout>[]),
    nutrition?.heatmapData(days: 365) ?? Future.value(const <Map<String, dynamic>>[]),
    sleep?.history(limit: 365) ?? Future.value(const <Map<String, dynamic>>[]),
    gamification?.stats() ?? Future.value(null),
  ]);
  final nutritionRows = results[1]! as List<Map<String, dynamic>>;
  final sleepRows = results[2]! as List<Map<String, dynamic>>;
  return ProgressData(
    workouts: results[0]! as List<Workout>,
    nutrition: [
      for (final r in nutritionRows)
        (
          at: DateTime.parse('${r['logged_at']}'),
          protein: (r['protein_g'] as num?)?.toDouble() ?? 0,
          calories: (r['calories'] as num?)?.toDouble() ?? 0,
        ),
    ],
    sleep: [for (final r in sleepRows) SleepLog.fromJson(r)],
    stats: results[3] as Map<String, dynamic>?,
  );
});

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final data = ref.watch(progressDataProvider);
    final goals = ref.watch(goalTargetsProvider).valueOrNull ?? const GoalTargets();

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: () async {
        ref.invalidate(progressDataProvider);
        ref.invalidate(weightHistoryProvider);
        await ref.read(progressDataProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 44),
        children: [
          const FitTrackScreenHeader(
            title: 'Progress',
            subtitle: 'Analytics, body metrics and consistency',
            icon: Icons.insights,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: FitTrackSegmentedTabs(
              labels: const ['Analytics', 'Leaderboard'],
              selectedIndex: tab,
              onSelected: (value) {
                if (value == 1) {
                  context.push('/achievements');
                } else {
                  setState(() => tab = value);
                }
              },
            ),
          ),
          data.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: colors.accent)),
            ),
            error: (_, __) => const _Info(text: 'Unable to load progress.'),
            data: (d) => _Analytics(data: d, goals: goals),
          ),
        ],
      ),
    );
  }
}

class _Analytics extends ConsumerStatefulWidget {
  const _Analytics({required this.data, required this.goals});
  final ProgressData data;
  final GoalTargets goals;

  @override
  ConsumerState<_Analytics> createState() => _AnalyticsState();
}

enum _HeatType { workout, protein, calories, sleep }

class _AnalyticsState extends ConsumerState<_Analytics> {
  _HeatType _heat = _HeatType.workout;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final d = widget.data;
    final g = widget.goals;
    final now = DateTime.now();
    final week = weekDays(now);

    final volumeByDay = sumByDay([for (final w in d.workouts) (w.startedAt, w.totalVolumeKg)]);
    final workoutsByDay = sumByDay([for (final w in d.workouts) (w.startedAt, 1.0)]);
    final proteinByDay = sumByDay([for (final n in d.nutrition) (n.at, n.protein)]);
    final caloriesByDay = sumByDay([for (final n in d.nutrition) (n.at, n.calories)]);
    final sleepByDay = maxByDay([for (final s in d.sleep) (s.wakeTime, s.durationMinutes.toDouble())]);

    final proteinHits = goalHits(week, proteinByDay, g.protein);
    final calorieHits = goalHits(week, caloriesByDay, g.calories);
    final sleepHits = goalHits(week, sleepByDay, 7 * 60);
    final rate = completionRate([proteinHits, calorieHits, sleepHits]);

    final totalVolume = d.workouts.fold<double>(0, (s, w) => s + w.totalVolumeKg);
    final stats = d.stats;
    final totalWorkouts = (stats?['total_workouts'] as num?)?.toInt() ?? d.workouts.length;
    final streak = (stats?['current_streak'] as num?)?.toInt() ?? 0;
    final prs = (stats?['total_prs'] as num?)?.toInt() ?? 0;

    final heatData = switch (_heat) {
      _HeatType.workout => (map: workoutsByDay, max: 2.0, color: AppColors.workout, unit: 'sessions'),
      _HeatType.protein => (map: proteinByDay, max: g.protein, color: AppColors.nutrition, unit: 'g'),
      _HeatType.calories => (map: caloriesByDay, max: g.calories, color: AppColors.cardio, unit: 'kcal'),
      _HeatType.sleep => (map: sleepByDay, max: 8 * 60.0, color: AppColors.sleep, unit: 'min'),
    };

    Widget card({required Widget child}) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(14)),
          child: child,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card(
            child: Row(
              children: [
                _StatCell(label: 'WORKOUTS', value: '$totalWorkouts'),
                _StatCell(label: 'VOLUME', value: '${(totalVolume / 1000).round()}t'),
                _StatCell(label: 'STREAK', value: streak > 0 ? '${streak}d' : '—'),
                _StatCell(label: 'PRS', value: '$prs'),
              ],
            ),
          ),
          card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FitTrackSectionLabel(title: 'Weekly Volume (kg)'),
                const SizedBox(height: 8),
                _WeekBars(
                  week: week,
                  values: [for (final day in week) volumeByDay[dateKey(day)] ?? 0],
                  color: AppColors.workout,
                ),
              ],
            ),
          ),
          card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FitTrackSectionLabel(title: 'Weekly Protein (g)'),
                const SizedBox(height: 8),
                _WeekBars(
                  week: week,
                  values: [for (final day in week) proteinByDay[dateKey(day)] ?? 0],
                  color: AppColors.nutrition,
                  goal: g.protein,
                ),
              ],
            ),
          ),
          card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FitTrackSectionLabel(title: 'Consistency'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final t in _HeatType.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                            selected: _heat == t,
                            onSelected: (_) => setState(() => _heat = t),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _HeatMap(
                  byDay: heatData.map,
                  max: heatData.max,
                  color: heatData.color,
                  days: 182,
                ),
              ],
            ),
          ),
          card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: FitTrackSectionLabel(title: 'Goals This Week')),
                    Text(
                      '$rate%',
                      style: TextStyle(fontWeight: FontWeight.w900, color: colors.accent),
                    ),
                  ],
                ),
                _GoalRow(label: 'Protein', hits: proteinHits, week: week),
                _GoalRow(label: 'Calories', hits: calorieHits, week: week),
                _GoalRow(label: 'Sleep 7h', hits: sleepHits, week: week),
              ],
            ),
          ),
          _BodyMetrics(),
        ],
      ),
    );
  }
}

class _BodyMetrics extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final weights = ref.watch(weightHistoryProvider).valueOrNull ?? const <WeightLog>[];
    final summary = ProgressSummary.fromLogs(weights: weights, sleep: const []);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FitTrackSectionLabel(title: 'Body Metrics'),
          Row(
            children: [
              _StatCell(
                label: 'LATEST',
                value: summary.latestWeightKg == null
                    ? '—'
                    : '${summary.latestWeightKg!.toStringAsFixed(1)} kg',
              ),
              _StatCell(
                label: 'CHANGE',
                value: summary.weightChangeKg == null
                    ? '—'
                    : '${summary.weightChangeKg! >= 0 ? '+' : ''}${summary.weightChangeKg!.toStringAsFixed(1)} kg',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/progress/weight'),
                  icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                  label: const Text('Weight'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/sleep'),
                  icon: const Icon(Icons.bedtime_outlined, size: 16),
                  label: const Text('Sleep'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.text),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, letterSpacing: 1, color: colors.faint)),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({
    required this.week,
    required this.values,
    required this.color,
    this.goal,
  });
  final List<DateTime> week;
  final List<double> values;
  final Color color;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final today = startOfDay(DateTime.now());
    final peak = [...values, goal ?? 0, 1.0].reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: peak * 1.15,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= week.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('E').format(week[i]).substring(0, 1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: week[i] == today ? FontWeight.w900 : FontWeight.w500,
                        color: week[i] == today ? colors.text : colors.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: goal == null
              ? null
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: goal!,
                    color: colors.faint,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ]),
          barGroups: [
            for (var i = 0; i < week.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                    color: week[i].isAfter(today) ? colors.border2 : color,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.label, required this.hits, required this.week});
  final String label;
  final List<bool> hits;
  final List<DateTime> week;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final today = startOfDay(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.text)),
          ),
          for (var i = 0; i < hits.length; i++)
            Expanded(
              child: Column(
                children: [
                  Icon(
                    hits[i]
                        ? Icons.check_circle
                        : (week[i].isAfter(today) ? Icons.circle_outlined : Icons.cancel_outlined),
                    size: 18,
                    color: hits[i] ? AppColors.recovery : colors.faint,
                  ),
                  Text(
                    DateFormat('E').format(week[i]).substring(0, 1),
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatMap extends StatelessWidget {
  const _HeatMap({
    required this.byDay,
    required this.max,
    required this.color,
    required this.days,
  });
  final Map<String, double> byDay;
  final double max;
  final Color color;
  final int days;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final weeks = heatGrid(DateTime.now(), days);
    const alphas = [0.0, .2, .4, .65, 1.0];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (final col in weeks)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Column(
                children: [
                  for (final day in col)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: day == null
                            ? Colors.transparent
                            : () {
                                final level = heatLevel(byDay[dateKey(day)] ?? 0, max);
                                return level == 0
                                    ? colors.border2.withValues(alpha: .5)
                                    : color.withValues(alpha: alphas[level]);
                              }(),
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

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: colors.muted)),
    );
  }
}
