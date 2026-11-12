import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/progress/domain/progress_aggregates.dart';

void main() {
  test('weekDays starts on Monday', () {
    final days = weekDays(DateTime(2026, 11, 12)); // Thursday
    expect(days.first, DateTime(2026, 11, 9));
    expect(days.last, DateTime(2026, 11, 15));
    expect(days.length, 7);
  });

  test('sumByDay and maxByDay group by local date', () {
    final a = DateTime(2026, 11, 9, 8);
    final b = DateTime(2026, 11, 9, 20);
    final c = DateTime(2026, 11, 10, 7);
    final sum = sumByDay([(a, 10), (b, 5), (c, 3)]);
    expect(sum['2026-11-09'], 15);
    expect(sum['2026-11-10'], 3);
    final mx = maxByDay([(a, 10), (b, 5), (c, 3)]);
    expect(mx['2026-11-09'], 10);
  });

  test('heatLevel thresholds', () {
    expect(heatLevel(0, 10), 0);
    expect(heatLevel(2, 10), 1);
    expect(heatLevel(4, 10), 2);
    expect(heatLevel(7, 10), 3);
    expect(heatLevel(8, 10), 4);
    expect(heatLevel(5, 0), 0);
  });

  test('goalHits and completionRate', () {
    final days = weekDays(DateTime(2026, 11, 12));
    final hits = goalHits(days, {'2026-11-09': 150, '2026-11-10': 100}, 150);
    expect(hits.where((h) => h).length, 1);
    expect(goalHits(days, {}, 0).any((h) => h), isFalse);
    expect(completionRate([[true, false], [true, true]]), 75);
    expect(completionRate(const []), 0);
  });

  test('heatGrid covers range with Monday-aligned columns', () {
    final now = DateTime(2026, 11, 12);
    final grid = heatGrid(now, 30);
    expect(grid.every((w) => w.length == 7), isTrue);
    final cells = grid.expand((w) => w).whereType<DateTime>().toList();
    expect(cells.length, 30);
    expect(cells.last, DateTime(2026, 11, 12));
    expect(grid.first.where((d) => d != null).first!.weekday >= 1, isTrue);
  });
}
