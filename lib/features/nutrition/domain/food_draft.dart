import 'dart:convert';

class FoodDraft {
  const FoodDraft(
      {required this.name,
      required this.quantityG,
      required this.proteinG,
      required this.calories,
      this.carbsG = 0,
      this.fatG = 0,
      this.mealType = 'snack'});
  final String name;
  final double quantityG;
  final double proteinG;
  final double calories;
  final double carbsG;
  final double fatG;
  final String mealType;

  bool get isValid =>
      name.trim().isNotEmpty &&
      [quantityG, proteinG, calories, carbsG, fatG]
          .every((value) => value.isFinite && value >= 0) &&
      quantityG > 0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity_g': quantityG,
        'protein_g': proteinG,
        'calories': calories,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'meal_type': mealType,
      };
  factory FoodDraft.fromJson(Map<String, dynamic> json) => FoodDraft(
        name: json['name'] as String,
        quantityG: (json['quantity_g'] as num).toDouble(),
        proteinG: (json['protein_g'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        carbsG: (json['carbs_g'] as num).toDouble(),
        fatG: (json['fat_g'] as num).toDouble(),
        mealType: json['meal_type'] as String,
      );
}

class FoodDraftCollection {
  const FoodDraftCollection(this.items);
  final List<FoodDraft> items;
  double get totalCalories =>
      items.fold<double>(0, (sum, item) => sum + item.calories);
  double get totalProteinG =>
      items.fold<double>(0, (sum, item) => sum + item.proteinG);
  FoodDraftCollection add(FoodDraft item) =>
      FoodDraftCollection([...items, item]);
  FoodDraftCollection remove(int index) => FoodDraftCollection([
        for (var i = 0; i < items.length; i++)
          if (i != index) items[i],
      ]);
  String encode() => jsonEncode(items.map((item) => item.toJson()).toList());
  factory FoodDraftCollection.decode(String raw) => FoodDraftCollection(
        (jsonDecode(raw) as List<dynamic>)
            .map((item) => FoodDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
