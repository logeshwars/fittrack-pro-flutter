import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/badges_data.dart';
import '../domain/badge_definition.dart';
import '../domain/badge_progress.dart';

class AchievementsData {
  const AchievementsData({required this.stats, required this.earnedIds});
  final Map<String, dynamic> stats;
  final Set<String> earnedIds;
}

final achievementsProvider =
    FutureProvider.autoDispose<AchievementsData?>((ref) async {
  final service = ref.watch(gamificationServiceProvider);
  if (service == null) {
    return null;
  }
  final stats = await service.stats();
  if (stats == null) {
    return null;
  }
  final badges = await service.badges();
  return AchievementsData(
    stats: stats,
    earnedIds: {for (final b in badges) '${b['badge_id']}'},
  );
});

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final data = ref.watch(achievementsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accent,
          onRefresh: () async {
            ref.invalidate(achievementsProvider);
            await ref.read(achievementsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              FitTrackScreenHeader(
                title: 'Achievements',
                subtitle: 'Level, rank and badges',
                trailing: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.close, color: colors.muted),
                ),
              ),
              data.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                      child: CircularProgressIndicator(color: colors.accent)),
                ),
                error: (_, __) => _Message(
                  text: 'Unable to load achievements.',
                  action: 'Retry',
                  onAction: () => ref.invalidate(achievementsProvider),
                ),
                data: (value) => value == null
                    ? const _Message(text: 'Sign in to see your achievements.')
                    : _Body(data: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final AchievementsData data;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final stats = data.stats;
    final xp = (stats['total_xp'] as num?)?.toInt() ?? 0;
    final level = (stats['level'] as num?)?.toInt() ?? 1;
    final tier = '${stats['rank_tier'] ?? 'bronze'}';
    final progress = levelProgress(xp);
    final earned = {
      for (final b in badgeDefinitions)
        if (isBadgeEarned(b, stats, data.earnedIds)) b.id,
    };
    final categories = <String>[];
    for (final b in badgeDefinitions) {
      if (!categories.contains(b.category)) {
        categories.add(b.category);
      }
    }

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colors.text)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 9, letterSpacing: 1, color: colors.faint)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: colors.card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Level $level',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: colors.text),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: tierColor(tier).withValues(alpha: .6)),
                      ),
                      child: Text(
                        tierLabel(tier),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tierColor(tier)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.fill,
                    minHeight: 8,
                    color: colors.accent,
                    backgroundColor: colors.border2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$xp XP · ${progress.toNext} XP to level ${level + 1}',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    stat('WORKOUTS',
                        '${(stats['total_workouts'] as num?)?.toInt() ?? 0}'),
                    stat(
                        'PRS', '${(stats['total_prs'] as num?)?.toInt() ?? 0}'),
                    stat('STREAK',
                        '${(stats['current_streak'] as num?)?.toInt() ?? 0}d'),
                    stat('BEST',
                        '${(stats['longest_streak'] as num?)?.toInt() ?? 0}d'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/leaderboard'),
            icon: const Icon(Icons.leaderboard_outlined, size: 18),
            label: const Text('Monthly leaderboard'),
          ),
          const SizedBox(height: 8),
          FitTrackSectionLabel(
              title: 'Badges  ${earned.length}/${badgeDefinitions.length}'),
          for (final category in categories) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                category.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: colors.muted),
              ),
            ),
            for (final b
                in badgeDefinitions.where((b) => b.category == category))
              _BadgeTile(badge: b, stats: stats, earned: earned.contains(b.id)),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile(
      {required this.badge, required this.stats, required this.earned});
  final BadgeDefinition badge;
  final Map<String, dynamic> stats;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final progress = badgeProgress(badge, stats);
    return Opacity(
      opacity: earned ? 1 : .6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: earned
              ? Border.all(color: AppColors.xp.withValues(alpha: .5))
              : null,
        ),
        child: Row(
          children: [
            Text(earned ? badge.emoji : '🔒',
                style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: colors.text)),
                  const SizedBox(height: 2),
                  Text(badge.description,
                      style: TextStyle(fontSize: 11, color: colors.muted)),
                  if (!earned && progress > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        color: colors.accent,
                        backgroundColor: colors.border2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('+${badge.xpReward}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.xp)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: colors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}
