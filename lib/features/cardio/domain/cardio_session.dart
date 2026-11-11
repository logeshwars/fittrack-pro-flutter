class CardioSession {
  const CardioSession({required this.id, required this.type, required this.startedAt, this.name, this.finishedAt, this.durationSeconds, this.distanceKm, this.caloriesBurned, this.avgHeartRate});
  final String id;
  final String type;
  final String? name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? durationSeconds;
  final double? distanceKm;
  final int? caloriesBurned;
  final int? avgHeartRate;
  factory CardioSession.fromJson(Map<String, dynamic> json) => CardioSession(
    id: json['id'] as String, type: json['type'] as String,
    name: json['name'] as String?, startedAt: DateTime.parse(json['started_at'] as String),
    finishedAt: json['finished_at'] == null ? null : DateTime.parse(json['finished_at'] as String),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    caloriesBurned: (json['calories_burned'] as num?)?.toInt(),
    avgHeartRate: (json['avg_heart_rate'] as num?)?.toInt(),
  );
}
