import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../workouts/domain/workout_models.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return state.when(
      loading: () => _DashboardBody(
        data: const DashboardData(configured: false, signedIn: false),
        loading: true,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
      ),
      error: (error, _) => _DashboardBody(
        data: const DashboardData(configured: false, signedIn: false),
        message: 'Dashboard unavailable. Pull to retry.',
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
      ),
      data: (data) => _DashboardBody(
        data: data,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.onRefresh,
    this.loading = false,
    this.message,
  });

  final DashboardData data;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? message;

  static const _calorieGoal = 2000;
  static const _stepGoal = 10000;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final now = DateTime.now();
    final firstName = data.displayName.trim().split(' ').first;
    final greeting = _greeting(now.hour);
    final proteinPct = data.proteinGoalG > 0
        ? (data.proteinG / data.proteinGoalG).clamp(0, 1).toDouble()
        : 0.0;
    final caloriesPct =
        (data.calories / _calorieGoal).clamp(0, 1).toDouble();
    const steps = 0;
    const stepsPct = 0.0;
    final xpBase = (data.level - 1) * 500;
    final xpCap = data.level * 500;
    final xpPct = xpCap > xpBase
        ? ((data.totalXp - xpBase) / (xpCap - xpBase)).clamp(0, 1).toDouble()
        : 0.0;

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 44),
        children: [
          Container(
            color: colors.header,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  DateFormat('EEE').format(now).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: colors.accentText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMMM d, yyyy').format(now),
                                style: FitTrackText.caption.copyWith(
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            greeting,
                            style: FitTrackText.stat.copyWith(
                              color: colors.text,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -2),
                            child: Text(
                              '$firstName 💪',
                              style: FitTrackText.stat.copyWith(
                                color: colors.accent,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push('/account'),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.accent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              firstName.isEmpty
                                  ? '?'
                                  : firstName[0].toUpperCase(),
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'LVL ${data.level}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: colors.accentText,
                                  ),
                                ),
                              ),
                              if (data.currentStreak > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardio.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.cardio.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        size: 10,
                                        color: AppColors.cardio,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${data.currentStreak}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cardio,
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
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.bolt, size: 12, color: colors.accent),
                    const SizedBox(width: 5),
                    Text(
                      'XP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${data.totalXp} / $xpCap',
                      style: TextStyle(fontSize: 10, color: colors.faint),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: xpPct,
                    minHeight: 6,
                    backgroundColor: colors.border2,
                    valueColor: AlwaysStoppedAnimation(colors.accent),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: colors.border),
          if (message != null)
            _StatusBanner(
              message: message!,
              color: colors.danger,
            )
          else if (!data.configured)
            const _StatusBanner(
              message: 'Backend not configured. Add the Supabase build secrets to load live data.',
              color: AppColors.warningDark,
            )
          else if (!data.signedIn)
            _StatusBanner(
              message: 'Sign in to load your FitTrack Pro dashboard.',
              color: colors.accent,
              onTap: () => context.push('/account'),
            ),
          if (loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: colors.border2,
                color: colors.accent,
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                FitTrackSectionLabel(
                  title: "Today's Progress",
                  action: 'Goals',
                  onAction: () => context.go('/progress'),
                ),
                Row(
                  children: [
                    FitTrackMiniRing(
                      progress: proteinPct,
                      color: AppColors.nutrition,
                      icon: Icons.restaurant,
                      value: '${data.proteinG.toStringAsFixed(0)}g',
                      label: 'Protein',
                      sublabel: '/ ${data.proteinGoalG}g',
                      done: data.proteinG >= data.proteinGoalG &&
                          data.proteinGoalG > 0,
                    ),
                    _VerticalDivider(color: colors.border2),
                    FitTrackMiniRing(
                      progress: caloriesPct,
                      color: AppColors.workout,
                      icon: Icons.local_fire_department,
                      value: data.calories.toStringAsFixed(0),
                      label: 'Calories',
                      sublabel: '/ $_calorieGoal kcal',
                      done: data.calories >= _calorieGoal,
                    ),
                    _VerticalDivider(color: colors.border2),
                    FitTrackMiniRing(
                      progress: stepsPct,
                      color: AppColors.water,
                      icon: Icons.directions_walk,
                      value: '$steps',
                      label: 'Steps',
                      sublabel: '/ ${(_stepGoal / 1000).toStringAsFixed(0)}k',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.water.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.water.withValues(alpha: 0.25),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Health step sync will be enabled after the native integration gate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.water,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                const FitTrackSectionLabel(title: 'Quick Actions'),
                Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.fitness_center,
                        label: 'Start Workout',
                        sublabel: '+50 XP',
                        accent: colors.accent,
                        onTap: () => context.go('/workout/draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.restaurant,
                        label: 'Log Nutrition',
                        sublabel: 'Track protein',
                        accent: AppColors.nutrition,
                        onTap: () => context.go('/nutrition/draft'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                FitTrackSectionLabel(
                  title: 'This Week',
                  action: '${_weekWorkoutCount(data.recentWorkouts)} workouts',
                  onAction: () => context.go('/workout'),
                ),
                _WeekGrid(workouts: data.recentWorkouts),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _VitalTile(
                    icon: Icons.bedtime_outlined,
                    title: 'Sleep',
                    value: data.latestSleepMinutes == null
                        ? 'Not logged'
                        : _sleepDuration(data.latestSleepMinutes!),
                    sublabel: data.sleepQuality == null
                        ? 'Last night'
                        : _qualityStars(data.sleepQuality!),
                    accent: AppColors.sleep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VitalTile(
                    icon: Icons.monitor_weight_outlined,
                    title: 'Weight',
                    value: data.latestWeightKg == null
                        ? 'Not logged'
                        : '${data.latestWeightKg!.toStringAsFixed(1)} kg',
                    sublabel: data.latestWeightKg == null
                        ? 'Tap to log'
                        : 'Latest entry',
                    accent: AppColors.weight,
                    onTap: () => context.go('/progress/draft'),
                  ),
                ),
              ],
            ),
          ),
          if (data.recentWorkouts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                children: [
                  FitTrackSectionLabel(
                    title: 'Recent Workouts',
                    action: 'See all',
                    onAction: () => context.go('/workout'),
                  ),
                  ...data.recentWorkouts.take(3).map(
                    (workout) => _WorkoutCard(workout: workout),
                  ),
                ],
              ),
            ),
          if (data.recentWorkouts.isEmpty && !loading)
            _EmptyWorkout(onTap: () => context.go('/workout/draft')),
        ],
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 5) return 'Up late?';
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  static int _weekWorkoutCount(List<Workout> workouts) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return workouts.where((workout) => !workout.startedAt.isBefore(monday)).length;
  }

  static String _sleepDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  static String _qualityStars(int quality) {
    final safe = quality.clamp(0, 5).toInt();
    return '${List.filled(safe, '★').join()}${List.filled(5 - safe, '☆').join()}';
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    this.onTap,
  });

  final String message;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 78, color: color);
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: FitTrackText.label.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.workouts});
  final List<Workout> workouts;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - DateTime.monday));
    final workoutDays = workouts
        .map((w) => DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day))
        .toSet();

    return Row(
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final hit = workoutDays.contains(date);
        final isToday = date == today;
        final isFuture = date.isAfter(today);
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: hit ? AppColors.recovery : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: hit
                      ? null
                      : Border.all(
                          color: isToday ? colors.accent : colors.border2,
                        ),
                ),
                alignment: Alignment.center,
                child: hit
                    ? const Text(
                        '✓',
                        style: TextStyle(
                          color: Color(0xFF04140A),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : isToday
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : !isFuture
                            ? Text('–', style: TextStyle(color: colors.muted))
                            : null,
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('EEE').format(date),
                style: TextStyle(
                  fontSize: 8,
                  color: isToday
                      ? colors.accent
                      : isFuture
                          ? colors.faint.withValues(alpha: 0.4)
                          : colors.muted,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.sublabel,
    required this.accent,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String sublabel;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 15, color: accent),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    title.toUpperCase(),
                    style: FitTrackText.micro.copyWith(color: colors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: value == 'Not logged' ? colors.faint : colors.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, color: colors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final duration = workout.finishedAt == null
        ? '—'
        : '${workout.finishedAt!.difference(workout.startedAt).inMinutes}min';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.workout.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.fitness_center,
                  size: 24,
                  color: AppColors.workout,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE · MMM d').format(workout.startedAt).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: colors.muted,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaPill(label: '${workout.sets.length} sets'),
                      _MetaPill(label: duration),
                      if (workout.totalVolumeKg > 0)
                        _MetaPill(
                          label: '${workout.totalVolumeKg.round()} kg',
                        ),
                    ],
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.subtext,
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
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.fitness_center, size: 36, color: colors.border2),
          ),
          const SizedBox(height: 14),
          Text(
            'No workouts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.faint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start your first session to begin building your history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colors.faint.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.accentText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 28,
              ),
            ),
            child: const Text(
              'Start first workout',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
