import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/local/local_draft_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../domain/health_drafts.dart';
import '../../../core/widgets/fittrack_icons.dart';

class HealthDraftScreen extends StatefulWidget {
  const HealthDraftScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  State<HealthDraftScreen> createState() => _HealthDraftScreenState();
}

class _HealthDraftScreenState extends State<HealthDraftScreen> {
  static const _key = 'fittrack_health_drafts_v1';

  final _weight = TextEditingController();
  final _weightNote = TextEditingController();
  final _sleepNotes = TextEditingController();

  LocalDraftStore? _store;
  HealthDrafts _drafts = const HealthDrafts();
  String? _error;
  late int _tab;

  int _bedHour = 22;
  int _bedMinute = 0;
  int _wakeHour = 6;
  int _wakeMinute = 30;
  int _quality = 3;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1).toInt();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = LocalDraftStore(await SharedPreferences.getInstance());
      if (!mounted) return;
      setState(() {
        _store = store;
        final raw = store.read(_key);
        _drafts = raw == null ? const HealthDrafts() : HealthDrafts.decode(raw);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load local entries');
    }
  }

  Future<void> _saveDrafts(HealthDrafts value) async {
    final store = _store;
    if (store == null) return;
    await store.write(_key, value.encode());
    if (!mounted) return;
    setState(() {
      _drafts = value;
      _error = null;
    });
  }

  Future<void> _addWeight() async {
    final note = _weightNote.text.trim();
    final draft = WeightDraft(
      kg: double.tryParse(_weight.text) ?? double.nan,
      loggedAt: DateTime.now(),
      note: note.isEmpty ? null : note,
    );

    if (!draft.isValid) {
      setState(() => _error = 'Enter a valid weight in kg');
      return;
    }

    try {
      await _saveDrafts(_drafts.addWeight(draft));
      _weight.clear();
      _weightNote.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save weight');
    }
  }

  Future<void> _addSleep() async {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    var bedtime = DateTime(
      base.year,
      base.month,
      base.day,
      _bedHour,
      _bedMinute,
    );
    var wake = DateTime(
      base.year,
      base.month,
      base.day,
      _wakeHour,
      _wakeMinute,
    );

    if (!wake.isAfter(bedtime)) {
      wake = wake.add(const Duration(days: 1));
    }
    if (wake.isAfter(now.add(const Duration(days: 1)))) {
      bedtime = bedtime.subtract(const Duration(days: 1));
      wake = wake.subtract(const Duration(days: 1));
    }

    final notes = _sleepNotes.text.trim();
    final draft = SleepDraft(
      bedtime: bedtime,
      wakeTime: wake,
      quality: _quality,
      notes: notes.isEmpty ? null : notes,
    );

    if (!draft.isValid) {
      setState(() => _error = 'Invalid sleep duration');
      return;
    }

    try {
      await _saveDrafts(_drafts.addSleep(draft));
      _sleepNotes.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save sleep');
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _weightNote.dispose();
    _sleepNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _Header(onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: FitTrackSegmentedTabs(
                labels: const ['Weight', 'Sleep'],
                selectedIndex: _tab,
                onSelected: (value) => setState(() {
                  _tab = value;
                  _error = null;
                }),
              ),
            ),
            if (_tab == 0)
              _WeightPanel(
                controller: _weight,
                noteController: _weightNote,
                latest: _drafts.weights.isEmpty ? null : _drafts.weights.last,
                history: _drafts.weights.reversed.take(8).toList(),
                error: _error,
                enabled: _store != null,
                onSave: _addWeight,
              )
            else
              _SleepPanel(
                bedHour: _bedHour,
                bedMinute: _bedMinute,
                wakeHour: _wakeHour,
                wakeMinute: _wakeMinute,
                quality: _quality,
                notes: _sleepNotes,
                history: _drafts.sleep.reversed.take(6).toList(),
                error: _error,
                enabled: _store != null,
                onBedHour: (delta) => setState(() {
                  _bedHour = (_bedHour + delta + 24) % 24;
                }),
                onBedMinute: (delta) => setState(() {
                  final total =
                      (_bedHour * 60 + _bedMinute + delta + 1440) % 1440;
                  _bedHour = total ~/ 60;
                  _bedMinute = total % 60;
                }),
                onWakeHour: (delta) => setState(() {
                  _wakeHour = (_wakeHour + delta + 24) % 24;
                }),
                onWakeMinute: (delta) => setState(() {
                  final total =
                      (_wakeHour * 60 + _wakeMinute + delta + 1440) % 1440;
                  _wakeHour = total ~/ 60;
                  _wakeMinute = total % 60;
                }),
                onQuality: (value) => setState(() => _quality = value),
                onSave: _addSleep,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'These entries are saved only on this device. Production health writes remain disabled until identity and native health integrations are verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: colors.faint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(FitIcons.back, size: 20, color: colors.text),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Weight & sleep tracking',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.weight.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.weight.withValues(alpha: .25),
              ),
            ),
            child: const Text(
              'LOCAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.weight,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightPanel extends StatelessWidget {
  const _WeightPanel({
    required this.controller,
    required this.noteController,
    required this.latest,
    required this.history,
    required this.error,
    required this.enabled,
    required this.onSave,
  });

  final TextEditingController controller;
  final TextEditingController noteController;
  final WeightDraft? latest;
  final List<WeightDraft> history;
  final String? error;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.weight.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    FitIcons.weight,
                    size: 30,
                    color: AppColors.weight,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  latest == null
                      ? 'Log your weight'
                      : '${latest!.kg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: latest == null ? colors.text : AppColors.weight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latest == null
                      ? 'Build a consistent weight trend'
                      : 'Latest local entry · ${DateFormat('MMM d').format(latest!.loggedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.weight,
            ),
            decoration: const InputDecoration(
              labelText: 'BODY WEIGHT (KG)',
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'NOTE (OPTIONAL)',
              hintText: 'Morning, fasted, after workout…',
            ),
          ),
          _ErrorBox(error: error),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onSave : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.weight,
                foregroundColor: const Color(0xFF04121A),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'SAVE WEIGHT',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.muted,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < history.length; i++)
              _WeightRow(
                item: history[i],
                previous: i + 1 < history.length ? history[i + 1] : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.item, required this.previous});
  final WeightDraft item;
  final WeightDraft? previous;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final diff = previous == null ? null : item.kg - previous!.kg;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.weight.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  FitIcons.weight,
                  size: 24,
                  color: AppColors.weight,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE · MMM d')
                        .format(item.loggedAt)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: colors.muted,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.kg.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.weight,
                    ),
                  ),
                  if (diff != null || item.note != null) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (diff != null)
                          _Pill(
                            text:
                                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
                            color: diff <= 0
                                ? AppColors.recovery
                                : AppColors.cardio,
                          ),
                        if (item.note != null)
                          _Pill(text: item.note!, color: colors.subtext),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepPanel extends StatelessWidget {
  const _SleepPanel({
    required this.bedHour,
    required this.bedMinute,
    required this.wakeHour,
    required this.wakeMinute,
    required this.quality,
    required this.notes,
    required this.history,
    required this.error,
    required this.enabled,
    required this.onBedHour,
    required this.onBedMinute,
    required this.onWakeHour,
    required this.onWakeMinute,
    required this.onQuality,
    required this.onSave,
  });

  final int bedHour;
  final int bedMinute;
  final int wakeHour;
  final int wakeMinute;
  final int quality;
  final TextEditingController notes;
  final List<SleepDraft> history;
  final String? error;
  final bool enabled;
  final ValueChanged<int> onBedHour;
  final ValueChanged<int> onBedMinute;
  final ValueChanged<int> onWakeHour;
  final ValueChanged<int> onWakeMinute;
  final ValueChanged<int> onQuality;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final duration = _durationMinutes();
    final hours = duration / 60;
    final durationColor = hours >= 7 && hours <= 9
        ? AppColors.recovery
        : hours >= 6
            ? AppColors.sleep
            : colors.danger;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.accentTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'DURATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: durationColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hours >= 7 && hours <= 9
                      ? 'Optimal sleep window'
                      : hours >= 6
                          ? 'Below optimal sleep'
                          : 'Sleep debt',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _TimePicker(
            label: 'BEDTIME',
            icon: FitIcons.sleep,
            hour24: bedHour,
            minute: bedMinute,
            onHour: onBedHour,
            onMinute: onBedMinute,
          ),
          const SizedBox(height: 16),
          _TimePicker(
            label: 'WAKE TIME',
            icon: FitIcons.sun,
            hour24: wakeHour,
            minute: wakeMinute,
            onHour: onWakeHour,
            onMinute: onWakeMinute,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SLEEP QUALITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var q = 1; q <= 5; q++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: q == 5 ? 0 : 6,
                          ),
                          child: InkWell(
                            onTap: () => onQuality(q),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: quality == q
                                    ? AppColors.sleep.withValues(alpha: .12)
                                    : colors.cardAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: quality == q
                                      ? AppColors.sleep
                                      : colors.border2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    FitIcons.sleep,
                                    size: 19,
                                    color: quality >= q
                                        ? AppColors.sleep
                                        : colors.faint,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$q',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: quality == q
                                          ? AppColors.sleep
                                          : colors.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'NOTES (OPTIONAL)',
              hintText: 'How did you sleep?',
            ),
          ),
          _ErrorBox(error: error),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onSave : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.accentText,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'SAVE SLEEP LOG',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RECENT SLEEP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.muted,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final item in history) _SleepRow(item: item),
          ],
        ],
      ),
    );
  }

  int _durationMinutes() {
    var bed = bedHour * 60 + bedMinute;
    var wake = wakeHour * 60 + wakeMinute;
    if (wake <= bed) wake += 24 * 60;
    return wake - bed;
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.label,
    required this.icon,
    required this.hour24,
    required this.minute,
    required this.onHour,
    required this.onMinute,
  });

  final String label;
  final IconData icon;
  final int hour24;
  final int minute;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final hour12 = hour24 == 0
        ? 12
        : hour24 > 12
            ? hour24 - 12
            : hour24;
    final ampm = hour24 >= 12 ? 'PM' : 'AM';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.sleep),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Adjust(
                value: hour12.toString().padLeft(2, '0'),
                onPlus: () => onHour(1),
                onMinus: () => onHour(-1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: colors.muted,
                  ),
                ),
              ),
              _Adjust(
                value: minute.toString().padLeft(2, '0'),
                onPlus: () => onMinute(5),
                onMinus: () => onMinute(-5),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sleep.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sleep),
                ),
                child: Text(
                  ampm,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sleep,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Adjust extends StatelessWidget {
  const _Adjust({
    required this.value,
    required this.onPlus,
    required this.onMinus,
  });

  final String value;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Column(
      children: [
        _AdjustButton(text: '+', onTap: onPlus),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: colors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        _AdjustButton(text: '−', onTap: onMinus),
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 36,
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
      ),
    );
  }
}

class _SleepRow extends StatelessWidget {
  const _SleepRow({required this.item});
  final SleepDraft item;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(FitIcons.sleep, size: 20, color: AppColors.sleep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _SleepPanel._formatDuration(item.durationMinutes),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('MMM d').format(item.wakeTime)} · ${DateFormat('h:mm a').format(item.bedtime)} – ${DateFormat('h:mm a').format(item.wakeTime)}',
                  style: TextStyle(fontSize: 10, color: colors.muted),
                ),
              ],
            ),
          ),
          if (item.quality != null)
            Text(
              '',
              style: const TextStyle(color: AppColors.sleep),
            ),
          if (item.quality != null)
            Text(
              List.filled(item.quality!, '★').join(),
              style: const TextStyle(
                color: AppColors.sleep,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final colors = AppPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.danger.withValues(alpha: .35),
        ),
      ),
      child: Text(
        error!,
        style: TextStyle(
          color: colors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
