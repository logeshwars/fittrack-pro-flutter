import '../../../core/data/data_gateway.dart';

/// XP for a night's sleep (ported from `calculateSleepXP`).
int calculateSleepXp(int durationMinutes, int quality) {
  final hours = durationMinutes / 60;
  var xp = hours < 5
      ? 5
      : hours < 6
          ? 10
          : hours < 7
              ? 20
              : hours < 8
                  ? 35
                  : hours <= 9
                      ? 40
                      : 25;
  if (quality == 4) xp += 5;
  if (quality == 5) xp += 10;
  return xp;
}

String formatSleepDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String sleepQualityLabel(int quality) => switch (quality) {
      1 => 'Poor',
      2 => 'Fair',
      3 => 'Good',
      4 => 'Great',
      5 => 'Excellent',
      _ => '',
    };

class SleepStats {
  const SleepStats({
    required this.totalNights,
    required this.avgDurationMinutes,
    required this.avgQuality,
    required this.totalXp,
    this.lastNight,
  });
  final int totalNights;
  final int avgDurationMinutes;
  final double avgQuality;
  final int totalXp;
  final Json? lastNight;
}

/// Port of `src/services/sleepService.ts`.
class SleepService {
  SleepService(this._gateway);

  final DataGateway _gateway;

  Future<List<Json>> history({int limit = 20}) => _gateway.mergedList(
        'sleep_logs',
        'sleep_history_$limit',
        () async {
          final rows = await _gateway.client
              .from('sleep_logs')
              .select()
              .eq('google_user_id', _gateway.userId)
              .order('wake_time', ascending: false)
              .limit(limit);
          return [for (final row in rows) Json.from(row)];
        },
      );

  Future<SleepStats> stats() async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final logs = (await history(limit: 100)).where((l) {
      final wake = DateTime.tryParse('${l['wake_time']}');
      return wake != null && !wake.isBefore(since);
    }).toList();
    if (logs.isEmpty) {
      return const SleepStats(
        totalNights: 0,
        avgDurationMinutes: 0,
        avgQuality: 0,
        totalXp: 0,
      );
    }
    final totalMinutes = logs.fold<int>(
        0, (a, l) => a + ((l['duration_minutes'] as num?)?.toInt() ?? 0));
    final rated = logs.where((l) => l['quality'] != null).toList();
    final avgQuality = rated.isEmpty
        ? 0.0
        : (rated.fold<num>(0, (a, l) => a + (l['quality'] as num)) /
                    rated.length *
                    10)
                .round() /
            10;
    return SleepStats(
      totalNights: logs.length,
      avgDurationMinutes: (totalMinutes / logs.length).round(),
      avgQuality: avgQuality,
      totalXp: logs.fold<int>(
          0, (a, l) => a + ((l['xp_awarded'] as num?)?.toInt() ?? 0)),
      lastNight: logs.first,
    );
  }

  /// Logs a night and returns the XP awarded.
  Future<int> logSleep({
    String? id,
    required DateTime bedtime,
    required DateTime wakeTime,
    required int quality,
    String? notes,
  }) async {
    if (quality < 1 || quality > 5) {
      throw ArgumentError.value(quality, 'quality', 'Quality is 1-5');
    }
    final minutes =
        (wakeTime.difference(bedtime).inMilliseconds / 60000).round();
    if (minutes <= 0) {
      throw ArgumentError('Wake time must be after bedtime');
    }
    final xp = calculateSleepXp(minutes, quality);
    await _gateway.upsert('sleep_logs', {
      'id': id ?? _gateway.newId(),
      'bedtime': bedtime.toUtc().toIso8601String(),
      'wake_time': wakeTime.toUtc().toIso8601String(),
      'duration_minutes': minutes,
      'quality': quality,
      'notes': notes,
      'xp_awarded': xp,
    });
    return xp;
  }

  Future<void> deleteLog(String id) => _gateway.delete('sleep_logs', id);
}
