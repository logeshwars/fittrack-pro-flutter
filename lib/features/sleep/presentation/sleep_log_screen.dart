import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/sleep_service.dart';
import 'sleep_screen.dart' show sleepHistoryProvider;

/// Default bedtime (yesterday 23:00) and wake time (today 07:00).
({DateTime bedtime, DateTime wake}) defaultSleepWindow(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return (
    bedtime: today.subtract(const Duration(hours: 1)),
    wake: today.add(const Duration(hours: 7)),
  );
}

/// Log a night: bedtime, wake time, quality, notes.
class SleepLogScreen extends ConsumerStatefulWidget {
  const SleepLogScreen({super.key});

  @override
  ConsumerState<SleepLogScreen> createState() => _SleepLogScreenState();
}

class _SleepLogScreenState extends ConsumerState<SleepLogScreen> {
  late DateTime _bedtime;
  late DateTime _wake;
  int _quality = 3;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = defaultSleepWindow(DateTime.now());
    _bedtime = w.bedtime;
    _wake = w.wake;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  int get _minutes =>
      (_wake.difference(_bedtime).inMilliseconds / 60000).round();

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) {
      return null;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final service = ref.read(sleepServiceProvider);
    if (_minutes <= 0 || _minutes > 24 * 60) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Wake time must be after bedtime')),
      );
      return;
    }
    if (service == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Sign in to log sleep.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final xp = await service.logSleep(
        bedtime: _bedtime,
        wakeTime: _wake,
        quality: _quality,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      await ref.read(gamificationServiceProvider)?.awardXp(xp);
      ref.invalidate(sleepHistoryProvider);
      messenger.showSnackBar(SnackBar(content: Text('Sleep logged · +$xp XP')));
      router.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final valid = _minutes > 0 && _minutes <= 24 * 60;
    final xp = valid ? calculateSleepXp(_minutes, _quality) : 0;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.header,
        foregroundColor: colors.text,
        title: const Text('Log sleep'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  valid ? formatSleepDuration(_minutes) : '—',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sleep,
                  ),
                ),
                Text(
                  valid ? '+$xp XP' : 'Wake time must be after bedtime',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            tileColor: colors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.bedtime_outlined, color: AppColors.sleep),
            title: const Text('Bedtime'),
            subtitle: Text(fmt.format(_bedtime)),
            onTap: () async {
              final v = await _pick(_bedtime);
              if (v != null) {
                setState(() => _bedtime = v);
              }
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: colors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading:
                const Icon(Icons.wb_sunny_outlined, color: AppColors.workout),
            title: const Text('Wake time'),
            subtitle: Text(fmt.format(_wake)),
            onTap: () async {
              final v = await _pick(_wake);
              if (v != null) {
                setState(() => _wake = v);
              }
            },
          ),
          const SizedBox(height: 20),
          Text(
            'QUALITY · ${sleepQualityLabel(_quality).toUpperCase()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: sleepQualityLabel(i),
                  onPressed: () => setState(() => _quality = i),
                  iconSize: 36,
                  icon: Icon(
                    i <= _quality ? Icons.star : Icons.star_border,
                    color: AppColors.xp,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || !valid ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.accentText,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
