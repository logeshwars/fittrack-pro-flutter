import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/gamification/domain/gamification_stats.dart';

void main() {
  test('XP level matches existing app', () {
    expect(GamificationStats.levelFromXp(0), 1);
    expect(GamificationStats.levelFromXp(499), 1);
    expect(GamificationStats.levelFromXp(500), 2);
    expect(GamificationStats.levelFromXp(1500), 4);
  });
  test('maps nullable stats safely', () {
    final stats = GamificationStats.fromJson(
        {'total_xp': 1200, 'total_volume_kg': 123.5});
    expect(stats.totalXp, 1200);
    expect(stats.totalVolumeKg, 123.5);
    expect(stats.currentStreak, 0);
  });
}
