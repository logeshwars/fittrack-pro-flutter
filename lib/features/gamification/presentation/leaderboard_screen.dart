import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/data_gateway.dart';
import '../../../core/data/data_providers.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../domain/badge_progress.dart';
import '../../../core/l10n/language_controller.dart';

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

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final data = ref.watch(leaderboardProvider);
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
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              FitTrackScreenHeader(
                title: context.t('progress:leaderboard'),
                subtitle: 'This month, ranked by score',
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
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('Unable to load the leaderboard.',
                          style: TextStyle(color: colors.muted)),
                      TextButton(
                        onPressed: () => ref.invalidate(leaderboardProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (value) => value.entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.t('progress:noLeaderboard'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.muted),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          children: [
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
        ),
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
        'Unknown';
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
    final podium = switch (position) {
      1 => tierColor('gold'),
      2 => tierColor('silver'),
      3 => tierColor('bronze'),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isMe ? colors.accentTint : colors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
                width: 3,
                color: podium ?? (isMe ? colors.accent : colors.border2)),
            SizedBox(
              width: 38,
              child: Center(
                child: Text(
                  position.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: podium ?? colors.muted,
                  ),
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.border2,
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.text)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '$name (you)' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: colors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$volume kg · $days days · ${tierLabel(tier)}',
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '$score',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: tierColor(tier)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
