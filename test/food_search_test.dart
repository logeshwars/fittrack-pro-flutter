import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/nutrition/data/food_search_service.dart';
import 'package:fittrack_pro/features/nutrition/domain/food_result.dart';

void main() {
  test(
      'searchLocalFoods: empty query returns defaults, filter by name/category',
      () {
    expect(searchLocalFoods('').length, 12);
    final dal = searchLocalFoods('moong');
    expect(dal, isNotEmpty);
    expect(dal.every((f) => f.name.toLowerCase().contains('moong')), isTrue);
    expect(
        searchLocalFoods('legumes').every((f) => f.source == FoodSource.local),
        isTrue);
  });

  test('parseOffProduct handles kJ fallback, sodium grams and vitamin A', () {
    final food = parseOffProduct({
      'product_name': ' Oats ',
      'brands': 'Acme',
      'nutriments': {
        'proteins_100g': 13.5,
        'energy-kj_100g': 1500,
        'carbohydrates_100g': '60',
        'sodium_100g': 0.01,
        'vitamin-a_100g': 0.0005,
      },
    }, '123')!;
    expect(food.name, 'Oats');
    expect(food.barcode, '123');
    expect(food.proteinPer100g, 13.5);
    expect(food.caloriesPer100g, (1500 / 4.184).roundToDouble());
    expect(food.carbsPer100g, 60);
    expect(food.micronutrients['sodium_mg'], 10.0);
    expect(food.micronutrients['vitamin_a_mcg'], 0.5);
  });

  test('parseOffProduct rejects nameless products', () {
    expect(parseOffProduct({'nutriments': {}}, '1'), isNull);
  });

  test('parseUsdaFood requires protein', () {
    expect(
        parseUsdaFood({'description': 'Thing', 'foodNutrients': []}), isNull);
    final food = parseUsdaFood({
      'description': 'Chicken',
      'foodNutrients': [
        {'nutrientName': 'Protein', 'value': 27},
        {'nutrientName': 'Energy', 'value': 165},
        {'nutrientName': 'Iron, Fe', 'value': 1.04},
      ],
    })!;
    expect(food.proteinPer100g, 27);
    expect(food.caloriesPer100g, 165);
    expect(food.micronutrients['iron_mg'], 1.0);
  });

  test('scaleFood scales per-100g values', () {
    const food = FoodResult(
      name: 'x',
      proteinPer100g: 10,
      caloriesPer100g: 200,
      carbsPer100g: 20,
      fatPer100g: 5,
      micronutrients: {'iron_mg': 2},
      source: FoodSource.local,
    );
    final s = scaleFood(food, 150);
    expect(s.protein, 15);
    expect(s.calories, 300);
    expect(s.carbs, 30);
    expect(s.fat, 7.5);
    expect(s.micronutrients['iron_mg'], 3);
  });
}
