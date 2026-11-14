import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/badges_data.dart';
import '../domain/badge_definition.dart';
import '../domain/badge_progress.dart';
import '../../../core/widgets/fittrack_icons.dart';

class AchievementsData {
  const AchievementsData({
    required this.stats,
    required this.earnedIds,
    this.earnedAt = const {},
  });
  final Map<String, dynamic> stats;
  final Set<String> earnedIds;

  /// When each recorded badge was earned, keyed by badge id.
  final Map<String, DateTime> earnedAt;
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
    earnedAt: {
      for (final b in badges)
        if (DateTime.tryParse('${b['earned_at']}') != null)
          '${b['badge_id']}': DateTime.parse('${b['earned_at']}').toLocal(),
    },
  );
});

FitTrackTier _tierOf(String tier) => switch (tier) {
      'silver' => FitTrackTier.silver,
      'gold' => FitTrackTier.gold,
      'elite' => FitTrackTier.elite,
      'legend' => FitTrackTier.legend,
      _ => FitTrackTier.bronze,
    };

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final data = ref.watch(achievementsProvider);
    final value = data.valueOrNull;
    String? subtitle;
    if (value != null) {
      final earned = badgeDefinitions
          .where((b) => isBadgeEarned(b, value.stats, value.earnedIds))
          .length;
      subtitle = context.t(
        'profile:badgesEarnedCount',
        args: {'earned': earned, 'total': badgeDefinitions.length},
      );
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            FitTrackTopBar(
              title: context.t('profile:badgesTitle'),
              subtitle: subtitle,
              backLabel: context.t('settings:backLabel'),
              onBack: () => context.pop(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: c.accent,
                backgroundColor: c.surface,
                onRefresh: () async {
                  ref.invalidate(achievementsProvider);
                  await ref.read(achievementsProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    data.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: c.accent),
                        ),
                      ),
                      error: (_, __) => _Message(
                        text: context.t('profile:loadAchievementsFailed'),
                        action: context.t('profile:badgesRetry'),
                        onAction: () => ref.invalidate(achievementsProvider),
                      ),
                      data: (v) => v == null
                          ? _Message(
                              text: context.t('profile:signInAchievements'),
                            )
                          : _Body(
                              data: v,
                              tab: _tab,
                              onTab: (i) => setState(() => _tab = i),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.tab, required this.onTab});
  final AchievementsData data;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final stats = data.stats;
    final xp = (stats['total_xp'] as num?)?.toInt() ?? 0;
    final level = (stats['level'] as num?)?.toInt() ?? 1;
    final tier = '${stats['rank_tier'] ?? 'bronze'}';
    final progress = levelProgress(xp);
    final earned = {
      for (final b in badgeDefinitions)
        if (isBadgeEarned(b, stats, data.earnedIds)) b.id,
    };
    final visible = [
      for (final b in badgeDefinitions)
        if (tab == 0 ||
            (tab == 1 && earned.contains(b.id)) ||
            (tab == 2 && !earned.contains(b.id)))
          b,
    ];
    final categories = <String>[];
    for (final b in visible) {
      if (!categories.contains(b.category)) {
        categories.add(b.category);
      }
    }
    int n(String key) => (stats[key] as num?)?.toInt() ?? 0;

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: FitTrackText.titleLg.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.lg,
        FitTrackSpacing.md,
        FitTrackSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FitTrackCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t(
                          'profile:levelProgress',
                          args: {'level': level},
                        ),
                        style: FitTrackText.stat.copyWith(color: c.ink),
                      ),
                    ),
                    FitTrackRankBadge(
                      tier: _tierOf(tier),
                      label: context.t('progress:tier_$tier'),
                    ),
                  ],
                ),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackProgressBar(
                  progress: progress.fill,
                  color: c.xpColor,
                  semanticLabel: context.t(
                    'profile:levelProgress',
                    args: {'level': level},
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'profile:xpToNext',
                    args: {
                      'xp': xp,
                      'next': progress.toNext,
                      'level': level + 1,
                    },
                  ),
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
                const SizedBox(height: FitTrackSpacing.lg),
                Row(
                  children: [
                    stat(
                      context.t('profile:statWorkouts'),
                      '${n('total_workouts')}',
                    ),
                    stat(context.t('profile:statPrs'), '${n('total_prs')}'),
                    stat(
                      context.t('profile:statStreak'),
                      context.t(
                        'profile:daysShort',
                        args: {'n': n('current_streak')},
                      ),
                    ),
                    stat(
                      context.t('profile:statBest'),
                      context.t(
                        'profile:daysShort',
                        args: {'n': n('longest_streak')},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackButton(
            label: context.t('profile:monthlyLeaderboard'),
            icon: FitIcons.leaderboard,
            variant: FitTrackButtonVariant.secondary,
            fullWidth: true,
            onPressed: () => context.push('/leaderboard'),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackSegmentedTabs(
            labels: [
              context.t('profile:tabAll'),
              context.t('profile:tabEarned'),
              context.t('profile:tabLocked'),
            ],
            selectedIndex: tab,
            onSelected: onTab,
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: FitTrackSpacing.lg),
              child: FitTrackCard(
                padding: const EdgeInsets.all(FitTrackSpacing.xl),
                child: Text(
                  context.t(
                    tab == 1 ? 'profile:noEarned' : 'profile:allEarned',
                  ),
                  textAlign: TextAlign.center,
                  style: FitTrackText.body.copyWith(color: c.muted),
                ),
              ),
            ),
          for (final category in categories) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: FitTrackSpacing.lg,
                bottom: FitTrackSpacing.sm,
                left: 2,
              ),
              child: Text(
                context.t('profile:cat_$category').toUpperCase(),
                style: FitTrackText.caption.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _BadgeGrid(
              badges: [
                for (final b in visible)
                  if (b.category == category) b,
              ],
              stats: stats,
              earned: earned,
              earnedAt: data.earnedAt,
            ),
          ],
        ],
      ),
    );
  }
}

/// Two badge cards per row, each row as tall as its taller card.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({
    required this.badges,
    required this.stats,
    required this.earned,
    required this.earnedAt,
  });
  final List<BadgeDefinition> badges;
  final Map<String, dynamic> stats;
  final Set<String> earned;
  final Map<String, DateTime> earnedAt;

  @override
  Widget build(BuildContext context) {
    Widget tile(BadgeDefinition b) => _BadgeTile(
          badge: b,
          stats: stats,
          earned: earned.contains(b.id),
          earnedAt: earnedAt[b.id],
        );
    return Column(
      children: [
        for (var i = 0; i < badges.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(badges[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < badges.length
                      ? tile(badges[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.stats,
    required this.earned,
    required this.earnedAt,
  });
  final BadgeDefinition badge;
  final Map<String, dynamic> stats;
  final bool earned;
  final DateTime? earnedAt;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final progress = badgeProgress(badge, stats);
    final value = badgeStatValue(badge, stats);
    final caption = earned
        ? (earnedAt == null
            ? context.t('profile:tabEarned')
            : context.t(
                'profile:earnedOn',
                args: {'date': DateFormat('d MMM').format(earnedAt!)},
              ))
        : (value != null && badge.requirementValue > 0
            ? context.t(
                'profile:progressOf',
                args: {
                  'value': value.round(),
                  'target': badge.requirementValue.round(),
                },
              )
            : null);
    return Semantics(
      container: true,
      label: [
        badge.name,
        badge.description,
        if (!earned) context.t('profile:lockedLabel'),
        if (caption != null) caption,
        context.t('profile:xpReward', args: {'n': badge.xpReward}),
      ].join(', '),
      child: ExcludeSemantics(
        child: FitTrackCard(
          padding: const EdgeInsets.all(FitTrackSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: earned
                          ? c.xpColor.withValues(alpha: .18)
                          : c.line,
                      borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: earned ? 1 : .45,
                      child: Text(
                        badge.emoji,
                        style: FitTrackText.emoji,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!earned) ...[
                    Icon(FitIcons.lock, size: 14, color: c.muted),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    context.t('profile:xpReward', args: {'n': badge.xpReward}),
                    style: FitTrackText.caption.copyWith(
                      color: c.xpColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitTrackSpacing.sm),
              Text(
                badge.name,
                style: FitTrackText.title.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                badge.description,
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
              if (caption != null) ...[
                const SizedBox(height: 6),
                Text(
                  caption,
                  style: FitTrackText.caption.copyWith(
                    color: earned ? c.ink : c.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!earned && progress > 0) ...[
                const SizedBox(height: 6),
                FitTrackProgressBar(progress: progress, color: c.muted),
              ],
            ],
          ),
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
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.lg,
        FitTrackSpacing.xl,
        FitTrackSpacing.lg,
        0,
      ),
      child: FitTrackCard(
        padding: const EdgeInsets.all(FitTrackSpacing.xl),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: FitTrackText.body.copyWith(color: c.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: FitTrackSpacing.md),
              FitTrackButton(
                label: action!,
                icon: FitIcons.refresh,
                variant: FitTrackButtonVariant.secondary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
