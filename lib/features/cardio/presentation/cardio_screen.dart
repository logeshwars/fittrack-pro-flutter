import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/cardio_repository.dart';
import '../domain/cardio_session.dart';

final cardioProvider = FutureProvider.autoDispose<List<CardioSession>>((ref) async {
  if (!AppConfig.hasSupabase) return [];
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  return user == null ? [] : CardioRepository(client).recent(authenticatedUserId: user.id);
});

class CardioScreen extends ConsumerWidget {
  const CardioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final sessions = ref.watch(cardioProvider);

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: () async {
        ref.invalidate(cardioProvider);
        await ref.read(cardioProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 44),
        children: [
          const FitTrackScreenHeader(
            title: 'Cardio',
            subtitle: 'Track duration, distance and effort',
            icon: Icons.directions_run,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: FitTrackSectionLabel(title: 'Start an Activity'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .88,
              children: const [
                _ActivityTile(label: 'Running', hint: 'Road · Treadmill', icon: Icons.directions_run, accent: AppColors.cardio),
                _ActivityTile(label: 'Cycling', hint: 'Indoor · Outdoor', icon: Icons.directions_bike, accent: Color(0xFF4CAF50)),
                _ActivityTile(label: 'Walking', hint: 'Walk · Hike', icon: Icons.directions_walk, accent: Color(0xFF2196F3)),
                _ActivityTile(label: 'HIIT', hint: 'Intervals', icon: Icons.timer_outlined, accent: Color(0xFF9C27B0)),
                _ActivityTile(label: 'Swimming', hint: 'Pool · Open water', icon: Icons.pool, accent: Color(0xFF00BCD4)),
                _ActivityTile(label: 'Other', hint: 'Custom cardio', icon: Icons.favorite_outline, accent: Color(0xFF607D8B)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: FitTrackSectionLabel(
              title: 'Recent Sessions',
              action: sessions.valueOrNull == null ? null : '${sessions.valueOrNull!.length}',
              onAction: sessions.valueOrNull == null ? null : () {},
            ),
          ),
          sessions.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: colors.accent)),
            ),
            error: (_, __) => const _Info(text: 'Unable to load cardio sessions.'),
            data: (items) {
              if (items.isEmpty) {
                return const _Info(
                  text: 'No cardio yet. Start your first session above.',
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: items.map((item) => _SessionCard(session: item)).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String hint;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/cardio/draft'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 8, color: colors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final CardioSession session;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final mins = (session.durationSeconds ?? 0) ~/ 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 3, height: 76, color: AppColors.cardio),
          Container(
            width: 52,
            height: 76,
            color: AppColors.cardio.withValues(alpha: .05),
            alignment: Alignment.center,
            child: const Icon(
              Icons.directions_run,
              color: AppColors.cardio,
              size: 22,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name ?? session.type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('EEE · MMM d · h:mm a').format(session.startedAt.toLocal()),
                    style: TextStyle(fontSize: 10, color: colors.muted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    children: [
                      Text(
                        '$mins min',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.subtext,
                        ),
                      ),
                      if (session.distanceKm != null)
                        Text(
                          '${session.distanceKm!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.subtext,
                          ),
                        ),
                      if (session.caloriesBurned != null)
                        Text(
                          '${session.caloriesBurned} kcal',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cardio,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_run, size: 48, color: colors.border2),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
        ],
      ),
    );
  }
}
