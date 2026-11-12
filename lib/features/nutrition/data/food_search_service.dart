import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/food_result.dart';
import 'indian_foods_data.dart';

double? _num(Object? v) {
  if (v is num) {
    return v.toDouble();
  }
  if (v is String) {
    return double.tryParse(v);
  }
  return null;
}

double? _round1(double? v) => v == null ? null : (v * 10).round() / 10;

/// Searches the bundled Indian food list (offline).
List<FoodResult> searchLocalFoods(String query) {
  final q = query.toLowerCase().trim();
  final source = q.isEmpty
      ? indianFoods.take(12)
      : indianFoods
          .where(
            (f) =>
                f.name.toLowerCase().contains(q) ||
                f.category.toLowerCase().contains(q),
          )
          .take(20);
  return [
    for (final f in source)
      FoodResult(
        name: f.name,
        proteinPer100g: f.proteinPer100g,
        caloriesPer100g: f.caloriesPer100g,
        carbsPer100g: f.carbsPer100g,
        fatPer100g: f.fatPer100g,
        source: FoodSource.local,
      ),
  ];
}

// ── OpenFoodFacts parsing ────────────────────────────────────────────────

double _offProtein(Map<String, dynamic> n) =>
    _num(n['proteins_100g']) ?? _num(n['proteins']) ?? 0;

double? _offCalories(Map<String, dynamic> n) {
  final kcal = _num(n['energy-kcal_100g']) ??
      _num(n['energy-kcal']) ??
      _num(n['energy_kcal_100g']);
  if (kcal != null) {
    return kcal.roundToDouble();
  }
  final kj = _num(n['energy-kj_100g']) ??
      _num(n['energy-kj']) ??
      _num(n['energy_100g']);
  return kj == null ? null : (kj / 4.184).roundToDouble();
}

/// Extracts micronutrients (per 100 g) from OpenFoodFacts nutriments.
Map<String, double> offMicronutrients(Map<String, dynamic> n) {
  final sodium = _num(n['sodium_100g']);
  final vitaminA = _num(n['vitamin-a_100g']);
  final raw = <String, double?>{
    // Older entries store sodium in g, newer in mg: values <= 10 are grams.
    'sodium_mg': sodium == null ? null : (sodium > 10 ? sodium : sodium * 1000),
    'potassium_mg': _num(n['potassium_100g']),
    'calcium_mg': _num(n['calcium_100g']),
    'iron_mg': _num(n['iron_100g']),
    'magnesium_mg': _num(n['magnesium_100g']),
    'zinc_mg': _num(n['zinc_100g']),
    'phosphorus_mg': _num(n['phosphorus_100g']),
    // OFF stores vitamin A in mg; the RDA table uses µg.
    'vitamin_a_mcg': vitaminA == null ? null : vitaminA * 1000,
    'vitamin_c_mg': _num(n['vitamin-c_100g']),
    'vitamin_d_mcg': _num(n['vitamin-d_100g']),
    'vitamin_b12_mcg': _num(n['vitamin-b12_100g']),
    'vitamin_b6_mg': _num(n['vitamin-b6_100g']),
    'folate_mcg': _num(n['folate_100g']) ?? _num(n['folic-acid_100g']),
  };
  return {
    for (final e in raw.entries)
      if (e.value != null && e.value! > 0) e.key: _round1(e.value)!,
  };
}

/// Parses one OpenFoodFacts product; returns null when it has no name.
FoodResult? parseOffProduct(Map<String, dynamic> p, String barcode) {
  final name = ((p['product_name'] as String?) ??
          (p['product_name_en'] as String?) ??
          '')
      .trim();
  if (name.isEmpty) {
    return null;
  }
  final n = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
  final brand = (p['brands'] as String?)?.trim();
  final code = barcode.isNotEmpty ? barcode : (p['code'] as String?);
  return FoodResult(
    name: name,
    brand: brand == null || brand.isEmpty ? null : brand,
    barcode: code,
    proteinPer100g: _offProtein(n),
    caloriesPer100g: _offCalories(n),
    carbsPer100g: _num(n['carbohydrates_100g']) ?? _num(n['carbohydrates']),
    fatPer100g: _num(n['fat_100g']) ?? _num(n['fat']),
    micronutrients: offMicronutrients(n),
    source: FoodSource.openFoodFacts,
  );
}

// ── USDA parsing ─────────────────────────────────────────────────────────

double? _usdaFind(List<Map<String, dynamic>> nutrients, List<String> names) {
  for (final n in nutrients) {
    final label = (n['nutrientName'] as String?)?.toLowerCase();
    if (label != null && names.any((x) => label.contains(x.toLowerCase()))) {
      return _num(n['value']);
    }
  }
  return null;
}

/// Parses one USDA food; returns null without a name or protein value.
FoodResult? parseUsdaFood(Map<String, dynamic> f) {
  final name = ((f['description'] as String?) ?? '').trim();
  if (name.isEmpty) {
    return null;
  }
  final nutrients = [
    for (final n in (f['foodNutrients'] as List?) ?? const [])
      if (n is Map) n.cast<String, dynamic>(),
  ];
  final protein = _usdaFind(nutrients, ['protein']);
  if (protein == null) {
    return null;
  }
  final raw = <String, double?>{
    'sodium_mg': _usdaFind(nutrients, ['sodium']),
    'potassium_mg': _usdaFind(nutrients, ['potassium']),
    'calcium_mg': _usdaFind(nutrients, ['calcium']),
    'iron_mg': _usdaFind(nutrients, ['iron']),
    'magnesium_mg': _usdaFind(nutrients, ['magnesium']),
    'zinc_mg': _usdaFind(nutrients, ['zinc']),
    'phosphorus_mg': _usdaFind(nutrients, ['phosphorus']),
    'vitamin_a_mcg': _usdaFind(nutrients, ['vitamin a']),
    'vitamin_c_mg': _usdaFind(nutrients, ['vitamin c']),
    'vitamin_d_mcg': _usdaFind(nutrients, ['vitamin d']),
    'vitamin_b12_mcg': _usdaFind(nutrients, ['vitamin b12', 'b12']),
    'vitamin_b6_mg': _usdaFind(nutrients, ['vitamin b6', 'b6']),
    'folate_mcg': _usdaFind(nutrients, ['folate']),
  };
  final brand = (f['brandName'] as String?)?.trim();
  return FoodResult(
    name: name,
    brand: brand == null || brand.isEmpty ? null : brand,
    barcode: f['gtinUpc'] as String?,
    proteinPer100g: protein,
    caloriesPer100g: _usdaFind(nutrients, ['energy', 'kcal']),
    carbsPer100g: _usdaFind(nutrients, ['carbohydrate']),
    fatPer100g: _usdaFind(nutrients, ['total lipid', 'fat']),
    micronutrients: {
      for (final e in raw.entries)
        if (e.value != null && e.value! > 0) e.key: _round1(e.value)!,
    },
    source: FoodSource.usda,
  );
}

/// Remote food lookup (OpenFoodFacts, USDA FoodData Central).
class FoodSearchService {
  FoodSearchService({http.Client? client, this.usdaApiKey = ''})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String usdaApiKey;

  Future<Map<String, dynamic>?> _getJson(Uri uri, Duration timeout) async {
    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(res.body);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on Object {
      return null;
    }
  }

  Future<List<FoodResult>> searchOpenFoodFacts(String query) async {
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'fields': 'product_name,product_name_en,brands,code,nutriments',
      'page_size': '10',
    });
    final json = await _getJson(uri, const Duration(seconds: 6));
    final products = (json?['products'] as List?) ?? const [];
    return [
      for (final p in products)
        if (p is Map)
          if (parseOffProduct(p.cast<String, dynamic>(), '') case final r?) r,
    ];
  }

  Future<List<FoodResult>> searchUsda(String query) async {
    if (usdaApiKey.isEmpty) {
      return const [];
    }
    final uri = Uri.https('fdc.nal.usda.gov', '/api/v1/foods/search', {
      'query': query,
      'pageSize': '10',
      'api_key': usdaApiKey,
    });
    final json = await _getJson(uri, const Duration(seconds: 6));
    final foods = (json?['foods'] as List?) ?? const [];
    return [
      for (final f in foods)
        if (f is Map)
          if (parseUsdaFood(f.cast<String, dynamic>()) case final r?) r,
    ];
  }

  /// Local list first, then OpenFoodFacts and USDA in parallel.
  Future<List<FoodResult>> search(String query) async {
    final local = searchLocalFoods(query);
    if (query.trim().length < 2) {
      return local;
    }
    final remote = await Future.wait([
      searchOpenFoodFacts(query),
      searchUsda(query),
    ]);
    return [...local, ...remote[0], ...remote[1]];
  }

  Future<FoodResult?> _lookupOff(String barcode, String mirror) async {
    final uri = Uri.https(
      '$mirror.openfoodfacts.org',
      '/api/v2/product/$barcode',
      {'fields': 'product_name,product_name_en,brands,nutriments'},
    );
    final json = await _getJson(uri, const Duration(seconds: 8));
    final product = json?['product'];
    if (json?['status'] != 1 || product is! Map) {
      return null;
    }
    return parseOffProduct(product.cast<String, dynamic>(), barcode);
  }

  Future<FoodResult?> _lookupUsda(String barcode) async {
    if (usdaApiKey.isEmpty) {
      return null;
    }
    final uri = Uri.https('fdc.nal.usda.gov', '/api/v1/foods/search', {
      'query': barcode,
      'pageSize': '1',
      'api_key': usdaApiKey,
    });
    final json = await _getJson(uri, const Duration(seconds: 8));
    for (final f in (json?['foods'] as List?) ?? const []) {
      if (f is Map && f['gtinUpc'] == barcode) {
        return parseUsdaFood(f.cast<String, dynamic>());
      }
    }
    return null;
  }

  /// OpenFoodFacts (world, India mirror, v0) then USDA.
  Future<FoodResult?> lookupBarcode(String barcode) async {
    final world = await _lookupOff(barcode, 'world');
    if (world != null) {
      return world;
    }
    final india = await _lookupOff(barcode, 'in');
    if (india != null) {
      return india;
    }
    final v0 = await _getJson(
      Uri.https('world.openfoodfacts.org', '/api/v0/product/$barcode.json'),
      const Duration(seconds: 8),
    );
    final product = v0?['product'];
    if (v0?['status'] == 1 && product is Map) {
      final parsed = parseOffProduct(product.cast<String, dynamic>(), barcode);
      if (parsed != null) {
        return parsed;
      }
    }
    return _lookupUsda(barcode);
  }
}
