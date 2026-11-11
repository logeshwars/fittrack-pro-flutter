import 'dart:convert';

class WeightDraft {
  const WeightDraft({
    required this.kg,
    required this.loggedAt,
    this.note,
  });

  final double kg;
  final DateTime loggedAt;
  final String? note;

  bool get isValid => kg.isFinite && kg > 0 && kg <= 500;

  Map<String, dynamic> toJson() => {
    'kg': kg,
    'logged_at': loggedAt.toUtc().toIso8601String(),
    'note': note,
  };

  factory WeightDraft.fromJson(Map<String, dynamic> json) => WeightDraft(
    kg: (json['kg'] as num).toDouble(),
    loggedAt: DateTime.parse(json['logged_at'] as String),
    note: json['note'] as String?,
  );
}

class SleepDraft {
  const SleepDraft({
    required this.bedtime,
    required this.wakeTime,
    this.quality,
    this.notes,
  });

  final DateTime bedtime;
  final DateTime wakeTime;
  final int? quality;
  final String? notes;

  int get durationMinutes => wakeTime.difference(bedtime).inMinutes;

  bool get isValid =>
      durationMinutes > 0 &&
      durationMinutes <= 1440 &&
      (quality == null || (quality! >= 1 && quality! <= 5));

  Map<String, dynamic> toJson() => {
    'bedtime': bedtime.toUtc().toIso8601String(),
    'wake_time': wakeTime.toUtc().toIso8601String(),
    'quality': quality,
    'notes': notes,
  };

  factory SleepDraft.fromJson(Map<String, dynamic> json) => SleepDraft(
    bedtime: DateTime.parse(json['bedtime'] as String),
    wakeTime: DateTime.parse(json['wake_time'] as String),
    quality: (json['quality'] as num?)?.toInt(),
    notes: json['notes'] as String?,
  );
}

class HealthDrafts {
  const HealthDrafts({this.weights = const [], this.sleep = const []});

  final List<WeightDraft> weights;
  final List<SleepDraft> sleep;

  HealthDrafts addWeight(WeightDraft draft) =>
      HealthDrafts(weights: [...weights, draft], sleep: sleep);

  HealthDrafts addSleep(SleepDraft draft) =>
      HealthDrafts(weights: weights, sleep: [...sleep, draft]);

  String encode() => jsonEncode({
    'weights': weights.map((item) => item.toJson()).toList(),
    'sleep': sleep.map((item) => item.toJson()).toList(),
  });

  factory HealthDrafts.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return HealthDrafts(
      weights: (json['weights'] as List<dynamic>)
          .map((item) => WeightDraft.fromJson(item as Map<String, dynamic>))
          .toList(),
      sleep: (json['sleep'] as List<dynamic>)
          .map((item) => SleepDraft.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
