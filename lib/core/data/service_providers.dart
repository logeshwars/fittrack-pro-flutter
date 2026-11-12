import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cardio/data/cardio_service.dart';
import '../../features/gamification/data/gamification_service.dart';
import '../../features/nutrition/data/nutrition_service.dart';
import '../../features/profile/data/profile_service.dart';
import '../../features/progress/data/weight_service.dart';
import '../../features/sleep/data/sleep_service.dart';
import '../../features/workouts/data/preset_service.dart';
import '../../features/workouts/data/workout_service.dart';
import '../config/app_config.dart';
import '../../features/nutrition/data/photo_scan_service.dart';
import '../../features/nutrition/data/food_search_service.dart';
import 'data_providers.dart';

/// Each provider is null when signed out or when Supabase is not configured.
final workoutServiceProvider = Provider<WorkoutService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : WorkoutService(gateway);
});

final presetServiceProvider = Provider<PresetService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : PresetService(gateway);
});

final nutritionServiceProvider = Provider<NutritionService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : NutritionService(gateway);
});

final cardioServiceProvider = Provider<CardioService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : CardioService(gateway);
});

final sleepServiceProvider = Provider<SleepService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : SleepService(gateway);
});

final weightServiceProvider = Provider<WeightService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : WeightService(gateway);
});

final profileServiceProvider = Provider<ProfileService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : ProfileService(gateway);
});

final gamificationServiceProvider = Provider<GamificationService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null ? null : GamificationService(gateway);
});

/// Remote food search / barcode lookup (no auth needed).
final foodSearchServiceProvider = Provider<FoodSearchService>((ref) {
  return FoodSearchService(usdaApiKey: AppConfig.usdaApiKey);
});

final photoScanServiceProvider = Provider<PhotoScanService?>((ref) {
  final gateway = ref.watch(dataGatewayProvider);
  return gateway == null
      ? null
      : PhotoScanService(gateway.client, gateway.userId);
});
