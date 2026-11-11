import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../cardio/data/cardio_repository.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../nutrition/domain/nutrition_models.dart';
import '../../progress/data/progress_repository.dart';
import '../../workouts/data/workout_repository.dart';

class DashboardData {
  const DashboardData({required this.configured, required this.signedIn, this.workouts = 0, this.proteinG = 0, this.cardioMinutes = 0, this.latestWeightKg});
  final bool configured;
  final bool signedIn;
  final int workouts;
  final double proteinG;
  final int cardioMinutes;
  final double? latestWeightKg;
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  if (!AppConfig.hasSupabase) return const DashboardData(configured: false, signedIn: false);
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const DashboardData(configured: true, signedIn: false);
  final id = user.id;
  final results = await Future.wait<Object>([
    WorkoutRepository(client).getHistory(authenticatedUserId: id),
    NutritionRepository(client).getRecentLogs(authenticatedUserId: id),
    CardioRepository(client).recent(authenticatedUserId: id),
    ProgressRepository(client).recent(authenticatedUserId: id),
  ]);
  final workouts = results[0] as List;
  final nutrition = results[1] as List<NutritionLog>;
  final cardio = results[2] as List;
  final progress = results[3] as ({List<dynamic> weights, List<dynamic> sleep});
  return DashboardData(
    configured: true,
    signedIn: true,
    workouts: workouts.length,
    proteinG: NutritionTotals.fromLogs(nutrition).proteinG,
    cardioMinutes: cardio.fold<int>(0, (sum, item) => sum + ((item.durationSeconds as int? ?? 0) ~/ 60)),
    latestWeightKg: progress.weights.isEmpty ? null : progress.weights.first.weightKg as double,
  );
});
