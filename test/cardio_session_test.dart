import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/cardio/domain/cardio_session.dart';

void main() {
  test('cardio session parses nullable legacy metrics', () {
    final session = CardioSession.fromJson({
      'id': 'c',
      'type': 'running',
      'started_at': '2026-01-01T00:00:00Z',
      'distance_km': 5.25
    });
    expect(session.distanceKm, 5.25);
    expect(session.durationSeconds, isNull);
  });
}
