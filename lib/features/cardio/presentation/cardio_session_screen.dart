import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../application/cardio_controller.dart';
import '../data/cardio_service.dart';
import '../domain/cardio_tracking.dart';
import 'cardio_screen.dart' show cardioProvider, cardioStatsProvider;
import '../../../core/widgets/fittrack_icons.dart';

/// Live cardio session: timer, optional GPS distance, calories, finish.
class CardioSessionScreen extends ConsumerStatefulWidget {
  const CardioSessionScreen({required this.type, super.key});
  final String type;

  @override
  ConsumerState<CardioSessionScreen> createState() =>
      _CardioSessionScreenState();
}

class _CardioSessionScreenState extends ConsumerState<CardioSessionScreen>
    with WidgetsBindingObserver {
  Timer? _tick;
  final _distance = TextEditingController();
  final _calories = TextEditingController();
  final _heart = TextEditingController();
  final _notes = TextEditingController();
  double _weightKg = 70;
  double _heightCm = 170;
  bool _ready = false;
  bool _saving = false;
  int _lastAutoCalMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    unawaited(_bootstrap().catchError((Object _) {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _distance.dispose();
    _calories.dispose();
    _heart.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    final controller = ref.read(cardioControllerProvider.notifier);
    final resumed = await controller.restore();
    if (!resumed) {
      await controller.start(
        widget.type,
        cardioLabels[widget.type] ?? 'Cardio',
      );
    }
    try {
      final profile = await ref.read(profileServiceProvider)?.profile();
      _weightKg = (profile?['bodyweight_kg'] as num?)?.toDouble() ?? _weightKg;
      _heightCm = (profile?['height_cm'] as num?)?.toDouble() ?? _heightCm;
    } on Object {
      // Offline without a cached profile: use defaults.
    }
    final s = ref.read(cardioControllerProvider);
    if (s != null) {
      _distance.text = s.distanceKm > 0 ? s.distanceKm.toStringAsFixed(2) : '';
      _calories.text = s.calories;
      _heart.text = s.heartRate;
      _notes.text = s.notes;
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  void _onTick() {
    final s = ref.read(cardioControllerProvider);
    if (!mounted || s == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // Mirror GPS distance into the field unless the user typed their own.
    if (s.gpsEnabled && !s.distanceManual && !_hasFocus) {
      final text = s.distanceKm > 0 ? s.distanceKm.toStringAsFixed(2) : '';
      if (_distance.text != text) {
        _distance.text = text;
      }
    }
    if (!s.caloriesManual && now - _lastAutoCalMs >= 5000 && !s.isPaused) {
      _lastAutoCalMs = now;
      final kcal = estimateCalories(
        type: s.type,
        seconds: s.elapsedSeconds(now),
        weightKg: _weightKg,
        heightCm: _heightCm,
      );
      if (kcal > 0) {
        _calories.text = '$kcal';
        unawaited(
          ref
              .read(cardioControllerProvider.notifier)
              .setAutoCalories(kcal)
              .catchError((Object _) {}),
        );
      }
    }
    setState(() {});
  }

  bool get _hasFocus => FocusManager.instance.primaryFocus?.hasFocus ?? false;

  Future<void> _toggleGps(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final denied = context.t('common:cardioGpsDenied');
    final ok = await ref.read(cardioControllerProvider.notifier).setGps(on);
    if (!ok && on && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(denied)));
    }
  }

  Future<void> _finish() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(cardioControllerProvider.notifier);
    final nothing = context.t('common:cardioNothingToSave');
    String saved(int xp) => context.t('common:cardioSavedXp', args: {'xp': xp});
    setState(() => _saving = true);
    try {
      final result = await controller.finish();
      if (result == null) {
        messenger.showSnackBar(SnackBar(content: Text(nothing)));
        return;
      }
      ref.invalidate(cardioProvider);
      ref.invalidate(cardioStatsProvider);
      messenger.showSnackBar(SnackBar(content: Text(saved(result.xp))));
      router.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _discard() async {
    final router = GoRouter.of(context);
    final ok = await showFitTrackConfirm(
      context: context,
      title: context.t('common:cardioDiscardTitle'),
      message: context.t('common:cardioDiscardBody'),
      confirmLabel: context.t('common:cardioDiscard'),
      cancelLabel: context.t('common:cardioKeepGoing'),
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await ref.read(cardioControllerProvider.notifier).discard();
    router.pop();
  }

  String _typeName(BuildContext context, String type) => switch (type) {
        'running' => context.t('common:cardioTypeRunning'),
        'cycling' => context.t('common:cardioTypeCycling'),
        'walking' => context.t('common:cardioTypeWalking'),
        'swimming' => context.t('common:cardioTypeSwimming'),
        'hiit' => context.t('common:cardioTypeHiit'),
        'other' => context.t('common:cardioTypeOther'),
        _ => cardioLabels[type] ?? context.t('common:cardioTitle'),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final s = ref.watch(cardioControllerProvider);
    if (!_ready || s == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }
    final controller = ref.read(cardioControllerProvider.notifier);
    final now = DateTime.now().millisecondsSinceEpoch;
    final seconds = s.elapsedSeconds(now);
    final pace = formatPace(seconds, s.distanceKm);
    final xp = calculateCardioXp(
      durationSeconds: seconds,
      distanceKm: s.distanceKm > 0 ? s.distanceKm : null,
    );
    final kcal = int.tryParse(s.calories.trim());
    final clock = formatClock(seconds);
    final stateColor = s.isPaused ? c.warning : c.cardioColor;
    const gap = SizedBox(height: FitTrackSpacing.md);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            FitTrackTopBar(
              title: _typeName(context, s.type),
              subtitle: context.t(
                s.gpsEnabled ? 'common:cardioGpsOn' : 'common:cardioGpsOff',
              ),
              backLabel: context.t('settings:backLabel'),
              onBack: () => context.pop(),
              trailing: FitTrackButton(
                label: context.t('common:cardioDiscard'),
                variant: FitTrackButtonVariant.ghost,
                size: FitTrackButtonSize.sm,
                onPressed: _discard,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.md,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xxl,
                ),
                children: [
                  FitTrackCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: FitTrackSpacing.xl,
                      horizontal: 14,
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.t('common:cardioTime'),
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                        const SizedBox(height: FitTrackSpacing.xs),
                        Semantics(
                          label: context.t('common:cardioElapsed'),
                          value: clock,
                          child: ExcludeSemantics(
                            child: Text(
                              clock,
                              style: FitTrackText.mega.copyWith(
                                color: s.isPaused ? c.warning : c.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: FitTrackSpacing.xs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.isPaused ? FitIcons.pause : FitIcons.play,
                              size: 14,
                              color: stateColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.t(
                                s.isPaused
                                    ? 'common:cardioPaused'
                                    : 'common:cardioRunning',
                              ),
                              style: FitTrackText.caption.copyWith(
                                color: stateColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  gap,
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: context.t('common:cardioStatDistance'),
                          value: s.distanceKm.toStringAsFixed(2),
                          unit: context.t('common:cardioKm'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          label: context.t('common:cardioPace'),
                          value: pace ?? '—',
                          unit: context.t('common:cardioPerKm'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: context.t('common:cardioCaloriesLabel'),
                          value: kcal == null ? '—' : '$kcal',
                          unit: context.t('nutrition:unitKcal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          label: context.t('common:cardioXpSoFar'),
                          value: '+$xp',
                          unit: context.t('common:cardioXpUnit'),
                        ),
                      ),
                    ],
                  ),
                  gap,
                  FitTrackCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('common:cardioGpsTitle'),
                                style: FitTrackText.title.copyWith(
                                  color: c.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.t('common:cardioGpsDesc'),
                                style: FitTrackText.caption
                                    .copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          label: context.t('common:cardioGpsTitle'),
                          child: Switch(
                            value: s.gpsEnabled,
                            onChanged: _toggleGps,
                          ),
                        ),
                      ],
                    ),
                  ),
                  gap,
                  FitTrackCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FitTrackTextField(
                          label: context.t('common:cardioDistanceKm'),
                          helper: context.t('common:cardioDistanceHelper'),
                          controller: _distance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: controller.setDistanceManual,
                        ),
                        gap,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FitTrackTextField(
                                label: context.t('common:cardioCaloriesLabel'),
                                helper: context.t(
                                  s.caloriesManual
                                      ? 'common:cardioCalManual'
                                      : 'common:cardioCalEstimated',
                                ),
                                controller: _calories,
                                keyboardType: TextInputType.number,
                                onChanged: controller.setCalories,
                              ),
                            ),
                            const SizedBox(width: FitTrackSpacing.md),
                            Expanded(
                              child: FitTrackTextField(
                                label: context.t('common:cardioHeartRate'),
                                controller: _heart,
                                keyboardType: TextInputType.number,
                                onChanged: controller.setHeartRate,
                              ),
                            ),
                          ],
                        ),
                        gap,
                        FitTrackTextField(
                          label: context.t('common:cardioNotes'),
                          controller: _notes,
                          maxLines: 2,
                          onChanged: controller.setNotes,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: FitTrackButton(
                          label: context.t(
                            s.isPaused
                                ? 'common:cardioResume'
                                : 'common:cardioPause',
                          ),
                          icon: s.isPaused ? FitIcons.play : FitIcons.pause,
                          variant: FitTrackButtonVariant.secondary,
                          size: FitTrackButtonSize.lg,
                          fullWidth: true,
                          onPressed:
                              s.isPaused ? controller.resume : controller.pause,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FitTrackButton(
                          label: context.t('common:cardioFinish'),
                          icon: FitIcons.check,
                          size: FitTrackButtonSize.lg,
                          fullWidth: true,
                          loading: _saving,
                          loadingLabel: context.t('common:cardioFinish'),
                          onPressed: _saving ? null : _finish,
                        ),
                      ),
                    ],
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

/// Label, big value and unit on a flat card.
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
          const SizedBox(height: FitTrackSpacing.xs),
          Text.rich(
            TextSpan(
              text: value,
              style: FitTrackText.statLg.copyWith(color: c.ink),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
