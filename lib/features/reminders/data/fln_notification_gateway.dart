import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_catalog.dart';
import '../domain/reminder_schedule.dart';
import 'notification_gateway.dart';

/// [NotificationGateway] on top of flutter_local_notifications.
class FlnNotificationGateway implements NotificationGateway {
  FlnNotificationGateway();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } on Object {
      // Fall back to UTC; reminders still fire, only offset by the zone.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final category in ReminderCategory.values) {
      await android?.createNotificationChannel(AndroidNotificationChannel(
        category.channelId,
        category.label,
        importance: Importance.high,
      ));
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    await _ensureInitialized();
    for (final def in reminderCatalog) {
      await _plugin.cancel(def.notificationId);
    }
    final now = DateTime.now();
    for (final r in reminders) {
      final day = firstFireDate(now, r.hour, r.minute);
      await _plugin.zonedSchedule(
        r.notificationId,
        r.title,
        r.body,
        tz.TZDateTime(tz.local, day.year, day.month, day.day, r.hour, r.minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            r.channelId,
            r.channelId,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}
