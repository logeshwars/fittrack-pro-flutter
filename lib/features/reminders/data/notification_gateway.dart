import '../domain/reminder_schedule.dart';

/// Port to the OS notification scheduler.
abstract interface class NotificationGateway {
  /// Asks for notification permission; true when granted.
  Future<bool> requestPermission();

  /// Makes the OS pending set exactly [reminders]: cancels every reminder
  /// this app owns, then registers each one as a daily repeating alarm.
  Future<void> replaceAll(List<ScheduledReminder> reminders);
}
