import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/nutrition/domain/nutrition_models.dart';
import 'package:fittrack_pro/features/nutrition/domain/rda.dart';
import 'package:fittrack_pro/features/nutrition/presentation/nutrition_screen.dart';

NutritionLog _log(String id, String? meal, double protein) => NutritionLog(
      id: id,
      foodName: id,
      mealType: meal,
      quantityG: 100,
      proteinG: protein,
      loggedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('groupByMeal orders meals and collects unknown as other', () {
    final groups = groupByMeal([
      _log('a', 'dinner', 1),
      _log('b', 'breakfast', 1),
      _log('c', null, 1),
      _log('d', 'breakfast', 1),
    ]);
    expect(groups.keys.toList(), ['breakfast', 'dinner', 'other']);
    expect(groups['breakfast']!.length, 2);
  });

  test('sumMicronutrients totals and scale', () {
    final sum = sumMicronutrients([
      {'iron_mg': 1.25, 'zinc_mg': 2},
      {'iron_mg': 1.0},
    ]);
    expect(sum['iron_mg'], 2.3);
    expect(sum['zinc_mg'], 2.0);
    expect(sum.containsKey('sodium_mg'), isFalse);
    expect(scaleMicronutrients({'iron_mg': 2.0}, 150)['iron_mg'], 3.0);
  });

  test('NutritionLog parses micronutrients', () {
    final log = NutritionLog.fromJson({
      'id': 'x',
      'food_name': 'Egg',
      'quantity_g': 50,
      'protein_g': 6,
      'logged_at': '2026-01-01T00:00:00Z',
      'micronutrients': {'iron_mg': 1.2, 'note': 'x'},
    });
    expect(log.micronutrients, {'iron_mg': 1.2});
  });
}
