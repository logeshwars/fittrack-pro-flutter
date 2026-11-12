import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/progress/domain/health_drafts.dart';
import 'package:fittrack_pro/features/cardio/domain/cardio_draft.dart';

void main() {
  test('weight and sleep draft serialization', () {
    final drafts = const HealthDrafts()
        .addWeight(WeightDraft(kg: 74, loggedAt: DateTime.utc(2026, 1, 1)))
        .addSleep(SleepDraft(
            bedtime: DateTime.utc(2026, 1, 1, 22),
            wakeTime: DateTime.utc(2026, 1, 2, 6)));
    final decoded = HealthDrafts.decode(drafts.encode());
    expect(decoded.weights.single.kg, 74);
    expect(decoded.sleep.single.durationMinutes, 480);
  });
  test('invalid cardio values are rejected', () {
    expect(
        const CardioDraft(type: 'running', durationMinutes: 30, distanceKm: 5)
            .isValid,
        isTrue);
    expect(const CardioDraft(type: 'running', durationMinutes: 0).isValid,
        isFalse);
    expect(
        const CardioDraft(type: 'running', durationMinutes: 30, distanceKm: -1)
            .isValid,
        isFalse);
  });
}
