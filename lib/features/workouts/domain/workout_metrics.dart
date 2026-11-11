import 'workout_models.dart';

/// Match the existing React Native behavior: a PR compares current
/// set volume to the volume of the prior highest-weight set.
/// This is intentionally NOT the conventional max-volume calculation.
bool isPersonalRecord({
  required double weightKg,
  required int reps,
  required List<WorkoutSet> previousSets,
}) {
  if (weightKg <= 0 || reps <= 0) return false;
  if (previousSets.isEmpty) return true;
  final sorted = [...previousSets]
    ..sort((a, b) => (b.weightKg ?? 0).compareTo(a.weightKg ?? 0));
  final bestByWeight = sorted.first;
  if ((bestByWeight.weightKg ?? 0) <= 0 || (bestByWeight.reps ?? 0) <= 0) {
    return true;
  }
  return weightKg * reps > bestByWeight.volumeKg;
}

int calculateProteinGoal({
  required double bodyweightKg,
  required String goal,
  double? heightCm,
}) {
  final multiplier = switch (goal) {
    'bulk' => heightCm != null && heightCm > 0 ? 2.5 : 2.2,
    'cut' => heightCm != null && heightCm > 0 ? 2.3 : 2.0,
    'maintain' => heightCm != null && heightCm > 0 ? 2.0 : 1.8,
    _ => throw ArgumentError.value(goal, 'goal', 'Unsupported goal'),
  };
  final leanMass = heightCm != null && heightCm > 0
      ? (0.33 * bodyweightKg + 0.35 * heightCm - 33.75)
          .clamp(bodyweightKg * 0.5, double.infinity)
      : bodyweightKg;
  // JavaScript Math.round rounds half-up for positive numbers.
  return ((leanMass * multiplier / 5) + 0.5).floor() * 5;
}
