import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../gamification/data/badges_data.dart';
import '../../gamification/domain/badge_definition.dart';
import '../../gamification/presentation/gamification_screen.dart';
import '../../gamification/presentation/leaderboard_screen.dart';
import '../../subscription/application/subscription_controller.dart';
import '../../../core/widgets/fittrack_icons.dart';

const _knownTiers = {'bronze', 'silver', 'gold', 'elite', 'legend'};

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _ProfileTopBar(
              onBack: () => context.pop(),
              onSettings: () => context.push('/settings'),
            ),
            Expanded(
              child: dashboard.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (_, __) => _ProfileError(
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
                data: (data) => _ProfileBody(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.onBack, required this.onSettings});
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackTopBar(
      title: context.t('profile:title'),
      backLabel: context.t('settings:backLabel'),
      onBack: onBack,
      trailing: FitTrackIconButton(
        icon: FitIcons.settings,
        color: c.ink,
        semanticLabel: context.t('profile:settingsLabel'),
        onPressed: onSettings,
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);
    final achievements = achievementsAsync.valueOrNull;
    final board = ref.watch(leaderboardProvider).valueOrNull;
    final sub = ref.watch(subscriptionProvider);
    final stats = achievements?.stats;
    final number = NumberFormat.decimalPattern();

    // This month's board entry is the freshest tier; the stored tier is the
    // fallback when the board is empty or unavailable.
    final mine = board == null
        ? null
        : board.entries
            .where((e) => e['google_user_id'] == board.myId)
            .firstOrNull;
    final rank =
        board == null || mine == null ? null : board.entries.indexOf(mine) + 1;
    final tier = '${mine?['rank_tier'] ?? stats?['rank_tier'] ?? ''}'
        .toLowerCase();

    final earnedIds = achievements?.earnedIds ?? const <String>{};
    final earnedAt = achievements?.earnedAt ?? const <String, DateTime>{};
    final earned = [
      for (final b in badgeDefinitions)
        if (earnedIds.contains(b.id)) b,
    ]..sort((a, b) => (earnedAt[b.id] ?? DateTime(0))
        .compareTo(earnedAt[a.id] ?? DateTime(0)));

    String count(String key) =>
        stats == null ? '—' : '${(stats[key] as num?)?.toInt() ?? 0}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.gutter,
        FitTrackSpacing.gap,
        FitTrackSpacing.gutter,
        FitTrackSpacing.xxl,
      ),
      children: [
        _IdentityCard(
          name: data.displayName,
          tier: _knownTiers.contains(tier) ? tier : null,
          rank: rank,
          level: data.level,
          totalXp: data.totalXp,
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackStatStrip(
          stats: [
            FitTrackStat(
              label: context.t('profile:statWorkouts'),
              value: count('total_workouts'),
            ),
            FitTrackStat(
              label: context.t('profile:statStreak'),
              value: '${data.currentStreak}',
              unit: context.t('profile:dayUnit'),
            ),
            FitTrackStat(
              label: context.t('profile:statPrs'),
              value: count('total_prs'),
            ),
          ],
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackStatStrip(
          stats: [
            FitTrackStat(
              label: context.t('profile:totalXP'),
              value: number.format(data.totalXp),
            ),
            FitTrackStat(
              label: context.t('profile:bodyKg'),
              value: data.latestWeightKg == null
                  ? '–'
                  : data.latestWeightKg!.toStringAsFixed(1),
              unit: data.latestWeightKg == null
                  ? null
                  : context.t('profile:kgUnit'),
            ),
          ],
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        _BadgesCard(
          earned: earned.take(4).toList(),
          earnedCount: earned.length,
          total: badgeDefinitions.length,
          loaded: achievements != null,
          loading: achievementsAsync.isLoading,
          onSeeAll: () => context.push('/achievements'),
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ListRow(
                title: context.t('profile:proName'),
                subtitle: sub.isTrial
                    ? context.t(
                        'profile:proTrial',
                        args: {'days': sub.trialDaysLeft(DateTime.now())},
                      )
                    : sub.isPro
                        ? context.t('profile:proActive')
                        : context.t('profile:proFree'),
                trailingText: sub.isPro
                    ? context.t('profile:manageLabel')
                    : context.t('profile:proUpgrade'),
                first: true,
                onTap: () => context.push('/subscription'),
              ),
            ],
          ),
        ),
        const SizedBox(height: FitTrackSpacing.xl),
        FitTrackSectionLabel(title: context.t('profile:settings')),
        FitTrackCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ListRow(
                icon: FitIcons.health,
                title: context.t('profile:personalSettings'),
                first: true,
                onTap: () => context.push('/settings/personal'),
              ),
              _ListRow(
                icon: FitIcons.bell,
                title: context.t('profile:supplementAlerts'),
                onTap: () => context.push('/settings/alerts'),
              ),
              _ListRow(
                icon: FitIcons.calories,
                title: context.t('profile:dailyGoals'),
                onTap: () => context.push('/settings/goals'),
              ),
              _ListRow(
                icon: FitIcons.palette,
                title: context.t('profile:appearance'),
                onTap: () => context.push('/settings/theme'),
              ),
              _ListRow(
                icon: FitIcons.settings,
                title: context.t('profile:appSettings'),
                onTap: () => context.push('/settings/app-settings'),
              ),
              _ListRow(
                icon: FitIcons.trophy,
                title: context.t('profile:achievementsRow'),
                onTap: () => context.push('/achievements'),
              ),
            ],
          ),
        ),
        const SizedBox(height: FitTrackSpacing.xl),
        FitTrackButton(
          label: context.t('profile:signOut'),
          variant: FitTrackButtonVariant.secondary,
          size: FitTrackButtonSize.lg,
          fullWidth: true,
          onPressed: () async {
            final auth = ref.read(authRepositoryProvider);
            if (auth != null) {
              await auth.signOut();
              if (context.mounted) context.go('/account');
            }
          },
        ),
      ],
    );
  }
}

Color _tierInk(AppPalette c, String tier) => switch (tier) {
      'silver' => c.tierSilver,
      'gold' => c.tierGold,
      'elite' => c.tierElite,
      'legend' => c.tierLegend,
      _ => c.tierBronze,
    };

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.tier,
    required this.rank,
    required this.level,
    required this.totalXp,
  });

  final String name;
  final String? tier;
  final int? rank;
  final int level;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? 'U' : trimmed.characters.first.toUpperCase();
    final base = (level - 1) * 500;
    final cap = level * 500;
    final progress = ((totalXp - base) / 500).clamp(0, 1).toDouble();
    final number = NumberFormat.decimalPattern();
    final tierName = tier == null ? null : context.t('progress:tier_$tier');
    final tierLine = tierName == null
        ? null
        : rank == null
            ? tierName
            : context.t(
                'profile:tierRank',
                args: {'tier': tierName, 'rank': rank!},
              );

    return FitTrackCard(
      padding: const EdgeInsets.all(FitTrackSpacing.lg - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.accentTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: FitTrackText.stat.copyWith(
                      color: c.accentText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: FitTrackSpacing.lg - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.titleLg.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tierLine != null) ...[
                      const SizedBox(height: FitTrackSpacing.xs),
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _tierInk(c, tier!),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tierLine,
                              style: FitTrackText.caption.copyWith(
                                color: _tierInk(c, tier!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.lg - 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  context.t('profile:levelProgress', args: {'level': level}),
                  style: FitTrackText.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                context.t(
                  'profile:xpProgress',
                  args: {
                    'current': number.format(totalXp),
                    'max': number.format(cap),
                  },
                ),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.sm),
          FitTrackProgressBar(
            progress: progress,
            semanticLabel: context.t(
              'profile:levelProgress',
              args: {'level': level},
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of stat cells sharing one bordered surface, split by 1px lines.
class _BadgesCard extends StatelessWidget {
  const _BadgesCard({
    required this.earned,
    required this.earnedCount,
    required this.total,
    required this.loaded,
    required this.loading,
    required this.onSeeAll,
  });

  final List<BadgeDefinition> earned;
  final int earnedCount;
  final int total;
  final bool loaded;
  final bool loading;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: const EdgeInsets.all(FitTrackSpacing.lg - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t(
                    'profile:badgesSummary',
                    args: {'earned': earnedCount, 'total': total},
                  ),
                  style: FitTrackText.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    FitTrackSpacing.touchMin,
                    FitTrackSpacing.touchMin,
                  ),
                  foregroundColor: c.accentText,
                ),
                child: Text(
                  context.t('profile:seeAll'),
                  style: FitTrackText.label.copyWith(color: c.accentText),
                ),
              ),
            ],
          ),
          if (earned.isEmpty && loading)
            const SizedBox(height: FitTrackSpacing.sm)
          else if (earned.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: FitTrackSpacing.xs),
              child: Text(
                loaded
                    ? context.t('profile:noEarned')
                    : context.t('profile:loadAchievementsFailed'),
                style: FitTrackText.caption.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: FitTrackSpacing.sm),
                  Expanded(
                    child: i < earned.length
                        ? _BadgeGlyph(badge: earned[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BadgeGlyph extends StatelessWidget {
  const _BadgeGlyph({required this.badge});

  final BadgeDefinition badge;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      container: true,
      label: badge.name,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.xpColor.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(FitTrackRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(badge.emoji, style: FitTrackText.titleLg),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: FitTrackText.caption.copyWith(
                color: c.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailingText,
    this.first = false,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final String? subtitle;
  final String? trailingText;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      label: [title, if (subtitle != null) subtitle!].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.lg - 2,
            ),
            decoration: BoxDecoration(
              border: first ? null : Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: c.muted),
                  const SizedBox(width: FitTrackSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: FitTrackText.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: FitTrackText.caption.copyWith(
                            color: c.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null)
                  Text(
                    trailingText!,
                    style: FitTrackText.label.copyWith(color: c.accentText),
                  )
                else
                  Icon(FitIcons.chevronRight, size: 16, color: c.chevron),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FitTrackSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('profile:loadProfileFailed'),
              textAlign: TextAlign.center,
              style: FitTrackText.body.copyWith(color: c.muted),
            ),
            const SizedBox(height: FitTrackSpacing.lg),
            FitTrackButton(
              label: context.t('common:retry'),
              variant: FitTrackButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
