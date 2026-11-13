class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.logType = 'weight_reps',
    this.isBilateral = true,
    this.isCustom = false,
    this.level,
    this.mechanic,
    this.force,
    this.category,
    this.cdnName,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
  });
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;

  /// `weight_reps`, `reps_only` or `duration` (drives which inputs a set shows).
  final String logType;
  final bool isBilateral;
  final bool isCustom;
  final String? level;
  final String? mechanic;
  final String? force;
  final String? category;

  /// Folder name in the exercise-image CDN repository.
  final String? cdnName;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscle_group'] as String,
        equipment: json['equipment'] as String,
        logType: (json['log_type'] as String?) ?? 'weight_reps',
        isBilateral: json['is_bilateral'] != false,
        isCustom: json['is_custom'] == true,
        level: json['level'] as String?,
        mechanic: json['mechanic'] as String?,
        force: json['force'] as String?,
        category: json['category'] as String?,
        cdnName: json['cdn_name'] as String?,
        primaryMuscles: _stringList(json['primary_muscles']),
        secondaryMuscles: _stringList(json['secondary_muscles']),
      );

  static List<String> _stringList(Object? value) =>
      value is List ? [for (final v in value) v.toString()] : const [];
}
