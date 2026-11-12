import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../cardio/data/cardio_repository.dart';
import '../../cardio/domain/cardio_session.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../gamification/domain/gamification_stats.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../nutrition/domain/nutrition_models.dart';
import '../../progress/data/progress_repository.dart';
import '../../progress/domain/progress_models.dart';
import '../../workouts/data/workout_repository.dart';
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

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  if (!AppConfig.hasSupabase) {
    return const DashboardData(configured: false, signedIn: false);
  }

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    return const DashboardData(configured: true, signedIn: false);
  }

  final id = user.id;
  final results = await Future.wait<Object>([
    WorkoutRepository(client).getHistory(
      authenticatedUserId: id,
      pageSize: 10,
    ),
    NutritionRepository(client).getRecentLogs(authenticatedUserId: id),
    CardioRepository(client).recent(authenticatedUserId: id),
    ProgressRepository(client).recent(authenticatedUserId: id),
  ]);

  final workouts = results[0] as List<Workout>;
  final nutrition = results[1] as List<NutritionLog>;
  final cardio = results[2] as List<CardioSession>;
  final progress =
      results[3] as ({List<WeightLog> weights, List<SleepLog> sleep});
  final nutritionTotals = NutritionTotals.fromLogs(nutrition);

  final metadata = user.userMetadata ?? const <String, dynamic>{};
  var displayName = (metadata['full_name'] ??
          metadata['name'] ??
          metadata['display_name'] ??
          user.email?.split('@').first ??
          'there')
      .toString();
  String? avatarUrl =
      (metadata['avatar_url'] ?? metadata['picture'])?.toString();
  var proteinGoal = 150;

  try {
    final profile = await client
        .from('profiles')
        .select('display_name,avatar_url,protein_goal_g')
        .eq('google_user_id', id)
        .maybeSingle();
    if (profile != null) {
      final profileName = (profile['display_name'] as String?)?.trim();
      if (profileName != null && profileName.isNotEmpty) {
        displayName = profileName;
      }
      avatarUrl = (profile['avatar_url'] as String?) ?? avatarUrl;
      proteinGoal = (profile['protein_goal_g'] as num?)?.toInt() ?? proteinGoal;
    }
  } catch (_) {
    // Profile enrichment must not make the dashboard unavailable.
  }

  GamificationStats? gamification;
  try {
    gamification = await GamificationRepository(client).readOwnStats(
      authenticatedUserId: id,
    );
  } catch (_) {
    // Keep the dashboard usable while the gamification RLS audit is ongoing.
  }

  final latestSleep = progress.sleep.isEmpty ? null : progress.sleep.first;

  return DashboardData(
    configured: true,
    signedIn: true,
    displayName: displayName,
    avatarUrl: avatarUrl,
    recentWorkouts: workouts,
    proteinG: nutritionTotals.proteinG,
    proteinGoalG: proteinGoal,
    calories: nutritionTotals.calories,
    cardioMinutes: cardio.fold<int>(
      0,
      (sum, item) => sum + ((item.durationSeconds ?? 0) ~/ 60),
    ),
    latestWeightKg:
        progress.weights.isEmpty ? null : progress.weights.first.weightKg,
    latestSleepMinutes: latestSleep?.durationMinutes,
    sleepQuality: latestSleep?.quality,
    totalXp: gamification?.totalXp ?? 0,
    level: gamification?.level ?? 1,
    currentStreak: gamification?.currentStreak ?? 0,
  );
});
