import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../data/sleep_service.dart';
import 'sleep_screen.dart' show sleepHistoryProvider;
import '../../../core/widgets/fittrack_icons.dart';

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
  /// Minutes after midnight, 0..1439.
  late int _bedMinutes;
  late int _wakeMinutes;

  /// Calendar day the night ends on; bedtime falls on this day or the one
  /// before, whichever makes the night run forward.
  late DateTime _wakeDay;
  int _quality = 3;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = defaultSleepWindow(DateTime.now());
    _bedMinutes = w.bedtime.hour * 60 + w.bedtime.minute;
    _wakeMinutes = w.wake.hour * 60 + w.wake.minute;
    _wakeDay = DateTime(w.wake.year, w.wake.month, w.wake.day);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime get _wake => DateTime(
        _wakeDay.year,
        _wakeDay.month,
        _wakeDay.day,
        _wakeMinutes ~/ 60,
        _wakeMinutes % 60,
      );

  DateTime get _bedtime {
    final day = _bedMinutes > _wakeMinutes
        ? _wakeDay.subtract(const Duration(days: 1))
        : _wakeDay;
    return DateTime(
      day.year,
      day.month,
      day.day,
      _bedMinutes ~/ 60,
      _bedMinutes % 60,
    );
  }

  int get _minutes =>
      (_wake.difference(_bedtime).inMilliseconds / 60000).round();

  bool get _valid => _minutes > 0 && _minutes <= 24 * 60;

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _wakeDay,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today,
    );
    if (date != null && mounted) {
      setState(() => _wakeDay = DateTime(date.year, date.month, date.day));
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final service = ref.read(sleepServiceProvider);
    final invalidText = context.t('common:slInvalid');
    final signInText = context.t('common:slSignIn');
    if (!_valid) {
      messenger.showSnackBar(SnackBar(content: Text(invalidText)));
      return;
    }
    if (service == null) {
      messenger.showSnackBar(SnackBar(content: Text(signInText)));
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
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.t('common:slSaved', args: {'xp': xp})),
          ),
        );
      }
      router.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final xp = _valid ? calculateSleepXp(_minutes, _quality) : 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nightLabel = _wakeDay == today
        ? context.t('common:slLastNight')
        : DateFormat('EEE, MMM d').format(_wakeDay);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.xs,
                FitTrackSpacing.sm,
                FitTrackSpacing.lg,
                FitTrackSpacing.xs,
              ),
              child: Row(
                children: [
                  FitTrackIconButton(
                    icon: FitIcons.back,
                    color: c.ink,
                    semanticLabel: context.t('settings:backLabel'),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            context.t('common:slLogTitle'),
                            style: FitTrackText.screenTitle.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          nightLabel,
                          style: FitTrackText.caption.copyWith(
                            color: c.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FitTrackButton(
                    label: context.t('common:slChangeDate'),
                    variant: FitTrackButtonVariant.ghost,
                    size: FitTrackButtonSize.sm,
                    icon: FitIcons.calendar,
                    onPressed: _pickDay,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.sm,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xl,
                ),
                children: [
                  _TimeCard(
                    title: context.t('common:slBedtime'),
                    minutes: _bedMinutes,
                    onChanged: (v) => setState(() => _bedMinutes = v),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  _TimeCard(
                    title: context.t('common:slWake'),
                    minutes: _wakeMinutes,
                    onChanged: (v) => setState(() => _wakeMinutes = v),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  FitTrackCard(
                    padding: const EdgeInsets.all(FitTrackSpacing.lg),
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      label: _valid
                          ? '${context.t('common:slDuration')}, '
                              '${formatSleepDuration(_minutes)}, '
                              '${context.t('profile:xpReward', args: {
                                    'n': xp
                                  })}'
                          : context.t('common:slInvalid'),
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Text(
                              context.t('common:slDuration').toUpperCase(),
                              style: FitTrackText.caption.copyWith(
                                color: c.muted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _valid ? formatSleepDuration(_minutes) : '—',
                              style: FitTrackText.mega.copyWith(
                                color: c.sleepColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _valid
                                  ? '${context.t('common:slOptimal')} · '
                                      '${context.t('profile:xpReward', args: {
                                            'n': xp
                                          })}'
                                  : context.t('common:slInvalid'),
                              textAlign: TextAlign.center,
                              style: FitTrackText.caption.copyWith(
                                color: _valid ? c.muted : c.textBad,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  FitTrackCard(
                    padding: const EdgeInsets.all(FitTrackSpacing.lg - 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            '${context.t('common:slQuality').toUpperCase()}'
                            ' · ${context.t('common:slQ$_quality').toUpperCase()}',
                            style: FitTrackText.caption.copyWith(
                              color: c.muted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: FitTrackSpacing.md),
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++) ...[
                              if (i > 1) const SizedBox(width: 8),
                              Expanded(
                                child: _QualityButton(
                                  value: i,
                                  selected: _quality == i,
                                  label: context.t(
                                    'common:slQualityN',
                                    args: {'n': i},
                                  ),
                                  onTap: () => setState(() => _quality = i),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.t('common:slPoor'),
                              style: FitTrackText.caption
                                  .copyWith(color: c.muted),
                            ),
                            Text(
                              context.t('common:slGreat'),
                              style: FitTrackText.caption
                                  .copyWith(color: c.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  FitTrackTextField(
                    label: context.t('common:slNotes'),
                    controller: _notes,
                    maxLines: 2,
                  ),
                  const SizedBox(height: FitTrackSpacing.lg),
                  FitTrackButton(
                    label: context.t('common:slSave'),
                    size: FitTrackButtonSize.lg,
                    fullWidth: true,
                    loading: _saving,
                    onPressed:
                        _saving || !_valid ? null : () => unawaited(_save()),
                  ),
                  const SizedBox(height: FitTrackSpacing.sm),
                  FitTrackButton(
                    label: context.t('common:cancel'),
                    variant: FitTrackButtonVariant.ghost,
                    fullWidth: true,
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hour and minute steppers with an AM/PM switch for one time of day.
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.title,
    required this.minutes,
    required this.onChanged,
  });

  final String title;

  /// Minutes after midnight.
  final int minutes;
  final ValueChanged<int> onChanged;

  static const _day = 24 * 60;

  int _wrap(int v) => ((v % _day) + _day) % _day;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final hour24 = minutes ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = minutes % 60;
    final pm = hour24 >= 12;
    final two = NumberFormat('00');

    Widget digits(String text) => SizedBox(
          width: 64,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: FitTrackText.hero.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        );

    Widget stepper({
      required String value,
      required String upLabel,
      required String downLabel,
      required int step,
    }) =>
        Column(
          children: [
            _StepButton(
              icon: FitIcons.add,
              label: upLabel,
              onTap: () => onChanged(_wrap(minutes + step)),
            ),
            digits(value),
            _StepButton(
              icon: FitIcons.remove,
              label: downLabel,
              onTap: () => onChanged(_wrap(minutes - step)),
            ),
          ],
        );

    return FitTrackCard(
      padding: const EdgeInsets.symmetric(
        horizontal: FitTrackSpacing.lg,
        vertical: FitTrackSpacing.lg - 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: FitTrackText.caption.copyWith(
                color: c.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              stepper(
                value: '$hour12',
                upLabel: context.t(
                  'common:slHourUp',
                  args: {'name': title},
                ),
                downLabel: context.t(
                  'common:slHourDown',
                  args: {'name': title},
                ),
                step: 60,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: FitTrackText.hero.copyWith(color: c.muted),
                ),
              ),
              stepper(
                value: two.format(minute),
                upLabel: context.t(
                  'common:slMinuteUp',
                  args: {'name': title},
                ),
                downLabel: context.t(
                  'common:slMinuteDown',
                  args: {'name': title},
                ),
                step: 5,
              ),
              const SizedBox(width: FitTrackSpacing.md),
              Column(
                children: [
                  _MeridiemButton(
                    label: context.t('common:slAm'),
                    selected: !pm,
                    onTap: () => pm ? onChanged(_wrap(minutes - 12 * 60)) : null,
                  ),
                  const SizedBox(height: FitTrackSpacing.sm),
                  _MeridiemButton(
                    label: context.t('common:slPm'),
                    selected: pm,
                    onTap: () => pm ? null : onChanged(_wrap(minutes + 12 * 60)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: FitTrackSpacing.touchMin,
            height: FitTrackSpacing.touchMin,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.lineStrong),
                ),
                child: Icon(icon, size: 16, color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeridiemButton extends StatelessWidget {
  const _MeridiemButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FitTrackRadius.md),
          child: Container(
            width: 56,
            height: FitTrackSpacing.touchMin,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(FitTrackRadius.md),
              border: selected ? null : Border.all(color: c.lineStrong),
            ),
            child: Text(
              label,
              style: FitTrackText.body.copyWith(
                color: selected ? c.accentText : c.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityButton extends StatelessWidget {
  const _QualityButton({
    required this.value,
    required this.selected,
    required this.label,
    required this.onTap,
  });
  final int value;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FitTrackRadius.md),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(FitTrackRadius.md),
              border: selected ? null : Border.all(color: c.lineStrong),
            ),
            child: Text(
              '$value',
              style: FitTrackText.titleLg.copyWith(
                color: selected ? c.accentText : c.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
