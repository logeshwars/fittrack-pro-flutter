import 'package:fittrack_pro/features/health/domain/health_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stepsProgress clamps to 0..1', () {
    expect(stepsProgress(5000, 10000), .5);
    expect(stepsProgress(20000, 10000), 1);
    expect(stepsProgress(0, 10000), 0);
    expect(stepsProgress(100, 0), 0);
  });

  test('formatSteps compacts thousands', () {
    expect(formatSteps(842), '842');
    expect(formatSteps(1000), '1.0k');
    expect(formatSteps(12345), '12.3k');
  });

  test('canConnect only when the user can act', () {
    expect(
        const StepsState(availability: StepsAvailability.needsPermission)
            .canConnect,
        isTrue);
    expect(
        const StepsState(availability: StepsAvailability.needsInstall)
            .canConnect,
        isTrue);
    expect(const StepsState(availability: StepsAvailability.ready).canConnect,
        isFalse);
    expect(
        const StepsState(availability: StepsAvailability.unsupported)
            .canConnect,
        isFalse);
  });

  test('healthStoreName', () {
    expect(healthStoreName(isIos: true), 'Apple Health');
    expect(healthStoreName(isIos: false), 'Health Connect');
  });
}
