class GamificationStats {
  const GamificationStats({
    required this.totalXp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalWorkouts,
    required this.totalPrs,
    required this.totalVolumeKg,
    required this.rankTier,
  });

  final int totalXp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final int totalWorkouts;
  final int totalPrs;
  final double totalVolumeKg;
  final String rankTier;

  /// Mirrors the existing React Native XP-to-level formula.
  static int levelFromXp(int xp) => (xp ~/ 500) + 1;

  factory GamificationStats.fromJson(Map<String, dynamic> json) =>
      GamificationStats(
        totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
        totalWorkouts: (json['total_workouts'] as num?)?.toInt() ?? 0,
        totalPrs: (json['total_prs'] as num?)?.toInt() ?? 0,
        totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble() ?? 0,
        rankTier: json['rank_tier'] as String? ?? 'Unranked',
      );
}
