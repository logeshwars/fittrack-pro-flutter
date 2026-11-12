/// Where a [FoodResult] came from.
enum FoodSource { local, openFoodFacts, usda, favorite }

/// A searchable food with macros per 100 g.
class FoodResult {
  const FoodResult({
    required this.name,
    required this.proteinPer100g,
    required this.source,
    this.brand,
    this.barcode,
    this.caloriesPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.micronutrients = const {},
  });

  final String name;
  final String? brand;
  final String? barcode;
  final double proteinPer100g;
  final double? caloriesPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  /// Micronutrients per 100 g keyed like `iron_mg`.
  final Map<String, double> micronutrients;
  final FoodSource source;

  String get displayName => brand == null || brand!.isEmpty ? name : '$name · $brand';
}

/// Macros for a specific serving size.
class ScaledFood {
  const ScaledFood({
    required this.quantityG,
    required this.protein,
    required this.calories,
    required this.carbs,
    required this.fat,
    required this.micronutrients,
  });

  final double quantityG;
  final double protein;
  final double? calories;
  final double? carbs;
  final double? fat;
  final Map<String, double> micronutrients;
}

double _round1(double v) => (v * 10).round() / 10;

/// Scales per-100 g values to [quantityG] grams.
ScaledFood scaleFood(FoodResult food, double quantityG) {
  final f = quantityG / 100;
  double? s(double? v) => v == null ? null : _round1(v * f);
  return ScaledFood(
    quantityG: quantityG,
    protein: _round1(food.proteinPer100g * f),
    calories: food.caloriesPer100g == null
        ? null
        : (food.caloriesPer100g! * f).roundToDouble(),
    carbs: s(food.carbsPer100g),
    fat: s(food.fatPer100g),
    micronutrients: {
      for (final e in food.micronutrients.entries) e.key: _round1(e.value * f),
    },
  );
}
