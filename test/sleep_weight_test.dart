import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/progress/domain/progress_models.dart';
import 'package:fittrack_pro/features/progress/presentation/weight_screen.dart';
import 'package:fittrack_pro/features/sleep/presentation/sleep_log_screen.dart';

WeightLog _w(double kg, int daysAgo) => WeightLog(
      id: '$kg$daysAgo',
      weightKg: kg,
      loggedAt: DateTime(2026, 1, 20).subtract(Duration(days: daysAgo)),
    );

void main() {
  test('WeightTrend: newest first', () {
    final t = WeightTrend.from([_w(80, 0), _w(81, 1), _w(82, 2)]);
    expect(t.latest, 80);
    expect(t.change, -2);
    expect(t.average, 81);
    final empty = WeightTrend.from(const []);
    expect(empty.latest, isNull);
    expect(WeightTrend.from([_w(70, 0)]).change, isNull);
  });

  test('default sleep window is 23:00 -> 07:00 (8h)', () {
    final w = defaultSleepWindow(DateTime(2026, 3, 10, 14));
    expect(w.bedtime, DateTime(2026, 3, 9, 23));
    expect(w.wake, DateTime(2026, 3, 10, 7));
    expect(w.wake.difference(w.bedtime).inHours, 8);
  });
}
