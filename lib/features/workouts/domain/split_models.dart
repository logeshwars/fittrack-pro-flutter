/// One planned exercise inside a split day (port of `PredefinedExercise`).
class PredefinedExercise {
  const PredefinedExercise({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.repsRange,
    required this.restSecs,
    required this.alternatives,
  });

  final String name;
  final String muscleGroup;
  final int sets;
  final String repsRange;
  final int restSecs;
  final List<String> alternatives;
}

class SplitDay {
  const SplitDay({
    required this.label,
    required this.focus,
    required this.exercises,
  });

  final String label;
  final String focus;
  final List<PredefinedExercise> exercises;
}

class WorkoutSplit {
  const WorkoutSplit({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.frequency,
    required this.accentBg,
    required this.accentBorder,
    required this.accentText,
    required this.days,
  });

  final String id;
  final String name;
  final String shortName;
  final String description;
  final String frequency;
  final String accentBg;
  final String accentBorder;
  final String accentText;
  final List<SplitDay> days;
}

/// Formats a rest period such as 180 -> "3 min", 90 -> "1:30", 60 -> "1 min".
String formatRest(int secs) {
  if (secs < 60) {
    return '${secs}s';
  }
  final m = secs ~/ 60;
  final s = secs % 60;
  return s == 0 ? '$m min' : '$m:${s.toString().padLeft(2, '0')}';
}
