import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../application/cardio_controller.dart';
import '../data/cardio_service.dart';
import '../domain/cardio_tracking.dart';
import 'cardio_screen.dart' show cardioProvider, cardioStatsProvider;

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
    final ok = await ref.read(cardioControllerProvider.notifier).setGps(on);
    if (!ok && on && mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Location permission or services unavailable.'),
        ),
      );
    }
  }

  Future<void> _finish() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(cardioControllerProvider.notifier);
    setState(() => _saving = true);
    try {
      final result = await controller.finish();
      if (result == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to save yet — keep going!')),
        );
        return;
      }
      ref.invalidate(cardioProvider);
      ref.invalidate(cardioStatsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Session saved · +${result.xp} XP')),
      );
      router.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _discard() async {
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard session?'),
        content: const Text('This session will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await ref.read(cardioControllerProvider.notifier).discard();
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final s = ref.watch(cardioControllerProvider);
    if (!_ready || s == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: CircularProgressIndicator()),
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
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.header,
        foregroundColor: colors.text,
        title: Text(cardioLabels[s.type] ?? 'Cardio'),
        actions: [
          TextButton(onPressed: _discard, child: const Text('Discard')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Text(
              formatClock(seconds),
              style: TextStyle(
                fontSize: 64,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: s.isPaused ? colors.warning : colors.text,
              ),
            ),
          ),
          Center(
            child: Text(
              s.isPaused ? 'PAUSED' : 'RUNNING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: s.isPaused ? colors.warning : AppColors.cardio,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'DISTANCE',
                  value: '${s.distanceKm.toStringAsFixed(2)} km',
                ),
              ),
              Expanded(
                  child: _Stat(
                      label: 'PACE', value: pace == null ? '—' : '$pace /km')),
              Expanded(child: _Stat(label: 'XP', value: '+$xp')),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: s.gpsEnabled,
            onChanged: _toggleGps,
            title: const Text('Track distance with GPS'),
            subtitle: const Text('Uses your location while the session runs'),
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: controller.setDistanceManual,
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
              helperText: 'Edit to override GPS',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  onChanged: controller.setCalories,
                  decoration: InputDecoration(
                    labelText: 'Calories',
                    helperText: s.caloriesManual ? 'Manual' : 'Estimated',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heart,
                  keyboardType: TextInputType.number,
                  onChanged: controller.setHeartRate,
                  decoration:
                      const InputDecoration(labelText: 'Avg heart rate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            onChanged: controller.setNotes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: s.isPaused ? controller.resume : controller.pause,
                  icon: Icon(s.isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(s.isPaused ? 'RESUME' : 'PAUSE'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _finish,
                  icon: const Icon(Icons.check),
                  label: const Text('FINISH'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.accentText,
                    padding: const EdgeInsets.symmetric(vertical: 15),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style:
              TextStyle(fontSize: 9, letterSpacing: 1.4, color: colors.muted),
        ),
      ],
    );
  }
}
