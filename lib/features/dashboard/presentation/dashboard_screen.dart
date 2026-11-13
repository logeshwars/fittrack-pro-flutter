import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../health/application/steps_controller.dart';
import '../../health/domain/health_steps.dart';
import '../../workouts/domain/workout_models.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final stepsState = ref.watch(stepsProvider);
    Future<void> refresh() async {
      ref.invalidate(dashboardProvider);
      unawaited(ref.read(stepsProvider.notifier).refresh());
      await ref.read(dashboardProvider.future);
    }

    Future<void> connectHealth() => ref.read(stepsProvider.notifier).connect();

    return state.when(
      loading: () => _DashboardBody(
        data: const DashboardData(configured: false, signedIn: false),
        loading: true,
        steps: stepsState,
        onConnectHealth: connectHealth,
        onRefresh: refresh,
      ),
      error: (error, _) => _DashboardBody(
        data: const DashboardData(configured: false, signedIn: false),
        failed: true,
        steps: stepsState,
        onConnectHealth: connectHealth,
        onRefresh: refresh,
      ),
      data: (data) => _DashboardBody(
        data: data,
        steps: stepsState,
        onConnectHealth: connectHealth,
        onRefresh: refresh,
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.onRefresh,
    required this.steps,
    required this.onConnectHealth,
    this.loading = false,
    this.failed = false,
  });

  final DashboardData data;
  final Future<void> Function() onRefresh;
  final StepsState steps;
  final Future<void> Function() onConnectHealth;
  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final firstName = data.displayName.trim().split(' ').first;
    final greeting = _greeting(context, now.hour);
    final proteinPct = data.proteinGoalG > 0
        ? (data.proteinG / data.proteinGoalG).clamp(0, 1).toDouble()
        : 0.0;
    final caloriesPct = data.calorieGoal > 0
        ? (data.calories / data.calorieGoal).clamp(0, 1).toDouble()
        : 0.0;
    final stepsPct = stepsProgress(steps.steps, data.stepGoal.toDouble());
    final weekCount = _weekWorkoutCount(data.recentWorkouts);
    final heroHeight = isDark ? 150.0 : 168.0;
    final overlap = isDark ? 36.0 : 60.0;

    final summary = isDark
        ? _NightSummary(
            calories: data.calories,
            calorieGoal: data.calorieGoal,
            proteinG: data.proteinG,
            proteinGoalG: data.proteinGoalG,
            steps: steps.steps,
            stepGoal: data.stepGoal,
          )
        : _PearlSummary(
            calories: data.calories,
            calorieGoal: data.calorieGoal,
            caloriesPct: caloriesPct,
            proteinG: data.proteinG,
            proteinGoalG: data.proteinGoalG,
            proteinPct: proteinPct,
            steps: steps.steps,
            stepGoal: data.stepGoal,
            stepsPct: stepsPct,
          );

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: FitTrackSpacing.tabBarClearance - 60,
        ),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: _Hero(isDark: isDark),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HeaderText(
                  greeting: '$greeting $firstName',
                  motivation: _motivation(context, data.currentStreak),
                  streak: data.currentStreak,
                  level: data.level,
                  initial:
                      firstName.isEmpty ? '?' : firstName[0].toUpperCase(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  heroHeight - overlap,
                  FitTrackSpacing.lg,
                  0,
                ),
                child: Semantics(
                  container: true,
                  label: context.t('home:summaryLabel'),
                  child: summary,
                ),
              ),
            ],
          ),
          if (failed)
            _StatusBanner(
              message: context.t('home:dashboardUnavailable'),
              background: colors.badSoft,
              foreground: colors.textBad,
              icon: Icons.error_outline,
            )
          else if (!data.configured && !loading)
            _StatusBanner(
              message: context.t('home:backendNotConfigured'),
              background: colors.warnSoft,
              foreground: colors.warn,
              icon: Icons.warning_amber_outlined,
            )
          else if (!data.signedIn && !loading)
            _StatusBanner(
              message: context.t('home:signInPrompt'),
              background: colors.accentSoft,
              foreground: colors.ink,
              icon: Icons.login,
              onTap: () => context.push('/account'),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _LoadingBar(),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      if (steps.canConnect)
                        FitTrackButton(
                      label: context.t(
                        'home:connectSteps',
                        args: {
                          'store': healthStoreName(
                            isIos:
                                Theme.of(context).platform == TargetPlatform.iOS,
                          ),
                        },
                      ),
                      icon: Icons.directions_walk,
                      variant: FitTrackButtonVariant.ghost,
                      size: FitTrackButtonSize.sm,
                      onPressed: () => unawaited(onConnectHealth()),
                        ),
                      FitTrackButton(
                        label: context.t('home:goals'),
                        icon: Icons.flag_outlined,
                        variant: FitTrackButtonVariant.ghost,
                        size: FitTrackButtonSize.sm,
                        onPressed: () => context.go('/progress'),
                      ),
                    ],
                  ),
                ),
                _XpStrip(totalXp: data.totalXp, level: data.level),
                const SizedBox(height: FitTrackSpacing.md),
                if (steps.availability == StepsAvailability.unsupported)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FitTrackSpacing.md),
                    child: FitTrackBadge(
                      label: context.t('home:stepsUnsupported'),
                      tone: FitTrackBadgeTone.info,
                      icon: Icons.info_outline,
                    ),
                  ),
                if (isDark)
                  _YourDay(
                    calories: data.calories,
                    trainedToday: _trainedToday(data.recentWorkouts),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FitTrackButton(
                          label: context.t('home:startWorkout'),
                          icon: Icons.play_arrow_rounded,
                          fullWidth: true,
                          onPressed: () => context.go('/workout/new'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FitTrackButton(
                          label: context.t('home:logNutrition'),
                          icon: Icons.add,
                          variant: FitTrackButtonVariant.secondary,
                          fullWidth: true,
                          onPressed: () => context.go('/nutrition/draft'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackSectionLabel(title: context.t('home:quickActions')),
                FitTrackLogBanner(
                  domainColor: colors.workoutColor,
                  icon: Icons.fitness_center,
                  overline: context.t('home:workoutRow'),
                  title: context.t('home:startWorkout'),
                  xp: context.t('home:xpReward', args: {'xp': 50}),
                  onTap: () => context.go('/workout/new'),
                ),
                const SizedBox(height: FitTrackSpacing.sm),
                FitTrackLogBanner(
                  domainColor: colors.nutritionColor,
                  icon: Icons.restaurant,
                  overline: context.t('home:nutritionRow'),
                  title: context.t('home:logNutrition'),
                  caption: context.t('home:trackProtein'),
                  onTap: () => context.go('/nutrition/draft'),
                ),
                const SizedBox(height: FitTrackSpacing.md),
                _WeekCard(workouts: data.recentWorkouts, count: weekCount),
                const SizedBox(height: FitTrackSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: FitTrackStatTile(
                        label: context.t('home:sleepLabel'),
                        value: data.latestSleepMinutes == null
                            ? context.t('home:notLogged')
                            : _sleepDuration(data.latestSleepMinutes!),
                        caption: data.sleepQuality == null
                            ? context.t('home:lastNight')
                            : '${_qualityStars(data.sleepQuality!)} '
                                '(${context.t('home:starsLabel', args: {
                                      'count': data.sleepQuality!.clamp(0, 5)
                                    })})',
                        onTap: () => context.push('/sleep'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FitTrackStatTile(
                        label: context.t('home:weightLabel'),
                        value: data.latestWeightKg == null
                            ? context.t('home:notLogged')
                            : '${data.latestWeightKg!.toStringAsFixed(1)} ${context.t('home:unitKg')}',
                        caption: data.latestWeightKg == null
                            ? context.t('home:tapToLog')
                            : context.t('home:latestEntry'),
                        onTap: () => context.push('/progress/weight'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FitTrackSpacing.md),
                if (data.recentWorkouts.isNotEmpty)
                  _RecentWorkouts(
                    workouts: data.recentWorkouts.take(3).toList(),
                    onSeeAll: () => context.go('/workout'),
                  ),
                if (data.recentWorkouts.isEmpty && !loading)
                  _EmptyWorkout(onTap: () => context.go('/workout/new')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting(BuildContext context, int hour) {
    if (hour < 5) return context.t('home:greetingLate');
    if (hour < 12) return context.t('home:greetingMorning');
    if (hour < 17) return context.t('home:greetingAfternoon');
    return context.t('home:greetingEvening');
  }

  static String _motivation(BuildContext context, int streak) {
    if (streak <= 0) return context.t('home:motivationStart');
    if (streak == 1) return context.t('home:motivationDay1');
    if (streak < 7) {
      return context.t('home:motivationWeekly', args: {'days': 7 - streak});
    }
    if (streak == 7) return context.t('home:motivationWeek7');
    if (streak < 30) {
      return context.t('home:motivationMonthly', args: {'days': 30 - streak});
    }
    if (streak == 30) return context.t('home:motivationMonth30');
    return context.t('home:motivationElite', args: {'streak': streak});
  }

  static int _weekWorkoutCount(List<Workout> workouts) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return workouts
        .where((workout) => !workout.startedAt.isBefore(monday))
        .length;
  }

  static bool _trainedToday(List<Workout> workouts) {
    final now = DateTime.now();
    return workouts.any(
      (w) =>
          w.startedAt.year == now.year &&
          w.startedAt.month == now.month &&
          w.startedAt.day == now.day,
    );
  }

  static String _qualityStars(int quality) {
    final safe = quality.clamp(0, 5).toInt();
    return '${List.filled(safe, '★').join()}${List.filled(5 - safe, '☆').join()}';
  }

  static String _sleepDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

/// Decorative hero. Night: concentric rings; Pearl: dot grid and a disc.
class _Hero extends StatelessWidget {
  const _Hero({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return ExcludeSemantics(
      child: ColoredBox(
        color: c.surface,
        child: CustomPaint(
          painter: _HeroPainter(
            isDark: isDark,
            line: c.line,
            lineStrong: c.lineStrong,
            surface: c.surface,
            accent: c.accent,
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter({
    required this.isDark,
    required this.line,
    required this.lineStrong,
    required this.surface,
    required this.accent,
  });

  final bool isDark;
  final Color line;
  final Color lineStrong;
  final Color surface;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      final center = Offset(size.width - 70, size.height - 20);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = lineStrong;
      for (final r in [120.0, 88.0, 56.0]) {
        canvas.drawCircle(center, r, ring);
      }
      canvas.drawCircle(center, 30, Paint()..color = line);
      canvas.drawCircle(center, 10, Paint()..color = accent);
    } else {
      final dot = Paint()..color = lineStrong.withValues(alpha: 0.7);
      for (var x = 3.0; x < size.width; x += 22) {
        for (var y = 3.0; y < size.height; y += 22) {
          canvas.drawCircle(Offset(x, y), 2, dot);
        }
      }
      final center = Offset(size.width - 72, size.height - 36);
      canvas.drawCircle(center, 40, Paint()..color = surface);
      canvas.drawCircle(center, 14, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.isDark != isDark ||
      old.line != line ||
      old.lineStrong != lineStrong ||
      old.surface != surface ||
      old.accent != accent;
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.greeting,
    required this.motivation,
    required this.streak,
    required this.level,
    required this.initial,
  });

  final String greeting;
  final String motivation;
  final int streak;
  final int level;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.xl,
        FitTrackSpacing.lg,
        FitTrackSpacing.xl,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.screenTitle.copyWith(color: c.ink),
                ),
              ),
              Semantics(
                button: true,
                label: context.t('home:profileLabel'),
                child: ExcludeSemantics(
                  child: InkResponse(
                    onTap: () => context.push('/profile'),
                    radius: 24,
                    child: SizedBox(
                      width: FitTrackSpacing.touchMin,
                      height: FitTrackSpacing.touchMin,
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.accent,
                            border: Border.all(color: c.surface, width: 3),
                          ),
                          child: Text(
                            initial,
                            style: FitTrackText.title.copyWith(
                              color: c.onAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  motivation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.label.copyWith(color: c.ink),
                ),
              ),
              const SizedBox(width: FitTrackSpacing.sm),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(FitTrackRadius.pill),
                ),
                child: Text(
                  context.t('home:levelChip', args: {'level': level}),
                  style: FitTrackText.label.copyWith(
                    color: c.onAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: FitTrackSpacing.sm),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(FitTrackRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_outlined,
                        size: 14,
                        color: c.ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.t('home:daysChip', args: {'days': streak}),
                        style: FitTrackText.label.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _num(num value) => NumberFormat('#,##0').format(value.round());

/// Night summary: three equal columns separated by `line` dividers.
class _NightSummary extends StatelessWidget {
  const _NightSummary({
    required this.calories,
    required this.calorieGoal,
    required this.proteinG,
    required this.proteinGoalG,
    required this.steps,
    required this.stepGoal,
  });

  final double calories;
  final int calorieGoal;
  final double proteinG;
  final int proteinGoalG;
  final int steps;
  final int stepGoal;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    Widget cell(String label, String value, String of, {bool first = false}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: first
                  ? null
                  : Border(left: BorderSide(color: c.line)),
            ),
            child: Column(
              children: [
                Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: FitTrackText.stat.copyWith(color: c.ink),
                ),
                Text(of, style: FitTrackText.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
        );

    return FitTrackCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(
              context.t('home:caloriesLabel'),
              _num(calories),
              context.t('home:ofGoal', args: {'goal': _num(calorieGoal)}),
              first: true,
            ),
            cell(
              context.t('home:proteinLabel'),
              '${_num(proteinG)} g',
              context.t('home:ofGoal', args: {'goal': '$proteinGoalG g'}),
            ),
            cell(
              context.t('home:stepsLabel'),
              formatSteps(steps),
              context.t('home:ofGoal', args: {'goal': _num(stepGoal)}),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pearl summary: calorie ring with protein and steps bars beside it.
class _PearlSummary extends StatelessWidget {
  const _PearlSummary({
    required this.calories,
    required this.calorieGoal,
    required this.caloriesPct,
    required this.proteinG,
    required this.proteinGoalG,
    required this.proteinPct,
    required this.steps,
    required this.stepGoal,
    required this.stepsPct,
  });

  final double calories;
  final int calorieGoal;
  final double caloriesPct;
  final double proteinG;
  final int proteinGoalG;
  final double proteinPct;
  final int steps;
  final int stepGoal;
  final double stepsPct;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    Widget bar(String label, String value, String of, double pct) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label,
                    style: FitTrackText.label.copyWith(color: c.muted)),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: FitTrackText.label.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: ' / $of',
                        style: FitTrackText.label.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FitTrackProgressBar(progress: pct, semanticLabel: label),
          ],
        );

    return FitTrackCard(
      child: Row(
        children: [
          FitTrackStatRing(
            progress: caloriesPct,
            color: c.accent,
            size: 118,
            strokeWidth: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _num(calories),
                  style: FitTrackText.stat.copyWith(color: c.ink),
                ),
                Text(
                  context.t(
                    'home:ofGoalKcal',
                    args: {'goal': _num(calorieGoal)},
                  ),
                  textAlign: TextAlign.center,
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                bar(
                  context.t('home:proteinLabel'),
                  _num(proteinG),
                  '$proteinGoalG g',
                  proteinPct,
                ),
                const SizedBox(height: 14),
                bar(
                  context.t('home:stepsLabel'),
                  formatSteps(steps),
                  _num(stepGoal),
                  stepsPct,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Night "Your day" timeline built from data the dashboard already has:
/// today's calories and whether a workout was logged today.
class _YourDay extends StatelessWidget {
  const _YourDay({required this.calories, required this.trainedToday});
  final double calories;
  final bool trainedToday;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    Widget row({
      required bool done,
      required String overline,
      required String title,
      required String action,
      required VoidCallback onTap,
      String? trailing,
      bool last = false,
    }) =>
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (!last)
                        Positioned(
                          top: 14,
                          bottom: -14,
                          child: Container(width: 2, color: c.line),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? c.accent : c.bg,
                            border: done
                                ? null
                                : Border.all(color: c.accent, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FitTrackCard(
                    onTap: onTap,
                    padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  overline,
                                  style: FitTrackText.caption
                                      .copyWith(color: c.muted),
                                ),
                                Text(
                                  title,
                                  style: FitTrackText.title.copyWith(
                                    color: c.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (trailing != null)
                            Text(
                              trailing,
                              style: FitTrackText.caption.copyWith(
                                color: c.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            FitTrackBadge(
                              label: action,
                              tone: FitTrackBadgeTone.info,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, FitTrackSpacing.sm),
          child: Text(
            context.t('home:yourDay'),
            style: FitTrackText.titleLg.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        row(
          done: calories > 0,
          overline: context.t('home:todayLabel'),
          title: context.t('home:nutritionRow'),
          action: context.t('home:logMeal'),
          trailing: calories > 0
              ? '${_num(calories)} ${context.t('home:unitKcal')}'
              : null,
          onTap: () => context.go('/nutrition/draft'),
        ),
        row(
          done: trainedToday,
          overline: context.t('home:todayLabel'),
          title: context.t('home:workoutRow'),
          action: context.t('home:startShort'),
          trailing: trainedToday ? context.t('home:trained') : null,
          onTap: () => context.go('/workout/new'),
          last: true,
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.background,
    required this.foreground,
    required this.icon,
    this.onTap,
  });

  final String message;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(FitTrackRadius.md);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(FitTrackSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: FitTrackSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: FitTrackText.caption.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
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

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return LinearProgressIndicator(
      minHeight: 3,
      backgroundColor: c.line,
      color: c.accent,
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.workouts, required this.count});
  final List<Workout> workouts;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tile = BorderRadius.circular(
      isDark ? FitTrackRadius.md : FitTrackRadius.sm,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday =
        today.subtract(Duration(days: now.weekday - DateTime.monday));
    final workoutDays = workouts
        .map((w) =>
            DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day))
        .toSet();

    return FitTrackCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                context.t('home:thisWeek'),
                style: FitTrackText.title.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                context.t('home:workoutsCount', args: {'count': count}),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.md),
          Row(
            children: List.generate(7, (index) {
              final date = monday.add(Duration(days: index));
              final hit = workoutDays.contains(date);
              final isToday = date == today;
              final isFuture = date.isAfter(today);

              Widget box;
              if (hit) {
                box = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: c.accent, borderRadius: tile),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: c.onAccent,
                    semanticLabel: context.t('home:trained'),
                  ),
                );
              } else if (isToday) {
                box = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: tile,
                    border: Border.all(color: c.accent, width: 2),
                  ),
                );
              } else if (isFuture) {
                box = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: tile,
                    border: Border.all(color: c.line),
                  ),
                );
              } else {
                box = Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.line, borderRadius: tile),
                  child: Text(
                    '–',
                    semanticsLabel: context.t('home:rest'),
                    style: FitTrackText.body.copyWith(color: c.muted),
                  ),
                );
              }

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE').format(date),
                      style: FitTrackText.caption.copyWith(
                        color: isToday ? c.ink : c.muted,
                        fontWeight:
                            isToday ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    box,
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Level progress: 500 XP per level, same maths as before the redesign.
class _XpStrip extends StatelessWidget {
  const _XpStrip({required this.totalXp, required this.level});
  final int totalXp;
  final int level;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final base = (level - 1) * 500;
    final cap = level * 500;
    final pct = cap > base
        ? ((totalXp - base) / (cap - base)).clamp(0, 1).toDouble()
        : 0.0;
    return FitTrackCard(
      padding: const EdgeInsets.symmetric(
        horizontal: FitTrackSpacing.lg,
        vertical: FitTrackSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: c.xpColor),
              const SizedBox(width: 6),
              Text(
                context.t('home:xpLabel'),
                style: FitTrackText.overline.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                context.t(
                  'home:xpProgress',
                  args: {'xp': _num(totalXp), 'cap': _num(cap)},
                ),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.sm),
          FitTrackProgressBar(
            progress: pct,
            color: c.xpColor,
            semanticLabel: context.t('home:xpLabel'),
          ),
        ],
      ),
    );
  }
}

class _RecentWorkouts extends StatelessWidget {
  const _RecentWorkouts({required this.workouts, required this.onSeeAll});
  final List<Workout> workouts;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.t('home:recentTitle'),
                    style: FitTrackText.title.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: context.t('home:seeAll'),
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: onSeeAll,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: FitTrackSpacing.touchMin,
                          ),
                          child: Center(
                            child: Text(
                              context.t('home:seeAll'),
                              style: FitTrackText.label.copyWith(
                                color: c.ink,
                                fontWeight: FontWeight.w700,
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
          ),
          for (final workout in workouts) _WorkoutRow(workout: workout),
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final minutes = workout.finishedAt?.difference(workout.startedAt).inMinutes;
    final when = DateFormat('EEE d MMM').format(workout.startedAt);
    final parts = <String>[
      when,
      context.t('home:setsCount', args: {'count': workout.sets.length}),
      if (minutes != null)
        context.t('home:durationMin', args: {'minutes': minutes}),
    ];
    final caption = parts.join(' · ');
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.title.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          if (workout.totalVolumeKg > 0)
            Text.rich(
              TextSpan(
                text: _num(workout.totalVolumeKg),
                style: FitTrackText.title.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: ' ${context.t('home:unitKg')}',
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyWorkout extends StatelessWidget {
  const _EmptyWorkout({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentSoft,
            ),
            child: Icon(Icons.fitness_center, size: 24, color: c.ink),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('home:noWorkouts'),
            style: FitTrackText.title.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('home:noWorkoutsDesc'),
            textAlign: TextAlign.center,
            style: FitTrackText.caption.copyWith(color: c.muted),
          ),
          const SizedBox(height: 12),
          FitTrackButton(
            label: context.t('home:startFirstWorkout'),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
