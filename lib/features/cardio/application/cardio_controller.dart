import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';
import '../domain/cardio_tracking.dart';

const _prefsKey = 'fittrack_active_cardio_v1';

/// Source of GPS fixes; overridable in tests.
abstract class PositionSource {
  /// Requests permission when needed. Returns false when GPS cannot be used.
  Future<bool> ensurePermission();
  Stream<GpsPoint> positions();
}

class GeolocatorPositionSource implements PositionSource {
  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Stream<GpsPoint> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).map(
        (p) => GpsPoint(
          p.latitude,
          p.longitude,
          p.accuracy,
          p.timestamp.millisecondsSinceEpoch,
        ),
      );
}

final positionSourceProvider =
    Provider<PositionSource>((ref) => GeolocatorPositionSource());

/// Result of finishing a session.
class CardioFinishResult {
  const CardioFinishResult({required this.xp, required this.durationSeconds});
  final int xp;
  final int durationSeconds;
}

class CardioController extends Notifier<CardioSessionState?> {
  final GpsAccumulator _gps = GpsAccumulator();
  StreamSubscription<GpsPoint>? _sub;

  @override
  CardioSessionState? build() {
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  Future<bool> restore() async {
    if (state != null) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = CardioSessionState.decode(prefs.getString(_prefsKey));
    if (saved == null) {
      return false;
    }
    state = saved;
    _gps.seed(saved.distanceKm);
    if (saved.gpsEnabled && !saved.isPaused) {
      await _startGps();
    }
    return true;
  }

  Future<void> start(String type, String name) async {
    _gps.seed(0);
    _gps.breakSegment();
    state = CardioSessionState(
      type: type,
      name: name,
      startMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persist();
  }

  /// Turns GPS distance tracking on/off. Returns false if it could not start.
  Future<bool> setGps(bool enabled) async {
    final current = state;
    if (current == null) {
      return false;
    }
    if (!enabled) {
      await _sub?.cancel();
      _sub = null;
      state = current.copyWith(gpsEnabled: false);
      await _persist();
      return true;
    }
    final ok = await ref.read(positionSourceProvider).ensurePermission();
    if (!ok) {
      return false;
    }
    state = current.copyWith(gpsEnabled: true, distanceManual: false);
    if (!current.isPaused) {
      await _startGps();
    }
    await _persist();
    return true;
  }

  Future<void> _startGps() async {
    await _sub?.cancel();
    _gps.breakSegment();
    _sub = ref.read(positionSourceProvider).positions().listen((p) {
      final current = state;
      if (current == null || current.isPaused || !current.gpsEnabled) {
        return;
      }
      if (_gps.add(p)) {
        state = current.copyWith(distanceKm: _gps.kilometres);
        unawaited(_persist());
      }
    }, onError: (Object _) {});
  }

  Future<void> pause() async {
    final current = state;
    if (current == null || current.isPaused) {
      return;
    }
    await _sub?.cancel();
    _sub = null;
    state = current.copyWith(
      isPaused: true,
      pausedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persist();
  }

  Future<void> resume() async {
    final current = state;
    if (current == null || !current.isPaused) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final pausedFor =
        current.pausedAtMs == null ? 0 : now - current.pausedAtMs!;
    state = current.copyWith(
      isPaused: false,
      clearPausedAt: true,
      totalPausedMs: current.totalPausedMs + pausedFor,
    );
    if (current.gpsEnabled) {
      await _startGps();
    }
    await _persist();
  }

  Future<void> setDistanceManual(String text) async {
    final current = state;
    if (current == null) {
      return;
    }
    final km = double.tryParse(text.trim()) ?? 0;
    _gps.seed(km);
    state = current.copyWith(distanceKm: km, distanceManual: true);
    await _persist();
  }

  Future<void> setHeartRate(String v) =>
      _update((s) => s.copyWith(heartRate: v));

  Future<void> setCalories(String v) =>
      _update((s) => s.copyWith(calories: v, caloriesManual: true));

  Future<void> setAutoCalories(int kcal) => _update(
        (s) => s.caloriesManual ? s : s.copyWith(calories: '$kcal'),
      );

  Future<void> setNotes(String v) => _update((s) => s.copyWith(notes: v));

  Future<void> _update(
      CardioSessionState Function(CardioSessionState) f) async {
    final current = state;
    if (current == null) {
      return;
    }
    state = f(current);
    await _persist();
  }

  /// Saves the session and awards XP. Returns null if there is nothing to save.
  Future<CardioFinishResult?> finish() async {
    final current = state;
    final service = ref.read(cardioServiceProvider);
    if (current == null || service == null) {
      return null;
    }
    final seconds =
        current.elapsedSeconds(DateTime.now().millisecondsSinceEpoch);
    if (seconds <= 0) {
      return null;
    }
    final km = current.distanceKm > 0 ? current.distanceKm : null;
    final xp = await service.logSession(
      type: current.type,
      name: current.name.isEmpty ? null : current.name,
      durationSeconds: seconds,
      distanceKm: km == null ? null : (km * 100).round() / 100,
      caloriesBurned: int.tryParse(current.calories),
      avgHeartRate: int.tryParse(current.heartRate),
      notes: current.notes.isEmpty ? null : current.notes,
    );
    await ref.read(gamificationServiceProvider)?.awardXp(xp);
    await _clear();
    return CardioFinishResult(xp: xp, durationSeconds: seconds);
  }

  Future<void> discard() => _clear();

  Future<void> _clear() async {
    await _sub?.cancel();
    _sub = null;
    _gps.seed(0);
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _persist() async {
    final current = state;
    if (current == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, current.encode());
  }
}

final cardioControllerProvider =
    NotifierProvider<CardioController, CardioSessionState?>(
        CardioController.new);
