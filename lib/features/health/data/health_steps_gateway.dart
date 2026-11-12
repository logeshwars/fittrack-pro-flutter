import 'dart:io' show Platform;

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/health_steps.dart';

/// Port to the platform health store (Health Connect / HealthKit).
abstract interface class HealthStepsGateway {
  Future<StepsAvailability> availability();

  /// Shows the system permission sheet; returns the resulting availability.
  Future<StepsAvailability> requestPermission();

  /// Steps from local midnight until [now]; null when unreadable.
  Future<int?> stepsToday(DateTime now);
}

/// [HealthStepsGateway] on top of the `health` package.
class PackageHealthStepsGateway implements HealthStepsGateway {
  PackageHealthStepsGateway();

  static const _types = [HealthDataType.STEPS];
  static const _access = [HealthDataAccess.READ];
  static const _askedKey = 'fittrack_health_permission_asked';

  final Health _health = Health();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) {
      return;
    }
    await _health.configure();
    _configured = true;
  }

  @override
  Future<StepsAvailability> availability() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return StepsAvailability.unsupported;
    }
    try {
      await _configure();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable) {
          return StepsAvailability.unsupported;
        }
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          return StepsAvailability.needsInstall;
        }
        final has = await _health.hasPermissions(_types, permissions: _access);
        return has == true
            ? StepsAvailability.ready
            : StepsAvailability.needsPermission;
      }
      // HealthKit never reveals read access, so remember that we asked.
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_askedKey) == true
          ? StepsAvailability.ready
          : StepsAvailability.needsPermission;
    } on Object {
      return StepsAvailability.unsupported;
    }
  }

  @override
  Future<StepsAvailability> requestPermission() async {
    try {
      await _configure();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          return StepsAvailability.needsInstall;
        }
      }
      await _health.requestAuthorization(_types, permissions: _access);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
    } on Object {
      // Fall through to a fresh availability check.
    }
    return availability();
  }

  @override
  Future<int?> stepsToday(DateTime now) async {
    try {
      await _configure();
      final start = DateTime(now.year, now.month, now.day);
      return await _health.getTotalStepsInInterval(start, now);
    } on Object {
      return null;
    }
  }
}
