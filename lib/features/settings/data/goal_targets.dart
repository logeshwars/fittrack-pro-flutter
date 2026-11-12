import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';

/// Daily targets edited on the Goals settings screen.
class GoalTargets {
  const GoalTargets({
    this.steps = 10000,
    this.protein = 150,
    this.calories = 2000,
    this.carbs = 250,
    this.fat = 65,
    this.fiber = 25,
  });

  final double steps;
  final double protein;
  final double calories;
  final double carbs;
  final double fat;
  final double fiber;
}

double _parse(SharedPreferences prefs, String key, double fallback) {
  final raw = prefs.getString('fittrack_goal_$key');
  final value = raw == null ? null : double.tryParse(raw);
  return value == null || value <= 0 ? fallback : value;
}

/// Loads goal targets from device storage; the protein goal prefers the
/// profile value when it is reachable (matches the Goals screen).
final goalTargetsProvider =
    FutureProvider.autoDispose<GoalTargets>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const d = GoalTargets();
  var protein = _parse(prefs, 'protein', d.protein);
  final profileService = ref.watch(profileServiceProvider);
  if (profileService != null &&
      prefs.getString('fittrack_goal_protein') == null) {
    try {
      final profile = await profileService.profile();
      final fromProfile = (profile?['protein_goal_g'] as num?)?.toDouble();
      if (fromProfile != null && fromProfile > 0) {
        protein = fromProfile;
      }
    } catch (_) {
      // Offline without a cached profile: keep the default.
    }
  }
  return GoalTargets(
    steps: _parse(prefs, 'steps', d.steps),
    protein: protein,
    calories: _parse(prefs, 'calories', d.calories),
    carbs: _parse(prefs, 'carbs', d.carbs),
    fat: _parse(prefs, 'fat', d.fat),
    fiber: _parse(prefs, 'fiber', d.fiber),
  );
});
