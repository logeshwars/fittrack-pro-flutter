import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fln_notification_gateway.dart';
import '../data/notification_gateway.dart';
import '../domain/reminder_schedule.dart';

const remindersPrefsKey = 'fittrack_reminders_v1';

/// Seam for the OS scheduler; override in tests.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => FlnNotificationGateway(),
);

/// Reminder choices. Preferences are the source of truth; the OS pending set
/// is a cache re-built from them by [RemindersController.syncNotifications].
final remindersProvider =
    AsyncNotifierProvider<RemindersController, ReminderSettings>(
  RemindersController.new,
);

/// Outcome of switching a reminder on.
enum ToggleResult { changed, permissionDenied }

class RemindersController extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = ReminderSettings.decode(prefs.getString(remindersPrefsKey));
    await _sync(settings);
    return settings;
  }

  Future<void> _sync(ReminderSettings settings) async {
    try {
      await ref.read(notificationGatewayProvider).replaceAll(buildSchedule(settings));
    } on Object {
      // Scheduling is best effort; the choice itself is still saved.
    }
  }

  Future<void> _save(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(remindersPrefsKey, settings.encode());
    state = AsyncData(settings);
    await _sync(settings);
  }

  /// Re-registers every enabled reminder with the OS.
  Future<void> syncNotifications() async {
    final settings = state.valueOrNull;
    if (settings != null) {
      await _sync(settings);
    }
  }

  /// Turns [id] on or off. Turning on asks for permission first.
  Future<ToggleResult> setEnabled(String id, {required bool enabled}) async {
    final current = state.valueOrNull ?? ReminderSettings.defaults();
    if (enabled) {
      final granted = await ref.read(notificationGatewayProvider).requestPermission();
      if (!granted) {
        return ToggleResult.permissionDenied;
      }
    }
    await _save(current.update(id, (p) => p.copyWith(enabled: enabled)));
    return ToggleResult.changed;
  }

  /// Moves [id] to [time] ("HH:MM").
  Future<void> setTime(String id, String time) async {
    if (parseTime(time) == null) {
      return;
    }
    final current = state.valueOrNull ?? ReminderSettings.defaults();
    await _save(current.update(id, (p) => p.copyWith(time: time)));
  }
}
