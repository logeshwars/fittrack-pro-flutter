import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../health/application/steps_controller.dart';
import '../../health/domain/health_steps.dart';
import '../../workouts/domain/workout_models.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/widgets/fittrack_icons.dart';

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
    final top = MediaQuery.paddingOf(context).top;
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
    // Boards: the hero is 172 (Night) or 190 (Pearl) tall including a 44px
    // status bar, and the summary card rides up over its lower edge.
    final heroHeight = top + (isDark ? 128.0 : 146.0);
    final overlap = isDark ? 36.0 : 60.0;
    final stepsKnown = steps.availability != StepsAvailability.unsupported;

    final summary = isDark
        ? _NightSummary(
            calories: data.calories,
            calorieGoal: data.calorieGoal,
            proteinG: data.proteinG,
            proteinGoalG: data.proteinGoalG,
            steps: stepsKnown ? steps.steps : null,
            stepGoal: data.stepGoal,
          )
        : _PearlSummary(
            calories: data.calories,
            calorieGoal: data.calorieGoal,
            caloriesPct: caloriesPct,
            proteinG: data.proteinG,
            proteinGoalG: data.proteinGoalG,
            proteinPct: proteinPct,
            steps: stepsKnown ? steps.steps : null,
            stepGoal: data.stepGoal,
            stepsPct: stepsPct,
          );

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.surface,
      edgeOffset: top,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
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
                top: top,
                left: 0,
                right: 0,
                child: _HeaderText(
                  greeting: firstName.isEmpty
                      ? greeting
                      : '$greeting $firstName',
                  motivation: _motivation(context, data.currentStreak),
                  streak: data.currentStreak,
                  initial:
                      firstName.isEmpty ? '?' : firstName[0].toUpperCase(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  FitTrackSpacing.gutter,
                  heroHeight - overlap,
                  FitTrackSpacing.gutter,
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
              icon: FitIcons.error,
            )
          else if (!data.configured && !loading)
            _StatusBanner(
              message: context.t('home:backendNotConfigured'),
              background: colors.warnSoft,
              foreground: colors.warn,
              icon: FitIcons.warning,
            )
          else if (!data.signedIn && !loading)
            _StatusBanner(
              message: context.t('home:signInPrompt'),
              background: colors.accentSoft,
              foreground: colors.accent,
              icon: FitIcons.signIn,
              onTap: () => context.push('/account'),
            ),
          if (steps.canConnect)
            _StatusBanner(
              message: context.t(
                'home:connectSteps',
                args: {
                  'store': healthStoreName(
                    isIos: Theme.of(context).platform == TargetPlatform.iOS,
                  ),
                },
              ),
              background: colors.accentSoft,
              foreground: colors.accent,
              icon: FitIcons.steps,
              onTap: () => unawaited(onConnectHealth()),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                FitTrackSpacing.gutter,
                FitTrackSpacing.gap,
                FitTrackSpacing.gutter,
                0,
              ),
              child: _LoadingBar(),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              FitTrackSpacing.gutter,
              isDark ? 16 : 14,
              FitTrackSpacing.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDark)
                  _YourDay(
                    meals: data.meals,
                    workoutToday: _workoutToday(data.recentWorkouts),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _HeroButton(
                          label: context.t('home:startWorkout'),
                          icon: FitIcons.play,
                          primary: true,
                          onPressed: () => context.go('/workout/new'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroButton(
                          label: context.t('home:logNutrition'),
                          icon: FitIcons.add,
                          primary: false,
                          onPressed: () => context.push('/nutrition/log'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: FitTrackSpacing.gap),
                _WeekCard(workouts: data.recentWorkouts, count: weekCount),
                const SizedBox(height: FitTrackSpacing.gap),
                FitTrackGrid(
                  children: [
                    _Tile(
                      label: context.t('home:sleepLabel'),
                      value: data.latestSleepMinutes == null
                          ? '–'
                          : _sleepDuration(data.latestSleepMinutes!),
                      caption: data.latestSleepMinutes == null
                          ? context.t('home:tapToLog')
                          : context.t('home:lastNight'),
                      onTap: () => context.push('/sleep'),
                    ),
                    _Tile(
                      label: context.t('home:weightLabel'),
                      value: data.latestWeightKg == null
                          ? '–'
                          : '${data.latestWeightKg!.toStringAsFixed(1)} ${context.t('home:unitKg')}',
                      caption: data.latestWeightKg == null
                          ? context.t('home:tapToLog')
                          : context.t('home:latestEntry'),
                      onTap: () => context.push('/progress/weight'),
                    ),
                  ],
                ),
                const SizedBox(height: FitTrackSpacing.gap),
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

  static Workout? _workoutToday(List<Workout> workouts) {
    final now = DateTime.now();
    for (final w in workouts) {
      if (w.startedAt.year == now.year &&
          w.startedAt.month == now.month &&
          w.startedAt.day == now.day) {
        return w;
      }
    }
    return null;
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [AppColors.heroDarkStart, AppColors.heroDarkEnd]
                : const [AppColors.heroLightStart, AppColors.heroLightEnd],
          ),
        ),
        child: ClipRect(
          child: CustomPaint(
            painter: _HeroPainter(
              isDark: isDark,
              surface: c.surface,
              accent: c.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter({
    required this.isDark,
    required this.surface,
    required this.accent,
  });

  final bool isDark;
  final Color surface;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      // Board: rings centred 70px from the right, 32px above the lower edge.
      final center = Offset(size.width - 70, size.height - 32);
      const rings = [(120.0, 0.5), (88.0, 0.7), (56.0, 0.9)];
      for (final (r, alpha) in rings) {
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = AppColors.heroDarkRing.withValues(alpha: alpha),
        );
      }
      canvas.drawCircle(
        center,
        30,
        Paint()..color = surface.withValues(alpha: 0.9),
      );
      canvas.drawCircle(center, 10, Paint()..color = accent);
    } else {
      final dot = Paint()..color = AppColors.heroLightDot.withValues(alpha: 0.7);
      for (var x = 3.0; x < size.width; x += 22) {
        for (var y = 3.0; y < size.height; y += 22) {
          canvas.drawCircle(Offset(x, y), 2, dot);
        }
      }
      final center = Offset(size.width - 72, size.height - 48);
      canvas.drawCircle(
        center,
        40,
        Paint()..color = surface.withValues(alpha: 0.9),
      );
      canvas.drawCircle(center, 14, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.isDark != isDark || old.surface != surface || old.accent != accent;
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.greeting,
    required this.motivation,
    required this.streak,
    required this.initial,
  });

  final String greeting;
  final String motivation;
  final int streak;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        FitTrackSpacing.xl,
        FitTrackSpacing.sm,
        FitTrackSpacing.lg,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitTrackText.greeting.copyWith(color: c.ink),
                  ),
                ),
              ),
              const SizedBox(width: FitTrackSpacing.sm),
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
                        // 38px disc with a 3px surface ring around it.
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.accent,
                            border: Border.all(color: c.surface, width: 3),
                          ),
                          child: Text(
                            initial,
                            style: FitTrackText.titleHeavy
                                .copyWith(color: c.onAccent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  motivation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.label.copyWith(
                    color: c.ink.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: FitTrackSpacing.sm),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(FitTrackRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FitIcons.streakBold, size: 14, color: c.accent),
                        const SizedBox(width: 6),
                        Text(
                          context.t('home:daysChip', args: {'days': streak}),
                          style: FitTrackText.label.copyWith(
                            color: c.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

/// The soft lift under the summary card on both boards.
const _summaryShadow = AppTheme.lift;

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

  /// Null when the device cannot report steps.
  final int? steps;
  final int stepGoal;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final g = context.t('home:unitG');
    Widget cell(String label, String value, String of, {bool first = false}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: first
                  ? null
                  : BorderDirectional(start: BorderSide(color: c.line)),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.heroStat.copyWith(color: c.ink),
                ),
                Text(
                  of,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          FitTrackRadius.hero(Theme.of(context).brightness),
        ),
        boxShadow: _summaryShadow,
      ),
      child: FitTrackCard(
        radius: FitTrackRadius.hero(Theme.of(context).brightness),
        padding: const EdgeInsets.symmetric(vertical: FitTrackSpacing.cardPad),
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
                '${_num(proteinG)} $g',
                context.t('home:ofGoal', args: {'goal': '$proteinGoalG $g'}),
              ),
              cell(
                context.t('home:stepsLabel'),
                steps == null ? '–' : formatSteps(steps!),
                context.t('home:ofGoal', args: {'goal': _num(stepGoal)}),
              ),
            ],
          ),
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

  /// Null when the device cannot report steps.
  final int? steps;
  final int stepGoal;
  final double stepsPct;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final g = context.t('home:unitG');
    Widget bar(String label, String value, String of, double pct) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitTrackText.label.copyWith(color: c.muted),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: FitTrackText.label.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    children: [
                      TextSpan(
                        text: ' / $of',
                        style: FitTrackText.label.copyWith(
                          color: c.muted,
                          fontWeight: FontWeight.w500,
                        ),
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

    final radius = FitTrackRadius.hero(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _summaryShadow,
      ),
      child: FitTrackCard(
        radius: radius,
        padding: const EdgeInsets.all(FitTrackSpacing.lg),
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
                    style: FitTrackText.ringStat.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 2),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  bar(
                    context.t('home:proteinLabel'),
                    _num(proteinG),
                    '$proteinGoalG $g',
                    proteinPct,
                  ),
                  const SizedBox(height: FitTrackSpacing.cardPad),
                  bar(
                    context.t('home:stepsLabel'),
                    steps == null ? '–' : formatSteps(steps!),
                    _num(stepGoal),
                    stepsPct,
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

/// 48px call to action on the Pearl board: filled or outlined.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FitTrackButton(
        label: label,
        icon: icon,
        size: FitTrackButtonSize.lg,
        variant: primary
            ? FitTrackButtonVariant.primary
            : FitTrackButtonVariant.secondary,
        fullWidth: true,
        onPressed: onPressed,
      );
}

/// Night "Your day" timeline: the meals logged today in order, the next
/// meal to log, then today's workout.
class _YourDay extends StatelessWidget {
  const _YourDay({required this.meals, required this.workoutToday});
  final List<DashboardMeal> meals;
  final Workout? workoutToday;

  static const _order = ['breakfast', 'lunch', 'snack', 'dinner'];

  String _mealName(BuildContext context, String type) => switch (type) {
        'breakfast' => context.t('nutrition:breakfast'),
        'lunch' => context.t('nutrition:lunch'),
        'dinner' => context.t('nutrition:dinner'),
        'snack' => context.t('nutrition:snack'),
        'post_workout' => context.t('nutrition:postworkout'),
        _ => context.t('nutrition:other'),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final radius = FitTrackRadius.hero(Theme.of(context).brightness);
    final logged = {for (final m in meals) m.type};
    String? next;
    for (final type in _order) {
      if (!logged.contains(type)) {
        next = type;
        break;
      }
    }
    final time = DateFormat('h:mm a');
    final w = workoutToday;

    final rows = <_DayRow>[
      for (final m in meals)
        _DayRow(
          done: true,
          overline: time.format(m.firstLoggedAt).toLowerCase(),
          title: _mealName(context, m.type),
          trailing: '${_num(m.calories)} ${context.t('home:unitKcal')}',
          onTap: () => context.go('/nutrition'),
        ),
      if (next != null)
        _DayRow(
          done: false,
          overline: context.t('home:nextLabel'),
          title: _mealName(context, next),
          action: context.t('home:logMeal'),
          onTap: () => context.push('/nutrition/log?meal=$next'),
        ),
      if (w != null)
        _DayRow(
          done: true,
          overline: time.format(w.startedAt.toLocal()).toLowerCase(),
          title: w.name,
          trailing: w.totalVolumeKg > 0
              ? '${_num(w.totalVolumeKg)} ${context.t('home:unitKg')}'
              : context.t('home:trained'),
          onTap: () => context.push('/workout/history/${w.id}'),
        )
      else
        _DayRow(
          done: false,
          overline: context.t('home:todayLabel'),
          title: context.t('home:workoutRow'),
          action: context.t('home:startShort'),
          onTap: () => context.go('/workout/new'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 10),
          child: Semantics(
            header: true,
            child: Text(
              context.t('home:yourDay'),
              style: FitTrackText.section.copyWith(color: c.ink),
            ),
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Rail: 2px line through the 12px dots.
                  SizedBox(
                    width: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (i < rows.length - 1)
                          PositionedDirectional(
                            start: 5,
                            top: 12,
                            bottom: -18,
                            child: Container(width: 2, color: c.line),
                          ),
                        PositionedDirectional(
                          start: 0,
                          top: 4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rows[i].done ? c.accent : c.bg,
                              border: rows[i].done
                                  ? null
                                  : Border.all(color: c.accent, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _DayCard(row: rows[i], radius: radius),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DayRow {
  const _DayRow({
    required this.done,
    required this.overline,
    required this.title,
    required this.onTap,
    this.trailing,
    this.action,
  });
  final bool done;
  final String overline;
  final String title;
  final String? trailing;
  final String? action;
  final VoidCallback onTap;
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.row, required this.radius});
  final _DayRow row;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final shape = BorderRadius.circular(radius);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    row.overline,
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitTrackText.titleHeavy.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FitTrackSpacing.md),
            if (row.trailing != null)
              Text(
                row.trailing!,
                style: FitTrackText.caption.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            else if (row.action != null)
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(FitTrackRadius.pill),
                ),
                child: Text(
                  row.action!,
                  style: FitTrackText.caption.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: [
        row.overline,
        row.title,
        if (row.trailing != null) row.trailing!,
        if (row.action != null) row.action!,
      ].join(', '),
      child: ExcludeSemantics(
        child: Material(
          color: c.surface,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: row.onTap,
            child: row.done
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: shape,
                      border: Border.all(color: c.line),
                    ),
                    child: content,
                  )
                : FitTrackDashedBorder(
                    color: c.line,
                    radius: radius,
                    child: content,
                  ),
          ),
        ),
      ),
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
    final radius = BorderRadius.circular(FitTrackRadius.card);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.gutter,
        FitTrackSpacing.gap,
        FitTrackSpacing.gutter,
        0,
      ),
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: FitTrackSpacing.touchMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FitTrackSpacing.md,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: FitTrackSpacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: FitTrackText.label.copyWith(color: foreground),
                    ),
                  ),
                  if (onTap != null)
                    Icon(FitIcons.chevronRight, size: 16, color: foreground),
                ],
              ),
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
    final brightness = Theme.of(context).brightness;
    final tile = BorderRadius.circular(
      brightness == Brightness.dark ? FitTrackRadius.card : FitTrackRadius.sm,
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
      radius: FitTrackRadius.hero(brightness),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  context.t('home:thisWeek'),
                  style: FitTrackText.titleHeavy.copyWith(color: c.ink),
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
              final dayName = DateFormat('EEEE').format(date);

              final Widget box;
              final String state;
              if (hit) {
                state = context.t('home:trained');
                box = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: c.accent, borderRadius: tile),
                  child: Icon(FitIcons.check, size: 16, color: c.onAccent),
                );
              } else if (isToday) {
                state = context.t('home:todayLabel');
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
                state = '';
                box = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: tile,
                    border: Border.all(color: c.line),
                  ),
                );
              } else {
                state = context.t('home:rest');
                box = Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.line, borderRadius: tile),
                  child: Text(
                    '–',
                    style: FitTrackText.body.copyWith(color: c.muted),
                  ),
                );
              }

              return Expanded(
                child: Semantics(
                  label: state.isEmpty ? dayName : '$dayName, $state',
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          maxLines: 1,
                          style: FitTrackText.caption.copyWith(
                            color: isToday ? c.accent : c.muted,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        box,
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Sleep and weight tiles: caption label, 22 / 800 value, caption line.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.caption,
    required this.onTap,
  });
  final String label;
  final String value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      label: '$label, $value, $caption',
      child: ExcludeSemantics(
        child: FitTrackCard(
          radius: FitTrackRadius.hero(Theme.of(context).brightness),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FitTrackText.tileStat.copyWith(color: c.ink),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
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
      radius: FitTrackRadius.hero(Theme.of(context).brightness),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FitTrackSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        context.t('home:recentTitle'),
                        style: FitTrackText.titleHeavy.copyWith(color: c.ink),
                      ),
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
                            widthFactor: 1,
                            child: Text(
                              context.t('home:seeAll'),
                              style: FitTrackText.label.copyWith(
                                color: c.accent,
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
    final parts = <String>[
      DateFormat('EEE d MMM').format(workout.startedAt),
      if (minutes != null)
        context.t('home:durationMin', args: {'minutes': minutes})
      else
        context.t('home:setsCount', args: {'count': workout.sets.length}),
    ];
    return InkWell(
      onTap: () => context.push('/workout/history/${workout.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(
          horizontal: FitTrackSpacing.lg,
          vertical: FitTrackSpacing.sm,
        ),
        decoration:
            BoxDecoration(border: Border(top: BorderSide(color: c.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                    parts.join(' · '),
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            if (workout.totalVolumeKg > 0) ...[
              const SizedBox(width: FitTrackSpacing.md),
              FitTrackValue(
                value: _num(workout.totalVolumeKg),
                unit: context.t('home:unitKg'),
                style: FitTrackText.title.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
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
      radius: FitTrackRadius.hero(Theme.of(context).brightness),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentSoft,
            ),
            child: Icon(FitIcons.workout, size: 24, color: c.accent),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          Text(
            context.t('home:noWorkouts'),
            style: FitTrackText.titleHeavy.copyWith(color: c.ink),
          ),
          const SizedBox(height: FitTrackSpacing.xs),
          Text(
            context.t('home:noWorkoutsDesc'),
            textAlign: TextAlign.center,
            style: FitTrackText.caption.copyWith(color: c.muted),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          FitTrackButton(
            label: context.t('home:startFirstWorkout'),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
