/// Recommended daily allowance entry for one micronutrient.
class RdaEntry {
  const RdaEntry(this.key, this.label, this.unit, this.rda);
  final String key;
  final String label;
  final String unit;
  final double rda;
}

const List<RdaEntry> mineralRda = [
  RdaEntry('sodium_mg', 'Sodium', 'mg', 2300),
  RdaEntry('potassium_mg', 'Potassium', 'mg', 3500),
  RdaEntry('calcium_mg', 'Calcium', 'mg', 1000),
  RdaEntry('iron_mg', 'Iron', 'mg', 18),
  RdaEntry('magnesium_mg', 'Magnesium', 'mg', 400),
  RdaEntry('zinc_mg', 'Zinc', 'mg', 11),
  RdaEntry('phosphorus_mg', 'Phosphorus', 'mg', 700),
];

const List<RdaEntry> vitaminRda = [
  RdaEntry('vitamin_a_mcg', 'Vitamin A', 'µg', 900),
  RdaEntry('vitamin_c_mg', 'Vitamin C', 'mg', 90),
  RdaEntry('vitamin_d_mcg', 'Vitamin D', 'µg', 20),
  RdaEntry('vitamin_b12_mcg', 'Vitamin B12', 'µg', 2.4),
  RdaEntry('vitamin_b6_mg', 'Vitamin B6', 'mg', 1.7),
  RdaEntry('folate_mcg', 'Folate', 'µg', 400),
];

const List<RdaEntry> allRda = [...mineralRda, ...vitaminRda];

/// Sums micronutrient maps across logs, rounding to one decimal.
Map<String, double> sumMicronutrients(
  Iterable<Map<String, double>> perLog,
) {
  final totals = <String, double>{};
  for (final entry in allRda) {
    var sum = 0.0;
    for (final m in perLog) {
      sum += m[entry.key] ?? 0;
    }
    if (sum > 0) {
      totals[entry.key] = (sum * 10).round() / 10;
    }
  }
  return totals;
}

/// Scales per-100 g micronutrients to [quantityG] grams.
Map<String, double> scaleMicronutrients(
  Map<String, double> per100g,
  double quantityG,
) {
  final factor = quantityG / 100;
  return {
    for (final e in per100g.entries)
      e.key: (e.value * factor * 10).round() / 10,
  };
}
