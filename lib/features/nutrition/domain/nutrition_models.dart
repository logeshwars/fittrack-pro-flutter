class NutritionLog {
  const NutritionLog({required this.id, required this.foodName, required this.quantityG, required this.proteinG, required this.loggedAt, this.mealType, this.calories, this.carbsG, this.fatG, this.fiberG});
  final String id;
  final String foodName;
  final String? mealType;
  final double quantityG;
  final double proteinG;
  final double? calories;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final DateTime loggedAt;

  factory NutritionLog.fromJson(Map<String, dynamic> json) => NutritionLog(
    id: json['id'] as String,
    foodName: json['food_name'] as String,
    mealType: json['meal_type'] as String?,
    quantityG: (json['quantity_g'] as num).toDouble(),
    proteinG: (json['protein_g'] as num).toDouble(),
    calories: (json['calories'] as num?)?.toDouble(),
    carbsG: (json['carbs_g'] as num?)?.toDouble(),
    fatG: (json['fat_g'] as num?)?.toDouble(),
    fiberG: (json['fiber_g'] as num?)?.toDouble(),
    loggedAt: DateTime.parse(json['logged_at'] as String),
  );
}

class NutritionTotals {
  const NutritionTotals({required this.proteinG, required this.carbsG, required this.fatG, required this.calories});
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double calories;
  factory NutritionTotals.fromLogs(Iterable<NutritionLog> logs) {
    double protein = 0, carbs = 0, fat = 0, calories = 0;
    for (final log in logs) {
      protein += log.proteinG;
      carbs += log.carbsG ?? 0;
      fat += log.fatG ?? 0;
      calories += log.calories ?? 0;
    }
    return NutritionTotals(proteinG: protein, carbsG: carbs, fatG: fat, calories: calories);
  }
}
