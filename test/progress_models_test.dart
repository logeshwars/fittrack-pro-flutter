import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/progress/domain/progress_models.dart';

void main() {
  test('progress summary calculates latest and oldest weight delta', () {
    final weights = [
      WeightLog(id: 'a', weightKg: 80, loggedAt: DateTime.utc(2026, 1, 1)),
      WeightLog(id: 'b', weightKg: 78, loggedAt: DateTime.utc(2026, 1, 3)),
    ];
    final summary = ProgressSummary.fromLogs(weights: weights, sleep: []);
    expect(summary.latestWeightKg, 78);
    expect(summary.weightChangeKg, -2);
    expect(summary.averageSleepHours, isNull);
  });
  test('sleep average uses duration minutes', () {
    final summary = ProgressSummary.fromLogs(weights: [], sleep: [
      SleepLog(
          id: 'a',
          bedtime: DateTime.utc(2026, 1, 1),
          wakeTime: DateTime.utc(2026, 1, 1, 8),
          durationMinutes: 480),
      SleepLog(
          id: 'b',
          bedtime: DateTime.utc(2026, 1, 2),
          wakeTime: DateTime.utc(2026, 1, 2, 6),
          durationMinutes: 360),
    ]);
    expect(summary.averageSleepHours, 7);
  });
}
