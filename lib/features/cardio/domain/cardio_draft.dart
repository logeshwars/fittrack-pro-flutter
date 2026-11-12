import 'dart:convert';

class CardioDraft {
  const CardioDraft(
      {required this.type, required this.durationMinutes, this.distanceKm});
  final String type;
  final int durationMinutes;
  final double? distanceKm;
  bool get isValid =>
      type.trim().isNotEmpty &&
      durationMinutes > 0 &&
      durationMinutes <= 1440 &&
      (distanceKm == null || (distanceKm!.isFinite && distanceKm! >= 0));
  Map<String, dynamic> toJson() => {
        'type': type,
        'duration_minutes': durationMinutes,
        'distance_km': distanceKm,
      };
  factory CardioDraft.fromJson(Map<String, dynamic> json) => CardioDraft(
        type: json['type'] as String,
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );
}

class CardioDrafts {
  const CardioDrafts(this.items);
  final List<CardioDraft> items;
  int get totalMinutes =>
      items.fold<int>(0, (sum, item) => sum + item.durationMinutes);
  CardioDrafts add(CardioDraft item) => CardioDrafts([...items, item]);
  String encode() => jsonEncode(items.map((item) => item.toJson()).toList());
  factory CardioDrafts.decode(String raw) => CardioDrafts(
        (jsonDecode(raw) as List<dynamic>)
            .map((item) => CardioDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
