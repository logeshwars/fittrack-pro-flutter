import '../../workouts/domain/workout_models.dart';

String dateKey(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday..Sunday of the week containing [now].
List<DateTime> weekDays(DateTime now) {
  final today = startOfDay(now);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
}

/// Sums [value] per local calendar day.
Map<String, double> sumByDay(Iterable<(DateTime, double)> entries) {
  final out = <String, double>{};
  for (final (at, v) in entries) {
    final k = dateKey(at);
    out[k] = (out[k] ?? 0) + v;
  }
  return out;
}

/// Maximum value per local calendar day.
Map<String, double> maxByDay(Iterable<(DateTime, double)> entries) {
  final out = <String, double>{};
  for (final (at, v) in entries) {
    final k = dateKey(at);
    final prev = out[k];
    out[k] = prev == null || v > prev ? v : prev;
  }
  return out;
}

/// Total training volume of a workout in kg.
double workoutVolume(Workout w) => w.totalVolumeKg;

/// Heat-map intensity step 0..4 for [value] against [max].
int heatLevel(double value, double max) {
  if (value <= 0 || max <= 0) {
    return 0;
  }
  final i = value / max;
  if (i < .25) {
    return 1;
  }
  if (i < .5) {
    return 2;
  }
  if (i < .8) {
    return 3;
  }
  return 4;
}

/// For each of [days], whether [byDay] reached [goal].
List<bool> goalHits(List<DateTime> days, Map<String, double> byDay, double goal) => [
      for (final d in days) goal > 0 && (byDay[dateKey(d)] ?? 0) >= goal,
    ];

/// Percentage (0-100) of true values across all [rows].
int completionRate(Iterable<List<bool>> rows) {
  var hits = 0;
  var slots = 0;
  for (final row in rows) {
    slots += row.length;
    hits += row.where((h) => h).length;
  }
  return slots == 0 ? 0 : (hits / slots * 100).round();
}

/// Weeks (columns) of the last [days] days for a calendar heat map; cells
/// outside the range are null. Columns start on Monday.
List<List<DateTime?>> heatGrid(DateTime now, int days) {
  final today = startOfDay(now);
  final first = today.subtract(Duration(days: days - 1));
  final gridStart = first.subtract(Duration(days: first.weekday - 1));
  final weeks = <List<DateTime?>>[];
  var cursor = gridStart;
  while (!cursor.isAfter(today)) {
    weeks.add([
      for (var i = 0; i < 7; i++)
        () {
          final d = DateTime(cursor.year, cursor.month, cursor.day + i);
          return d.isBefore(first) || d.isAfter(today) ? null : d;
        }(),
    ]);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 7);
  }
  return weeks;
}
