import '../../../core/data/data_gateway.dart';

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Port of `src/services/weightService.ts`. One entry per calendar day.
class WeightService {
  WeightService(this._gateway);

  final DataGateway _gateway;

  Future<List<Json>> history({int limit = 90}) => _gateway.mergedList(
        'weight_logs',
        'weight_history_$limit',
        () async {
          final rows = await _gateway.client
              .from('weight_logs')
              .select()
              .eq('google_user_id', _gateway.userId)
              .order('logged_at', ascending: false)
              .limit(limit);
          return [for (final row in rows) Json.from(row)];
        },
      );

  Future<Json?> latest() async {
    final rows = await history(limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Logs (or replaces) the weight for [date]'s calendar day.
  Future<void> logWeight(
    double weightKg, {
    String? note,
    DateTime? date,
    String? id,
  }) {
    if (!weightKg.isFinite || weightKg <= 0 || weightKg > 500) {
      throw ArgumentError.value(weightKg, 'weightKg');
    }
    return _gateway.upsert(
      'weight_logs',
      {
        'id': id ?? _gateway.newId(),
        'weight_kg': weightKg,
        'note': note,
        'logged_at': _dateOnly(date ?? DateTime.now()),
      },
      onConflict: 'google_user_id,logged_at',
    );
  }

  Future<void> deleteLog(String id) => _gateway.delete('weight_logs', id);
}
