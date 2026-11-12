import 'dart:convert';
import 'dart:math';

/// MET values per activity (ported from the RN session screen).
const Map<String, double> cardioMet = {
  'running': 9.8,
  'cycling': 7.5,
  'walking': 3.5,
  'swimming': 8.0,
  'hiit': 10.0,
  'rowing': 7.0,
  'elliptical': 5.0,
  'other': 5.0,
};

const Map<String, String> cardioLabels = {
  'running': 'Run',
  'cycling': 'Cycle',
  'walking': 'Walk',
  'swimming': 'Swim',
  'hiit': 'HIIT',
  'rowing': 'Row',
  'elliptical': 'Elliptical',
  'other': 'Cardio',
};

/// Calories burned: MET x body surface area (Du Bois) x 58.2 x hours.
int estimateCalories({
  required String type,
  required int seconds,
  double weightKg = 70,
  double heightCm = 170,
}) {
  final bsa =
      0.007184 * pow(heightCm, 0.725) * pow(weightKg, 0.425);
  final met = cardioMet[type] ?? 5.0;
  return (met * bsa * 58.2 * (seconds / 3600)).round();
}

/// Great-circle distance in kilometres.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0088;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(min(1.0, sqrt(a.toDouble())));
}

/// One GPS fix.
class GpsPoint {
  const GpsPoint(this.lat, this.lon, this.accuracyM, this.timeMs);
  final double lat;
  final double lon;
  final double accuracyM;
  final int timeMs;
}

/// Accumulates distance from noisy GPS fixes. Drops inaccurate fixes,
/// sub-jitter movement and physically implausible jumps.
class GpsAccumulator {
  GpsAccumulator({
    this.maxAccuracyM = 30,
    this.minStepM = 3,
    this.maxSpeedMs = 12,
  });

  final double maxAccuracyM;
  final double minStepM;
  final double maxSpeedMs;

  GpsPoint? _last;
  double _meters = 0;

  double get kilometres => _meters / 1000;

  /// Returns true when [p] extended the route.
  bool add(GpsPoint p) {
    if (p.accuracyM > maxAccuracyM) {
      return false;
    }
    final last = _last;
    if (last == null) {
      _last = p;
      return false;
    }
    final step = haversineKm(last.lat, last.lon, p.lat, p.lon) * 1000;
    final dt = (p.timeMs - last.timeMs) / 1000;
    if (step < minStepM) {
      return false;
    }
    if (dt <= 0 || step / dt > maxSpeedMs) {
      return false;
    }
    _meters += step;
    _last = p;
    return true;
  }

  /// Forget the last fix (e.g. after a pause) without losing distance.
  void breakSegment() => _last = null;

  /// Restore previously accumulated distance (app restart).
  void seed(double km) => _meters = km * 1000;
}

/// Persisted state of an in-progress cardio session.
class CardioSessionState {
  const CardioSessionState({
    required this.type,
    required this.name,
    required this.startMs,
    this.isPaused = false,
    this.pausedAtMs,
    this.totalPausedMs = 0,
    this.distanceKm = 0,
    this.distanceManual = false,
    this.gpsEnabled = false,
    this.heartRate = '',
    this.calories = '',
    this.caloriesManual = false,
    this.notes = '',
  });

  final String type;
  final String name;
  final int startMs;
  final bool isPaused;
  final int? pausedAtMs;
  final int totalPausedMs;
  final double distanceKm;
  final bool distanceManual;
  final bool gpsEnabled;
  final String heartRate;
  final String calories;
  final bool caloriesManual;
  final String notes;

  /// Elapsed seconds excluding paused time.
  int elapsedSeconds(int nowMs) {
    final end = isPaused && pausedAtMs != null ? pausedAtMs! : nowMs;
    return max(0, (end - startMs - totalPausedMs) ~/ 1000);
  }

  CardioSessionState copyWith({
    bool? isPaused,
    int? pausedAtMs,
    bool clearPausedAt = false,
    int? totalPausedMs,
    double? distanceKm,
    bool? distanceManual,
    bool? gpsEnabled,
    String? heartRate,
    String? calories,
    bool? caloriesManual,
    String? notes,
  }) =>
      CardioSessionState(
        type: type,
        name: name,
        startMs: startMs,
        isPaused: isPaused ?? this.isPaused,
        pausedAtMs: clearPausedAt ? null : (pausedAtMs ?? this.pausedAtMs),
        totalPausedMs: totalPausedMs ?? this.totalPausedMs,
        distanceKm: distanceKm ?? this.distanceKm,
        distanceManual: distanceManual ?? this.distanceManual,
        gpsEnabled: gpsEnabled ?? this.gpsEnabled,
        heartRate: heartRate ?? this.heartRate,
        calories: calories ?? this.calories,
        caloriesManual: caloriesManual ?? this.caloriesManual,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'startMs': startMs,
        'isPaused': isPaused,
        'pausedAtMs': pausedAtMs,
        'totalPausedMs': totalPausedMs,
        'distanceKm': distanceKm,
        'distanceManual': distanceManual,
        'gpsEnabled': gpsEnabled,
        'heartRate': heartRate,
        'calories': calories,
        'caloriesManual': caloriesManual,
        'notes': notes,
      };

  String encode() => jsonEncode(toJson());

  static CardioSessionState? decode(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return CardioSessionState(
        type: j['type'] as String,
        name: (j['name'] as String?) ?? '',
        startMs: (j['startMs'] as num).toInt(),
        isPaused: j['isPaused'] == true,
        pausedAtMs: (j['pausedAtMs'] as num?)?.toInt(),
        totalPausedMs: (j['totalPausedMs'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        distanceManual: j['distanceManual'] == true,
        gpsEnabled: j['gpsEnabled'] == true,
        heartRate: (j['heartRate'] as String?) ?? '',
        calories: (j['calories'] as String?) ?? '',
        caloriesManual: j['caloriesManual'] == true,
        notes: (j['notes'] as String?) ?? '',
      );
    } on Object {
      return null;
    }
  }
}

/// mm:ss, or h:mm:ss from one hour.
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Pace as min/km text, or null when it cannot be computed.
String? formatPace(int seconds, double km) {
  if (km <= 0.05 || seconds <= 0) {
    return null;
  }
  final perKm = seconds / km;
  final m = perKm ~/ 60;
  final s = (perKm % 60).round();
  return s == 60 ? '${m + 1}:00' : '$m:${s.toString().padLeft(2, '0')}';
}
