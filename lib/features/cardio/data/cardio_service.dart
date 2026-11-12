import '../../../core/data/data_gateway.dart';

const cardioTypes = [
  'running',
  'cycling',
  'walking',
  'swimming',
  'hiit',
  'rowing',
  'elliptical',
  'other',
];

/// XP for a cardio session (ported from `calculateCardioXP`).
int calculateCardioXp({required int durationSeconds, double? distanceKm}) {
  var xp = 30;
  if (durationSeconds >= 30 * 60) xp += 20;
  if (durationSeconds >= 60 * 60) xp += 30;
  if (distanceKm != null && distanceKm >= 5) xp += 50;
  if (distanceKm != null && distanceKm >= 10) xp += 50;
  return xp;
}

class CardioStats {
  const CardioStats({
    required this.totalSessions,
    required this.totalMinutes,
    required this.totalDistanceKm,
    required this.totalXp,
  });
  final int totalSessions;
  final int totalMinutes;
  final double totalDistanceKm;
  final int totalXp;
}

/// Port of `src/services/cardioService.ts`.
class CardioService {
  CardioService(this._gateway);

  final DataGateway _gateway;

  Future<List<Json>> history({int limit = 20}) => _gateway.mergedList(
        'cardio_sessions',
        'cardio_history_$limit',
        () async {
          final rows = await _gateway.client
              .from('cardio_sessions')
              .select()
              .eq('google_user_id', _gateway.userId)
              .not('finished_at', 'is', null)
              .order('started_at', ascending: false)
              .limit(limit);
          return [for (final row in rows) Json.from(row)];
        },
        keep: (row) => row['finished_at'] != null,
      );

  Future<List<Json>> today() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await history(limit: 50);
    return rows.where((row) {
      final at = DateTime.tryParse('${row['started_at']}')?.toLocal();
      return at != null && !at.isBefore(start);
    }).toList();
  }

  Future<CardioStats> stats() async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final rows = await _gateway.cachedList('cardio_stats', () async {
      final data = await _gateway.client
          .from('cardio_sessions')
          .select('duration_seconds, distance_km, calories_burned, '
              'xp_awarded, type, started_at')
          .eq('google_user_id', _gateway.userId)
          .not('finished_at', 'is', null)
          .gte('started_at', since.toUtc().toIso8601String());
      return [for (final row in data) Json.from(row)];
    });
    num sum(String key) =>
        rows.fold<num>(0, (a, r) => a + ((r[key] as num?) ?? 0));
    return CardioStats(
      totalSessions: rows.length,
      totalMinutes: (sum('duration_seconds') / 60).round(),
      totalDistanceKm: (sum('distance_km') * 10).round() / 10,
      totalXp: sum('xp_awarded').toInt(),
    );
  }

  /// Logs a finished session and returns the XP awarded.
  Future<int> logSession({
    String? id,
    required String type,
    String? name,
    required int durationSeconds,
    double? distanceKm,
    int? caloriesBurned,
    int? avgHeartRate,
    String? notes,
    DateTime? finishedAt,
  }) async {
    if (!cardioTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported cardio type');
    }
    if (durationSeconds <= 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final end = finishedAt ?? DateTime.now();
    final xp = calculateCardioXp(
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
    );
    await _gateway.upsert('cardio_sessions', {
      'id': id ?? _gateway.newId(),
      'type': type,
      'name': name,
      'started_at': end
          .subtract(Duration(seconds: durationSeconds))
          .toUtc()
          .toIso8601String(),
      'finished_at': end.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_km': distanceKm,
      'calories_burned': caloriesBurned,
      'avg_heart_rate': avgHeartRate,
      'notes': notes,
      'xp_awarded': xp,
    });
    return xp;
  }

  Future<void> deleteSession(String id) =>
      _gateway.delete('cardio_sessions', id);
}
