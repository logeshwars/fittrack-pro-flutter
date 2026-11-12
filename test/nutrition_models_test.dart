import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/nutrition/domain/nutrition_models.dart';

void main() {
  test('macro totals handle nullable legacy fields', () {
    final logs = [
      NutritionLog.fromJson({
        'id': 'a',
        'food_name': 'Rice',
        'quantity_g': 100,
        'protein_g': 3,
        'calories': 130,
        'logged_at': '2026-01-01T00:00:00Z'
      }),
      NutritionLog.fromJson({
        'id': 'b',
        'food_name': 'Egg',
        'quantity_g': 50,
        'protein_g': 6,
        'calories': 70,
        'fat_g': 5,
        'logged_at': '2026-01-01T00:00:00Z'
      }),
    ];
    final totals = NutritionTotals.fromLogs(logs);
    expect(totals.proteinG, 9);
    expect(totals.calories, 200);
    expect(totals.fatG, 5);
    expect(totals.carbsG, 0);
  });
}
