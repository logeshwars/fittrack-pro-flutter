import 'dart:convert';

import 'reminder_catalog.dart';

/// User choice for one reminder.
class ReminderPref {
  const ReminderPref({required this.enabled, required this.time});

  final bool enabled;

  /// "HH:MM", 24 hour.
  final String time;

  ReminderPref copyWith({bool? enabled, String? time}) =>
      ReminderPref(enabled: enabled ?? this.enabled, time: time ?? this.time);
}

/// All reminder choices, merged onto the catalog so new reminders always appear.
class ReminderSettings {
  const ReminderSettings(this.prefs);

  /// Everything off at its default time.
  factory ReminderSettings.defaults() => ReminderSettings({
        for (final d in reminderCatalog)
          d.id: ReminderPref(enabled: false, time: d.defaultTime),
      });

  factory ReminderSettings.decode(String? raw) {
    final base = ReminderSettings.defaults().prefs;
    if (raw == null) {
      return ReminderSettings(base);
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return ReminderSettings(base);
      }
      return ReminderSettings({
        for (final d in reminderCatalog)
          d.id: () {
            final saved = json[d.id];
            if (saved is! Map) {
              return base[d.id]!;
            }
            final time = saved['time'];
            return ReminderPref(
              enabled: saved['enabled'] == true,
              time: time is String && parseTime(time) != null ? time : d.defaultTime,
            );
          }(),
      });
    } on FormatException {
      return ReminderSettings(base);
    }
  }

  final Map<String, ReminderPref> prefs;

  String encode() => jsonEncode({
        for (final e in prefs.entries)
          e.key: {'enabled': e.value.enabled, 'time': e.value.time},
      });

  ReminderPref of(ReminderDef def) =>
      prefs[def.id] ?? ReminderPref(enabled: false, time: def.defaultTime);

  ReminderSettings update(String id, ReminderPref Function(ReminderPref) change) {
    final current = prefs[id];
    if (current == null) {
      return this;
    }
    return ReminderSettings({...prefs, id: change(current)});
  }

  int get enabledCount => prefs.values.where((p) => p.enabled).length;
}

/// One daily notification to register with the OS.
class ScheduledReminder {
  const ScheduledReminder({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    required this.channelId,
  });

  final int notificationId;
  final String title;
  final String body;
  final int hour;
  final int minute;
  final String channelId;
}

/// Parses "HH:MM"; null when malformed or out of range.
({int hour, int minute})? parseTime(String time) {
  final parts = time.split(':');
  if (parts.length != 2) {
    return null;
  }
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return (hour: h, minute: m);
}

/// "HH:MM" from components.
String formatTime24(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// "7:30 AM" label for a stored "HH:MM".
String formatTime12(String time) {
  final t = parseTime(time);
  if (t == null) {
    return time;
  }
  final period = t.hour >= 12 ? 'PM' : 'AM';
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12:${t.minute.toString().padLeft(2, '0')} $period';
}

/// The notifications that should exist given [settings], ordered by id.
List<ScheduledReminder> buildSchedule(ReminderSettings settings) {
  final out = <ScheduledReminder>[];
  for (final def in reminderCatalog) {
    final pref = settings.of(def);
    final time = parseTime(pref.time);
    if (!pref.enabled || time == null) {
      continue;
    }
    out.add(ScheduledReminder(
      notificationId: def.notificationId,
      title: def.label,
      body: def.body,
      hour: time.hour,
      minute: time.minute,
      channelId: def.category.channelId,
    ));
  }
  out.sort((a, b) => a.notificationId.compareTo(b.notificationId));
  return out;
}

/// Next local calendar date a daily [hour]:[minute] reminder first fires.
/// Today if still in the future, otherwise tomorrow.
({int year, int month, int day}) firstFireDate(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  final target = today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1);
  return (year: target.year, month: target.month, day: target.day);
}
