/// A food from the bundled Indian food list (values per 100 g).
class IndianFood {
  const IndianFood(
    this.name,
    this.proteinPer100g,
    this.caloriesPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.category,
  );

  final String name;
  final double proteinPer100g;
  final double caloriesPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String category;
}
