import 'food_result.dart';

double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);

/// One food recognised in a meal photo (estimated for the whole portion).
class FoodScanItem {
  const FoodScanItem({
    required this.foodName,
    required this.estimatedGrams,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.calories,
    required this.confidence,
    this.quantityValue,
    this.quantityUnit = 'g',
    this.isIndianFood = false,
    this.notes = '',
    this.micronutrients = const {},
  });

  final String foodName;
  final double estimatedGrams;
  final double? quantityValue;
  final String quantityUnit;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double calories;
  final double confidence;
  final bool isIndianFood;
  final String notes;
  final Map<String, double> micronutrients;

  factory FoodScanItem.fromJson(Map<String, dynamic> j) {
    final micro = <String, double>{};
    final raw = j['micronutrients'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is num && (e.value as num) > 0) {
          micro[e.key.toString()] = (e.value as num).toDouble();
        }
      }
    }
    return FoodScanItem(
      foodName: (j['food_name'] as String?)?.trim().isNotEmpty == true
          ? (j['food_name'] as String).trim()
          : 'Unknown food',
      estimatedGrams: _d(j['estimated_grams'], 200),
      quantityValue:
          j['quantity_value'] == null ? null : _d(j['quantity_value']),
      quantityUnit: (j['quantity_unit'] as String?) ?? 'g',
      proteinG: _d(j['protein_g']),
      carbsG: _d(j['carbs_g']),
      fatG: _d(j['fat_g']),
      fiberG: _d(j['fiber_g']),
      calories: _d(j['calories']),
      confidence: _d(j['confidence'], .5),
      isIndianFood: j['is_indian_food'] == true,
      notes: (j['notes'] as String?) ?? '',
      micronutrients: micro,
    );
  }

  /// Per-100 g view so the quantity sheet can rescale the estimate.
  FoodResult toFoodResult() {
    final f = estimatedGrams > 0 ? 100 / estimatedGrams : 0.0;
    return FoodResult(
      name: foodName,
      proteinPer100g: proteinG * f,
      caloriesPer100g: calories * f,
      carbsPer100g: carbsG * f,
      fatPer100g: fatG * f,
      micronutrients: {
        for (final e in micronutrients.entries) e.key: e.value * f
      },
      source: FoodSource.local,
    );
  }
}

class PhotoScanResult {
  const PhotoScanResult({
    required this.items,
    required this.scansUsed,
    required this.scansLimit,
  });

  final List<FoodScanItem> items;
  final int scansUsed;
  final int scansLimit;

  factory PhotoScanResult.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final items = rawItems is List
        ? [
            for (final i in rawItems)
              if (i is Map) FoodScanItem.fromJson(i.cast<String, dynamic>()),
          ]
        // Legacy single-item response.
        : [FoodScanItem.fromJson(j)];
    return PhotoScanResult(
      items: items,
      scansUsed: (j['scansUsed'] as num?)?.toInt() ?? 1,
      scansLimit: (j['scansLimit'] as num?)?.toInt() ?? 10,
    );
  }
}
