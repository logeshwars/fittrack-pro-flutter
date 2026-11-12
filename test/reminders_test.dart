import 'package:fittrack_pro/features/reminders/application/reminders_controller.dart';
import 'package:fittrack_pro/features/reminders/data/notification_gateway.dart';
import 'package:fittrack_pro/features/reminders/domain/reminder_catalog.dart';
import 'package:fittrack_pro/features/reminders/domain/reminder_schedule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGateway implements NotificationGateway {
  FakeGateway({this.grant = true});
  final bool grant;
  List<ScheduledReminder> scheduled = [];
  int replaceCalls = 0;

  @override
  Future<bool> requestPermission() async => grant;

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    replaceCalls++;
    scheduled = reminders;
  }
}

void main() {
  test('catalog ids and notification ids are unique', () {
    expect({for (final d in reminderCatalog) d.id}.length, reminderCatalog.length);
    expect({for (final d in reminderCatalog) d.notificationId}.length, reminderCatalog.length);
    expect(reminderCatalog.length, 25);
  });

  test('defaults schedule nothing', () {
    expect(buildSchedule(ReminderSettings.defaults()), isEmpty);
  });

  test('buildSchedule includes only enabled reminders with their time', () {
    final settings = ReminderSettings.defaults()
        .update('log_lunch', (p) => p.copyWith(enabled: true, time: '13:15'))
        .update('supp_creatine', (p) => p.copyWith(enabled: true));
    final schedule = buildSchedule(settings);
    expect(schedule.map((s) => s.notificationId), [4, 101]);
    expect(schedule.first.hour, 13);
    expect(schedule.first.minute, 15);
    expect(schedule.first.channelId, 'nutrition');
    expect(schedule.last.body, 'Time to take your Creatine.');
  });

  test('encode/decode round-trips and ignores corrupt input', () {
    final settings = ReminderSettings.defaults()
        .update('water_night', (p) => p.copyWith(enabled: true, time: '20:05'));
    final decoded = ReminderSettings.decode(settings.encode());
    expect(decoded.prefs['water_night']!.enabled, isTrue);
    expect(decoded.prefs['water_night']!.time, '20:05');
    expect(ReminderSettings.decode('not json').enabledCount, 0);
    expect(ReminderSettings.decode(null).prefs.length, reminderCatalog.length);
    final badTime = ReminderSettings.decode('{"log_lunch":{"enabled":true,"time":"99:99"}}');
    expect(badTime.prefs['log_lunch']!.time, '12:30');
  });

  test('parseTime and formatters', () {
    expect(parseTime('07:30'), (hour: 7, minute: 30));
    expect(parseTime('24:00'), isNull);
    expect(parseTime('7'), isNull);
    expect(formatTime24(7, 5), '07:05');
    expect(formatTime12('00:10'), '12:10 AM');
    expect(formatTime12('13:45'), '1:45 PM');
  });

  test('firstFireDate is today when still ahead, otherwise tomorrow', () {
    final now = DateTime(2026, 11, 12, 10, 0);
    expect(firstFireDate(now, 18, 0), (year: 2026, month: 11, day: 12));
    expect(firstFireDate(now, 8, 0), (year: 2026, month: 11, day: 13));
    expect(firstFireDate(now, 10, 0), (year: 2026, month: 11, day: 13));
    expect(firstFireDate(DateTime(2026, 12, 31, 23), 7, 0), (year: 2027, month: 1, day: 1));
  });

  group('RemindersController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('enabling asks permission, persists and syncs the OS set', () async {
      final gateway = FakeGateway();
      final container = ProviderContainer(
        overrides: [notificationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      await container.read(remindersProvider.future);

      final result = await container
          .read(remindersProvider.notifier)
          .setEnabled('workout_reminder', enabled: true);

      expect(result, ToggleResult.changed);
      expect(gateway.scheduled.map((s) => s.notificationId), [13]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(remindersPrefsKey), contains('workout_reminder'));
    });

    test('permission denied leaves the reminder off', () async {
      final gateway = FakeGateway(grant: false);
      final container = ProviderContainer(
        overrides: [notificationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      await container.read(remindersProvider.future);

      final result = await container
          .read(remindersProvider.notifier)
          .setEnabled('workout_reminder', enabled: true);

      expect(result, ToggleResult.permissionDenied);
      expect(container.read(remindersProvider).value!.enabledCount, 0);
      expect(gateway.scheduled, isEmpty);
    });

    test('changing the time re-registers with the new time', () async {
      final gateway = FakeGateway();
      final container = ProviderContainer(
        overrides: [notificationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      await container.read(remindersProvider.future);
      final notifier = container.read(remindersProvider.notifier);
      await notifier.setEnabled('sleep_bedtime', enabled: true);
      await notifier.setTime('sleep_bedtime', '23:00');
      await notifier.setTime('sleep_bedtime', 'bogus');

      expect(gateway.scheduled.single.hour, 23);
      expect(gateway.scheduled.single.minute, 0);
    });

    test('saved reminders are re-registered on launch', () async {
      SharedPreferences.setMockInitialValues({
        remindersPrefsKey:
            ReminderSettings.defaults().update('log_dinner', (p) => p.copyWith(enabled: true)).encode(),
      });
      final gateway = FakeGateway();
      final container = ProviderContainer(
        overrides: [notificationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      await container.read(remindersProvider.future);

      expect(gateway.scheduled.single.notificationId, 6);
    });
  });
}
