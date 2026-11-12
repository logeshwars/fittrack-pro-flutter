import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/data/service_providers.dart';
import '../../settings/data/goal_targets.dart';
import '../../workouts/domain/workout_models.dart';

class DashboardData {
  const DashboardData({
    required this.configured,
    required this.signedIn,
    this.displayName = 'there',
    this.avatarUrl,
    this.recentWorkouts = const [],
    this.proteinG = 0,
    this.proteinGoalG = 150,
    this.calorieGoal = 2000,
    this.stepGoal = 10000,
    this.calories = 0,
    this.cardioMinutes = 0,
    this.latestWeightKg,
    this.latestSleepMinutes,
    this.sleepQuality,
    this.totalXp = 0,
    this.level = 1,
    this.currentStreak = 0,
  });

  final bool configured;
  final bool signedIn;
  final String displayName;
  final String? avatarUrl;
  final List<Workout> recentWorkouts;
  final double proteinG;
  final int proteinGoalG;
  final int calorieGoal;
  final int stepGoal;
  final double calories;
  final int cardioMinutes;
  final double? latestWeightKg;
  final int? latestSleepMinutes;
  final int? sleepQuality;
  final int totalXp;
  final int level;
  final int currentStreak;

  int get workouts => recentWorkouts.length;
}

/// Runs [load] and falls back to [fallback] so one failing source never makes
/// the whole dashboard unavailable.
Future<T> _safe<T>(Future<T> Function() load, T fallback) async {
  try {
    return await load();
  } on Object {
    return fallback;
  }
}

double _sum(Iterable<Map<String, dynamic>> rows, String key) =>
    rows.fold<double>(0, (s, r) => s + ((r[key] as num?)?.toDouble() ?? 0));

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  if (!AppConfig.hasSupabase) {
    return const DashboardData(configured: false, signedIn: false);
  }
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return const DashboardData(configured: true, signedIn: false);
  }

  final workouts = ref.watch(workoutServiceProvider);
  final nutrition = ref.watch(nutritionServiceProvider);
  final cardio = ref.watch(cardioServiceProvider);
  final sleep = ref.watch(sleepServiceProvider);
  final weight = ref.watch(weightServiceProvider);
  final profileService = ref.watch(profileServiceProvider);
  final gamification = ref.watch(gamificationServiceProvider);

  final goals = await _safe(
    () => ref.watch(goalTargetsProvider.future),
    const GoalTargets(),
  );

  final recent = await Future.wait<Object?>([
    _safe<List<Workout>>(
        () async => await workouts?.history(limit: 10) ?? const [], const []),
    _safe<List<Map<String, dynamic>>>(
        () async => await nutrition?.todayLogs() ?? const [], const []),
    _safe<List<Map<String, dynamic>>>(
        () async => await cardio?.today() ?? const [], const []),
    _safe<List<Map<String, dynamic>>>(
        () async => await sleep?.history(limit: 1) ?? const [], const []),
    _safe<Map<String, dynamic>?>(() async => await weight?.latest(), null),
    _safe<Map<String, dynamic>?>(
        () async => await profileService?.profile(), null),
    _safe<Map<String, dynamic>?>(() async => await gamification?.stats(), null),
  ]);

  final recentWorkouts = recent[0]! as List<Workout>;
  final foodRows = recent[1]! as List<Map<String, dynamic>>;
  final cardioRows = recent[2]! as List<Map<String, dynamic>>;
  final sleepRows = recent[3]! as List<Map<String, dynamic>>;
  final latestWeight = recent[4] as Map<String, dynamic>?;
  final profile = recent[5] as Map<String, dynamic>?;
  final stats = recent[6] as Map<String, dynamic>?;

  final metadata = user.userMetadata ?? const <String, dynamic>{};
  var displayName = (metadata['full_name'] ??
          metadata['name'] ??
          metadata['display_name'] ??
          user.email?.split('@').first ??
          'there')
      .toString();
  var avatarUrl = (metadata['avatar_url'] ?? metadata['picture'])?.toString();
  final profileName = (profile?['display_name'] as String?)?.trim();
  if (profileName != null && profileName.isNotEmpty) {
    displayName = profileName;
  }
  avatarUrl = (profile?['avatar_url'] as String?) ?? avatarUrl;

  final latestSleep = sleepRows.isEmpty ? null : sleepRows.first;

  return DashboardData(
    configured: true,
    signedIn: true,
    displayName: displayName,
    avatarUrl: avatarUrl,
    recentWorkouts: recentWorkouts,
    proteinG: _sum(foodRows, 'protein_g'),
    proteinGoalG: goals.protein.round(),
    calorieGoal: goals.calories.round(),
    stepGoal: goals.steps.round(),
    calories: _sum(foodRows, 'calories'),
    cardioMinutes: (_sum(cardioRows, 'duration_seconds') / 60).round(),
    latestWeightKg: (latestWeight?['weight_kg'] as num?)?.toDouble(),
    latestSleepMinutes: (latestSleep?['duration_minutes'] as num?)?.toInt(),
    sleepQuality: (latestSleep?['quality'] as num?)?.toInt(),
    totalXp: (stats?['total_xp'] as num?)?.toInt() ?? 0,
    level: (stats?['level'] as num?)?.toInt() ?? 1,
    currentStreak: (stats?['current_streak'] as num?)?.toInt() ?? 0,
  );
});
