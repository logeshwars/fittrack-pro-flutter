import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/data_gateway.dart';
import '../../../core/data/data_providers.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/gamification_service.dart';
import '../domain/badge_progress.dart' show monthlyTotals;

class LeaderboardData {
  const LeaderboardData({required this.entries, required this.myId});
  final List<Json> entries;
  final String? myId;
}

/// Publishes the current user's monthly stats, then loads the board.
final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardData>((ref) async {
  final gamification = ref.watch(gamificationServiceProvider);
  final workouts = ref.watch(workoutServiceProvider);
  final gateway = ref.watch(dataGatewayProvider);
  if (gamification == null) {
    return const LeaderboardData(entries: [], myId: null);
  }
  try {
    final stats = await gamification.stats();
    final history = await workouts?.history(limit: 100) ?? const [];
    final totals = monthlyTotals(
      [for (final w in history) (at: w.startedAt, volumeKg: w.totalVolumeKg)],
      DateTime.now(),
    );
    await gamification.upsertMonthlyStats(
      volumeKg: totals.volumeKg,
      trainingDays: totals.trainingDays,
      streakLength: (stats?['current_streak'] as num?)?.toInt() ?? 0,
      prCount: (stats?['total_prs'] as num?)?.toInt() ?? 0,
    );
  } on Object {
    // Publishing is best effort; still show the board.
  }
  final entries = await gamification.monthlyLeaderboard();
  return LeaderboardData(entries: entries, myId: gateway?.userId);
});

const _tierThresholds = <(String, int)>[
  ('silver', 25),
  ('gold', 45),
  ('elite', 65),
  ('legend', 85),
];

FitTrackTier _tierOf(String tier) => switch (tier) {
      'silver' => FitTrackTier.silver,
      'gold' => FitTrackTier.gold,
      'elite' => FitTrackTier.elite,
      'legend' => FitTrackTier.legend,
      _ => FitTrackTier.bronze,
    };

Color _tierInk(AppPalette c, String tier) => switch (tier) {
      'silver' => c.tierSilver,
      'gold' => c.tierGold,
      'elite' => c.tierElite,
      'legend' => c.tierLegend,
      _ => c.tierBronze,
    };

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final data = ref.watch(leaderboardProvider);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accent,
          onRefresh: () async {
            ref.invalidate(leaderboardProvider);
            await ref.read(leaderboardProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
            children: [
              FitTrackScreenHeader(
                title: context.t('progress:title'),
                subtitle: context.t(
                  days == 1
                      ? 'progress:lbSubtitleOne'
                      : 'progress:lbSubtitle',
                  args: {'days': days},
                ),
                trailing: FitTrackIconButton(
                  icon: Icons.close,
                  semanticLabel: context.t('common:close'),
                  onPressed: () => context.pop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.md,
                  FitTrackSpacing.lg,
                  0,
                ),
                child: FitTrackSegmentedTabs(
                  labels: [
                    context.t('progress:analytics'),
                    context.t('progress:leaderboard'),
                  ],
                  selectedIndex: 1,
                  onSelected: (i) {
                    if (i == 0) context.go('/progress');
                  },
                ),
              ),
              data.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                  child: Column(
                    children: [
                      Text(
                        context.t('progress:lbLoadFailed'),
                        style: FitTrackText.body.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: FitTrackSpacing.md),
                      FitTrackButton(
                        label: context.t('common:retry'),
                        icon: Icons.refresh,
                        variant: FitTrackButtonVariant.secondary,
                        onPressed: () => ref.invalidate(leaderboardProvider),
                      ),
                    ],
                  ),
                ),
                data: (value) {
                  if (value.entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        context.t('progress:noLeaderboard'),
                        textAlign: TextAlign.center,
                        style: FitTrackText.body.copyWith(color: colors.muted),
                      ),
                    );
                  }
                  final me = [
                    for (final e in value.entries)
                      if (e['google_user_id'] == value.myId) e
                  ];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FitTrackSpacing.lg,
                      FitTrackSpacing.md,
                      FitTrackSpacing.lg,
                      0,
                    ),
                    child: Column(
                      children: [
                        if (me.isNotEmpty) ...[
                          _ScoreCard(entry: me.first),
                          const SizedBox(height: FitTrackSpacing.md),
                        ],
                        FitTrackCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(FitTrackRadius.lg - 1),
                            child: Column(
                              children: [
                                const _TableHeader(),
                                for (var i = 0; i < value.entries.length; i++)
                                  _Row(
                                    entry: value.entries[i],
                                    position: i + 1,
                                    isMe: value.entries[i]['google_user_id'] ==
                                        value.myId,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.entry});
  final Json entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final score = (entry['rank_score'] as num?)?.toInt() ?? 0;
    final tier = '${entry['rank_tier'] ?? 'bronze'}';
    final days = (entry['training_days'] as num?)?.toInt() ?? 0;
    final volume = (entry['volume_kg'] as num?)?.toDouble() ?? 0;
    final streak = (entry['streak_length'] as num?)?.toInt() ?? 0;
    final prs = (entry['pr_count'] as num?)?.toInt() ?? 0;
    final parts = rankScoreBreakdown(
      trainingDays: days,
      volumeKg: volume,
      streakLength: streak,
      prCount: prs,
    );
    final next = _tierThresholds.where((t) => t.$2 > score).firstOrNull;
    final prev = _tierThresholds.where((t) => t.$2 <= score).lastOrNull;
    final from = prev?.$2 ?? 0;
    final progress =
        next == null ? 1.0 : (score - from) / (next.$2 - from).toDouble();
    final cells = <(String, double, int)>[
      (context.t('progress:lbConsistency'), parts.consistency, 30),
      (context.t('progress:lbVolume'), parts.volume, 35),
      (context.t('progress:lbStreak'), parts.streak, 20),
      (context.t('progress:lbPrs'), parts.prs, 15),
    ];
    return FitTrackCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('progress:lbYourScore'),
                style: FitTrackText.caption.copyWith(
                  color: colors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              FitTrackRankBadge(
                tier: _tierOf(tier),
                label: context.t('progress:tier_$tier'),
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: FitTrackText.statLg.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.t('progress:lbOutOf'),
                style: FitTrackText.body.copyWith(color: colors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FitTrackProgressBar(
            progress: progress.clamp(0.0, 1.0),
            color: colors.accent,
            semanticLabel: context.t('progress:lbYourScore'),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? context.t('progress:lbTopTier')
                : context.t(
                    'progress:lbToNext',
                    args: {
                      'pts': next.$2 - score,
                      'tier': context.t('progress:tier_${next.$1}'),
                      'score': next.$2,
                    },
                  ),
            style: FitTrackText.caption.copyWith(color: colors.muted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitTrackSpacing.md),
            child: Divider(height: 1, color: colors.line),
          ),
          Row(
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cells[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FitTrackText.caption.copyWith(
                          color: colors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          text: '${cells[i].$2.round()} ',
                          children: [
                            TextSpan(
                              text: '/ ${cells[i].$3}',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                        style: FitTrackText.body.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FitTrackProgressBar(
                        progress: (cells[i].$2 / cells[i].$3).clamp(0.0, 1.0),
                        color: colors.accent,
                        semanticLabel: cells[i].$1,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final style = FitTrackText.overline.copyWith(
      color: colors.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(context.t('progress:lbColRank'), style: style),
          ),
          const SizedBox(width: FitTrackSpacing.sm),
          Expanded(
            child: Text(
              context.t('progress:lbColAthlete').toUpperCase(),
              style: style,
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              context.t('progress:lbColTier').toUpperCase(),
              style: style,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              context.t('progress:lbColPts').toUpperCase(),
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.position, required this.isMe});
  final Json entry;
  final int position;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final profile = entry['profiles'];
    final name = (profile is Map ? profile['display_name'] as String? : null) ??
        context.t('progress:lbUnknown');
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();
    final score = (entry['rank_score'] as num?)?.toInt() ?? 0;
    final tier = '${entry['rank_tier'] ?? 'bronze'}';
    final volume = (entry['volume_kg'] as num?)?.round() ?? 0;
    final days = (entry['training_days'] as num?)?.toInt() ?? 0;
    final tierInk = _tierInk(colors, tier);
    final podium = position <= 3
        ? _tierInk(
            colors,
            switch (position) {
              1 => 'gold',
              2 => 'silver',
              _ => 'bronze',
            },
          )
        : null;
    return Semantics(
      label: '${context.t('progress:lbRankLabel', args: {'n': position})}, '
          '$name, ${context.t('progress:tier_$tier')}, $score',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isMe ? colors.accentTint : null,
            border: Border(top: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$position',
                  style: FitTrackText.body.copyWith(
                    color: podium ?? (isMe ? colors.accent : colors.ink),
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: FitTrackSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.lineStrong,
                      child: Text(
                        initials,
                        style: FitTrackText.overline.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: FitTrackSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FitTrackText.body.copyWith(
                                    color: colors.ink,
                                    fontWeight:
                                        isMe ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.t('progress:lbYou'),
                                    style: FitTrackText.overline.copyWith(
                                      color: colors.accentText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            context.t(
                              'progress:lbRowMeta',
                              args: {
                                'volume':
                                    NumberFormat.decimalPattern().format(volume),
                                'days': days,
                              },
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FitTrackText.overline
                                .copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 76,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tierInk,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        context.t('progress:tier_$tier'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FitTrackText.caption.copyWith(
                          color: tierInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$score',
                  textAlign: TextAlign.end,
                  style: FitTrackText.body.copyWith(
                    color: colors.ink,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
