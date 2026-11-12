import 'dart:convert';

enum OfflineOperationType {
  startWorkout,
  logSet,
  finishWorkout,
  logFood,
  logCardioSession,
  logSleep,
  logWeight,
}

/// The operation ID must remain stable across retries so the eventual
/// backend adapter can deduplicate replayed writes.
class OfflineOperation {
  const OfflineOperation({
    required this.id,
    required this.userId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });
  final String id;
  final String userId;
  final OfflineOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  OfflineOperation withAttempts(int value) => OfflineOperation(
        id: id,
        userId: userId,
        type: type,
        payload: payload,
        createdAt: createdAt,
        attempts: value,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'payload': payload,
        'created_at': createdAt.toUtc().toIso8601String(),
        'attempts': attempts,
      };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) =>
      OfflineOperation(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: OfflineOperationType.values.byName(json['type'] as String),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );

  String encode() => jsonEncode(toJson());
  static OfflineOperation decode(String source) =>
      OfflineOperation.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
