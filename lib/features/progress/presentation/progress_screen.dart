import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../gamification/data/gamification_service.dart'
    show calculateRankScore;
import '../../settings/data/goal_targets.dart';
import '../../workouts/domain/workout_models.dart';
import '../domain/progress_aggregates.dart';
import '../domain/progress_models.dart';
import 'weight_screen.dart' show weightHistoryProvider;
import '../../../core/l10n/language_controller.dart';
import '../../../core/widgets/fittrack_icons.dart';

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
    nutrition?.heatmapData(days: 365) ??
        Future.value(const <Map<String, dynamic>>[]),
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

FitTrackTier _tierOf(String tier) => switch (tier) {
      'silver' => FitTrackTier.silver,
      'gold' => FitTrackTier.gold,
      'elite' => FitTrackTier.elite,
      'legend' => FitTrackTier.legend,
      _ => FitTrackTier.bronze,
    };

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final data = ref.watch(progressDataProvider);
    final goals =
        ref.watch(goalTargetsProvider).valueOrNull ?? const GoalTargets();
    final tier = '${data.valueOrNull?.stats?['rank_tier'] ?? ''}';

    return Column(
      children: [
        FitTrackScreenHeader(
          title: context.t('progress:title'),
          subtitle: context.t('progress:analytics'),
          trailing: tier.isEmpty
              ? null
              : _RankPill(
                  tier: _tierOf(tier),
                  label: context.t(
                    'progress:rankBadge',
                    args: {'tier': context.t('progress:tier_$tier')},
                  ),
                  onTap: () => context.push('/leaderboard'),
                ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.accent,
            backgroundColor: c.surface,
            onRefresh: () async {
              ref.invalidate(progressDataProvider);
              ref.invalidate(weightHistoryProvider);
              await ref.read(progressDataProvider.future);
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
                    context.t('progress:analytics'),
                    context.t('progress:leaderboard'),
                  ],
                  selectedIndex: tab,
                  onSelected: (value) {
                    if (value == 1) {
                      context.push('/leaderboard');
                    } else {
                      setState(() => tab = value);
                    }
                  },
                ),
                const SizedBox(height: FitTrackSpacing.gap),
                data.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                    child: Center(
                      child: CircularProgressIndicator(color: c.accent),
                    ),
                  ),
                  error: (_, __) =>
                      _Info(text: context.t('progress:unableLoad')),
                  data: (d) => _Analytics(data: d, goals: goals),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rank pill in the header: a soft tint of the tier color, a dot and the
/// tier name. 32px tall inside a 44px tap area.
class _RankPill extends StatelessWidget {
  const _RankPill({
    required this.tier,
    required this.label,
    required this.onTap,
  });
  final FitTrackTier tier;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final color = switch (tier) {
      FitTrackTier.bronze => c.tierBronze,
      FitTrackTier.silver => c.tierSilver,
      FitTrackTier.gold => c.tierGold,
      FitTrackTier.elite => c.tierElite,
      FitTrackTier.legend => c.tierLegend,
    };
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FitTrackRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: FitTrackSpacing.touchMin,
            ),
            child: Center(
              widthFactor: 1,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tier == FitTrackTier.gold
                      ? c.warnSoft
                      : color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(FitTrackRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: FitTrackText.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final c = AppPalette.of(context);
    final d = widget.data;
    final g = widget.goals;
    final now = DateTime.now();
    final today = startOfDay(now);
    final week = weekDays(now);

    final volumeByDay =
        sumByDay([for (final w in d.workouts) (w.startedAt, w.totalVolumeKg)]);
    final workoutsByDay =
        sumByDay([for (final w in d.workouts) (w.startedAt, 1.0)]);
    final proteinByDay =
        sumByDay([for (final n in d.nutrition) (n.at, n.protein)]);
    final caloriesByDay =
        sumByDay([for (final n in d.nutrition) (n.at, n.calories)]);
    final sleepByDay = maxByDay(
        [for (final s in d.sleep) (s.wakeTime, s.durationMinutes.toDouble())]);

    final proteinHits = goalHits(week, proteinByDay, g.protein);
    final calorieHits = goalHits(week, caloriesByDay, g.calories);
    final sleepHits = goalHits(week, sleepByDay, 7 * 60);
    final rate = completionRate([proteinHits, calorieHits, sleepHits]);

    final totalVolume =
        d.workouts.fold<double>(0, (s, w) => s + w.totalVolumeKg);
    final stats = d.stats;
    final totalWorkouts =
        (stats?['total_workouts'] as num?)?.toInt() ?? d.workouts.length;
    final streak = (stats?['current_streak'] as num?)?.toInt() ?? 0;
    final bestStreak = (stats?['longest_streak'] as num?)?.toInt() ?? streak;
    final prs = (stats?['total_prs'] as num?)?.toInt() ?? 0;

    // Rank score for this month, same formula as the leaderboard.
    final monthWorkouts = d.workouts
        .where((w) =>
            w.startedAt.year == now.year && w.startedAt.month == now.month)
        .toList();
    final rankScore = calculateRankScore(
      trainingDays: {
        for (final w in monthWorkouts) dateKey(w.startedAt),
      }.length,
      volumeKg: monthWorkouts.fold<double>(0, (s, w) => s + w.totalVolumeKg),
      streakLength: streak,
      prCount: monthWorkouts.fold<int>(
        0,
        (s, w) => s + w.sets.where((x) => x.isPersonalRecord).length,
      ),
    );

    // Last 8 weeks of volume in tonnes, oldest first.
    final thisMonday = week.first;
    final weeklyTonnes = [
      for (var i = 7; i >= 0; i--)
        () {
          final start = thisMonday.subtract(Duration(days: 7 * i));
          var sum = 0.0;
          for (var k = 0; k < 7; k++) {
            sum += volumeByDay[dateKey(start.add(Duration(days: k)))] ?? 0;
          }
          return sum / 1000;
        }(),
    ];

    final last7 = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final proteinTrend = [for (final x in last7) proteinByDay[dateKey(x)] ?? 0];

    final heatData = switch (_heat) {
      _HeatType.workout => (
          map: workoutsByDay,
          max: 2.0,
          color: c.workoutColor,
          label: context.t('progress:heatWorkout'),
        ),
      _HeatType.protein => (
          map: proteinByDay,
          max: g.protein,
          color: c.nutritionColor,
          label: context.t('progress:heatProtein'),
        ),
      _HeatType.calories => (
          map: caloriesByDay,
          max: g.calories,
          color: c.cardioColor,
          label: context.t('progress:heatCalories'),
        ),
      _HeatType.sleep => (
          map: sleepByDay,
          max: 8 * 60.0,
          color: c.sleepColor,
          label: context.t('progress:heatSleep'),
        ),
    };

    final daysUnit = context.t('progress:unitDays');
    final tonnes = totalVolume / 1000;
    final kpis = <(String, String, String?)>[
      (context.t('progress:kpiCurrentStreak'), '$streak', daysUnit),
      (context.t('progress:kpiBestStreak'), '$bestStreak', daysUnit),
      (context.t('progress:kpiWorkouts'), '$totalWorkouts', null),
      (
        context.t('progress:kpiTotalVolume'),
        tonnes < 10 ? tonnes.toStringAsFixed(1) : '${tonnes.round()}',
        context.t('progress:unitTonnes'),
      ),
      (context.t('progress:kpiRecords'), '$prs', context.t('progress:unitPrs')),
      (context.t('progress:rankScore'), '$rankScore', null),
    ];

    Widget titled(String title, String? sub, Widget child) => FitTrackCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: FitTrackText.rowTitle.copyWith(color: c.ink),
                  ),
                  const SizedBox(width: FitTrackSpacing.sm),
                  if (sub != null)
                    Flexible(
                      child: Text(
                        sub,
                        textAlign: TextAlign.end,
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FitTrackSpacing.md),
              child,
            ],
          ),
        );

    const gap = SizedBox(height: FitTrackSpacing.gap);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FitTrackGrid(
            columns: 3,
            children: [
              for (final (label, value, unit) in kpis)
                FitTrackStatTile(label: label, value: value, unit: unit),
            ],
          ),
          gap,
          titled(
            context.t('progress:weeklyVolumeTitle'),
            context.t('progress:last8Weeks'),
            _VolumeWeeks(values: weeklyTonnes),
          ),
          gap,
          titled(
            context.t('progress:proteinTrend'),
            context.t(
              'progress:proteinTrendSub',
              args: {'goal': g.protein.round()},
            ),
            _ProteinLine(values: proteinTrend, goal: g.protein),
          ),
          gap,
          titled(
            context.t('progress:goalCompletionTitle'),
            '$rate% · ${context.t('progress:last7Days')}',
            Column(
              children: [
                _GoalRow(
                  label: '',
                  hits: const [false, false, false, false, false, false, false],
                  week: week,
                  header: true,
                ),
                _GoalRow(
                  label: context.t('progress:goalCalories'),
                  hits: calorieHits,
                  week: week,
                ),
                _GoalRow(
                  label: context.t('progress:goalProtein'),
                  hits: proteinHits,
                  week: week,
                ),
                _GoalRow(
                  label: context.t('progress:goalSleep'),
                  hits: sleepHits,
                  week: week,
                ),
              ],
            ),
          ),
          gap,
          titled(
            context.t('progress:activityTitle'),
            context.t('progress:last13Weeks'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: FitTrackSpacing.touchMin,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final t in _HeatType.values)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: FitTrackSpacing.sm),
                          child: FitTrackChip(
                            label: switch (t) {
                              _HeatType.workout =>
                                context.t('progress:heatWorkout'),
                              _HeatType.protein =>
                                context.t('progress:heatProtein'),
                              _HeatType.calories =>
                                context.t('progress:heatCalories'),
                              _HeatType.sleep =>
                                context.t('progress:heatSleep'),
                            },
                            selected: _heat == t,
                            onTap: () => setState(() => _heat = t),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: FitTrackSpacing.sm),
                Semantics(
                  label: heatData.label,
                  child: _HeatMap(
                    byDay: heatData.map,
                    max: heatData.max,
                    color: heatData.color,
                    days: 91,
                  ),
                ),
              ],
            ),
          ),
          gap,
          const _BodyMetrics(),
        ],
    );
  }
}

class _BodyMetrics extends ConsumerWidget {
  const _BodyMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final weights =
        ref.watch(weightHistoryProvider).valueOrNull ?? const <WeightLog>[];
    final summary = ProgressSummary.fromLogs(weights: weights, sleep: const []);
    final latest = summary.latestWeightKg;
    final change = summary.weightChangeKg;
    final caption = latest == null
        ? context.t('progress:notLogged')
        : [
            '${latest.toStringAsFixed(1)} ${context.t('progress:unitKg')}',
            if (change != null)
              '${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(1)} ${context.t('progress:unitKg')}',
          ].join(' · ');
    Widget link(String title, String sub, String route) => FitTrackCard(
          onTap: () => context.push(route),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FitTrackText.rowTitle.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FitTrackSpacing.md),
              Text(
                context.t('progress:open'),
                style: FitTrackText.label.copyWith(color: c.accent),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        link(
          context.t('progress:weightTrackingTitle'),
          caption,
          '/progress/weight',
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        link(
          context.t('progress:sleepTrackingTitle'),
          context.t('progress:sleepTrackingSub'),
          '/sleep',
        ),
      ],
    );
  }
}

/// Eight weekly bars (tonnes), the current week filled.
class _VolumeWeeks extends StatelessWidget {
  const _VolumeWeeks({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final peak = values.fold<double>(1, (a, b) => b > a ? b : a);
    return Semantics(
      label: context.t('progress:weeklyVolumeTitle'),
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: FractionallySizedBox(
                        heightFactor:
                            (values[i] / peak).clamp(0.04, 1).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == values.length - 1
                                ? c.workoutColor
                                : c.workoutColor.withValues(alpha: .35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i == values.length - 1
                          ? context.t('progress:now')
                          : context.t('progress:weekShort', args: {'n': i + 1}),
                      textAlign: TextAlign.center,
                      style: FitTrackText.caption.copyWith(
                        color: i == values.length - 1 ? c.ink : c.muted,
                        fontWeight: i == values.length - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Seven-day protein line against the goal.
class _ProteinLine extends StatelessWidget {
  const _ProteinLine({required this.values, required this.goal});
  final List<double> values;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final peak = [...values, goal, 1.0].reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: context.t(
        'progress:proteinTrendLabel',
        args: {'goal': goal.round()},
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 110,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: peak * 1.15,
              minX: 0,
              maxX: 6,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: goal,
                  color: c.muted,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ]),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i]),
                  ],
                  color: c.nutritionColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    checkToShowDot: (spot, _) => spot.x == 6,
                    getDotPainter: (a, b, d, e) =>
                        FlDotCirclePainter(radius: 4.5, color: c.nutritionColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One goal row: seven day cells, filled with a check when the goal was met.
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.label,
    required this.hits,
    required this.week,
    this.header = false,
  });
  final String label;
  final List<bool> hits;
  final List<DateTime> week;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final today = startOfDay(DateTime.now());
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FitTrackText.label.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (var i = 0; i < hits.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: header
                  ? Text(
                      DateFormat('E').format(week[i]).substring(0, 1),
                      textAlign: TextAlign.center,
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    )
                  : Semantics(
                      label:
                          '$label, ${DateFormat('EEEE').format(week[i])}: ${hits[i] ? context.t('progress:goalMet') : (week[i].isAfter(today) ? context.t('progress:goalUpcoming') : context.t('progress:goalMissed'))}',
                      child: ExcludeSemantics(
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: hits[i] ? c.ok : c.line,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: hits[i]
                              ? Icon(FitIcons.check, size: 14, color: c.bg)
                              : (week[i].isAfter(today)
                                  ? null
                                  : Icon(FitIcons.remove, size: 12, color: c.muted)),
                        ),
                      ),
                    ),
            ),
          ],
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
    final c = AppPalette.of(context);
    final weeks = heatGrid(DateTime.now(), days);
    const alphas = [0.0, .25, .45, .7, 1.0];
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
                                final level =
                                    heatLevel(byDay[dateKey(day)] ?? 0, max);
                                return level == 0
                                    ? c.line
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
