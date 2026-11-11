class WeightLog {
  const WeightLog({required this.id, required this.weightKg, required this.loggedAt, this.note});
  final String id;
  final double weightKg;
  final DateTime loggedAt;
  final String? note;
  factory WeightLog.fromJson(Map<String, dynamic> json) => WeightLog(
    id: json['id'] as String,
    weightKg: (json['weight_kg'] as num).toDouble(),
    loggedAt: DateTime.parse(json['logged_at'] as String),
    note: json['note'] as String?,
  );
}

class SleepLog {
  const SleepLog({required this.id, required this.bedtime, required this.wakeTime, required this.durationMinutes, this.quality});
  final String id;
  final DateTime bedtime;
  final DateTime wakeTime;
  final int durationMinutes;
  final int? quality;
  factory SleepLog.fromJson(Map<String, dynamic> json) => SleepLog(
    id: json['id'] as String,
    bedtime: DateTime.parse(json['bedtime'] as String),
    wakeTime: DateTime.parse(json['wake_time'] as String),
    durationMinutes: (json['duration_minutes'] as num).toInt(),
    quality: (json['quality'] as num?)?.toInt(),
  );
}

class ProgressSummary {
  const ProgressSummary({required this.latestWeightKg, required this.weightChangeKg, required this.averageSleepHours});
  final double? latestWeightKg;
  final double? weightChangeKg;
  final double? averageSleepHours;

  factory ProgressSummary.fromLogs({required List<WeightLog> weights, required List<SleepLog> sleep}) {
    final sorted = [...weights]..sort((a,b) => b.loggedAt.compareTo(a.loggedAt));
    final latest = sorted.isEmpty ? null : sorted.first.weightKg;
    final change = sorted.length < 2 ? null : sorted.first.weightKg - sorted.last.weightKg;
    final average = sleep.isEmpty ? null : sleep.map((s) => s.durationMinutes).reduce((a,b) => a+b) / sleep.length / 60;
    return ProgressSummary(latestWeightKg: latest, weightChangeKg: change, averageSleepHours: average);
  }
}
