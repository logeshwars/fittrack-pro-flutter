import '../../../core/data/data_gateway.dart';

/// Meal types accepted by the `nutrition_logs.meal_type` check constraint.
const mealTypes = [
  'breakfast',
  'lunch',
  'dinner',
  'snack',
  'post_workout',
  'other',
];

DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Port of `src/services/nutritionService.ts` and `favoriteService.ts`.
class NutritionService {
  NutritionService(this._gateway);

  final DataGateway _gateway;

  Future<List<Json>> logsForDate(DateTime date) {
    final start = _dayStart(date);
    final end = start.add(const Duration(days: 1));
    return _gateway.mergedList(
      'nutrition_logs',
      'nutrition_day_${start.toIso8601String()}',
      () async {
        final rows = await _gateway.client
            .from('nutrition_logs')
            .select()
            .eq('google_user_id', _gateway.userId)
            .gte('logged_at', start.toUtc().toIso8601String())
            .lt('logged_at', end.toUtc().toIso8601String())
            .order('logged_at', ascending: false);
        return [for (final row in rows) Json.from(row)];
      },
      keep: (row) {
        final at = DateTime.tryParse('${row['logged_at']}')?.toLocal();
        return at != null && !at.isBefore(start) && at.isBefore(end);
      },
    );
  }

  Future<List<Json>> todayLogs() => logsForDate(DateTime.now());

  /// Daily protein for the last 7 days (oldest first) for the trend chart.
  Future<List<Json>> weeklyProtein() {
    final start = _dayStart(DateTime.now().subtract(const Duration(days: 6)));
    return _gateway.cachedList('nutrition_weekly_protein', () async {
      final rows = await _gateway.client
          .from('nutrition_logs')
          .select('protein_g, logged_at')
          .eq('google_user_id', _gateway.userId)
          .gte('logged_at', start.toUtc().toIso8601String())
          .order('logged_at', ascending: true);
      return [for (final row in rows) Json.from(row)];
    });
  }

  Future<List<Json>> heatmapData({int days = 90}) {
    final start = _dayStart(DateTime.now().subtract(Duration(days: days - 1)));
    return _gateway.cachedList('nutrition_heatmap_$days', () async {
      final rows = await _gateway.client
          .from('nutrition_logs')
          .select('protein_g, calories, logged_at')
          .eq('google_user_id', _gateway.userId)
          .gte('logged_at', start.toUtc().toIso8601String())
          .order('logged_at', ascending: true);
      return [for (final row in rows) Json.from(row)];
    });
  }

  Future<String> logFood({
    String? id,
    required String foodName,
    required String mealType,
    required double quantityG,
    required double proteinG,
    double? fatG,
    double? carbsG,
    double? fiberG,
    double? calories,
    String? foodId,
    DateTime? loggedAt,
    Map<String, dynamic>? micronutrients,
  }) async {
    if (!mealTypes.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType', 'Unsupported meal type');
    }
    final logId = id ?? _gateway.newId();
    await _gateway.upsert('nutrition_logs', {
      'id': logId,
      'food_name': foodName,
      'meal_type': mealType,
      'quantity_g': quantityG,
      'protein_g': proteinG,
      'fat_g': fatG,
      'carbs_g': carbsG,
      'fiber_g': fiberG,
      'calories': calories,
      'food_id': foodId,
      'micronutrients': micronutrients,
      if (loggedAt != null) 'logged_at': loggedAt.toUtc().toIso8601String(),
    });
    return logId;
  }

  Future<void> updateLog(String id, Json fields) =>
      _gateway.update('nutrition_logs', id, fields);

  Future<void> deleteLog(String id) => _gateway.delete('nutrition_logs', id);

  // ── Favorites ────────────────────────────────────────────────────────────

  Future<List<Json>> favorites() => _gateway.mergedList(
        'favorite_foods',
        'favorite_foods',
        () async {
          final rows = await _gateway.client
              .from('favorite_foods')
              .select()
              .eq('google_user_id', _gateway.userId)
              .order('created_at', ascending: false);
          return [for (final row in rows) Json.from(row)];
        },
      );

  Future<void> addFavorite({
    required String name,
    String? brand,
    required double proteinPer100g,
    double? caloriesPer100g,
    double? carbsPer100g,
    double? fatPer100g,
  }) {
    return _gateway.upsert(
      'favorite_foods',
      {
        'id': _gateway.newId(),
        'food_name': name,
        'brand': brand,
        'protein_per_100g': proteinPer100g,
        'calories_per_100g': caloriesPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
      },
      onConflict: 'google_user_id,food_name',
    );
  }

  Future<void> removeFavorite(String id) =>
      _gateway.delete('favorite_foods', id);
}
