import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/cardio/domain/cardio_tracking.dart';

void main() {
  test('haversine ~111 km per degree of latitude', () {
    expect(haversineKm(0, 0, 1, 0), closeTo(111.19, .1));
    expect(haversineKm(10, 10, 10, 10), 0);
  });

  test('GpsAccumulator filters accuracy, jitter and teleports', () {
    final g = GpsAccumulator();
    expect(g.add(const GpsPoint(0, 0, 5, 0)), isFalse); // first fix seeds
    expect(g.add(const GpsPoint(0.0001, 0, 5, 5000)), isTrue); // ~11 m in 5 s
    expect(g.add(const GpsPoint(0.0001, 0.00001, 5, 6000)), isFalse); // jitter
    expect(g.add(const GpsPoint(0.0002, 0, 80, 10000)), isFalse); // inaccurate
    expect(g.add(const GpsPoint(1, 0, 5, 11000)), isFalse); // teleport
    expect(g.kilometres, closeTo(.0111, .001));
    g.breakSegment();
    expect(g.add(const GpsPoint(0.0003, 0, 5, 20000)), isFalse);
    expect(g.add(const GpsPoint(0.0004, 0, 5, 25000)), isTrue);
    expect(g.kilometres, closeTo(.0222, .002));
  });

  test('elapsedSeconds excludes paused time', () {
    const s = CardioSessionState(type: 'running', name: 'Run', startMs: 0);
    expect(s.elapsedSeconds(60000), 60);
    final paused = s.copyWith(isPaused: true, pausedAtMs: 30000);
    expect(paused.elapsedSeconds(90000), 30);
    final resumed = s.copyWith(totalPausedMs: 20000);
    expect(resumed.elapsedSeconds(60000), 40);
  });

  test('state round-trips through JSON; bad JSON is null', () {
    final s = const CardioSessionState(type: 'cycling', name: 'Ride', startMs: 5)
        .copyWith(distanceKm: 3.2, gpsEnabled: true, calories: '120', caloriesManual: true);
    final back = CardioSessionState.decode(s.encode())!;
    expect(back.type, 'cycling');
    expect(back.distanceKm, 3.2);
    expect(back.gpsEnabled, isTrue);
    expect(back.caloriesManual, isTrue);
    expect(CardioSessionState.decode('nope'), isNull);
    expect(CardioSessionState.decode(null), isNull);
  });

  test('estimateCalories scales with time and MET', () {
    final run = estimateCalories(type: 'running', seconds: 3600);
    final walk = estimateCalories(type: 'walking', seconds: 3600);
    expect(run, greaterThan(walk));
    expect(estimateCalories(type: 'running', seconds: 1800), closeTo(run / 2, 1));
  });

  test('formatClock and formatPace', () {
    expect(formatClock(75), '01:15');
    expect(formatClock(3725), '1:02:05');
    expect(formatPace(300, 1), '5:00');
    expect(formatPace(0, 1), isNull);
    expect(formatPace(300, 0.01), isNull);
  });
}
