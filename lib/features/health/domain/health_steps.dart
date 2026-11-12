/// Whether today's step count can be read from the platform health store.
enum StepsAvailability {
  /// Not checked yet.
  unknown,

  /// No supported health store on this device (or desktop/web).
  unsupported,

  /// Health Connect must be installed or updated first (Android).
  needsInstall,

  /// The user has not granted step access yet.
  needsPermission,

  /// Steps can be read.
  ready,
}

/// Today's steps plus how trustworthy the number is.
class StepsState {
  const StepsState(
      {this.steps = 0, this.availability = StepsAvailability.unknown});

  final int steps;
  final StepsAvailability availability;

  StepsState copyWith({int? steps, StepsAvailability? availability}) =>
      StepsState(
        steps: steps ?? this.steps,
        availability: availability ?? this.availability,
      );

  /// Whether the dashboard should offer to connect the health store.
  bool get canConnect =>
      availability == StepsAvailability.needsPermission ||
      availability == StepsAvailability.needsInstall;
}

/// 0..1 progress towards a step goal.
double stepsProgress(int steps, double goal) {
  if (goal <= 0 || steps <= 0) {
    return 0;
  }
  final p = steps / goal;
  return p > 1 ? 1 : p;
}

/// Compact label: 842 -> "842", 12345 -> "12.3k".
String formatSteps(int steps) =>
    steps >= 1000 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps';

/// Name of the platform store for user-facing copy.
String healthStoreName({required bool isIos}) =>
    isIos ? 'Apple Health' : 'Health Connect';
