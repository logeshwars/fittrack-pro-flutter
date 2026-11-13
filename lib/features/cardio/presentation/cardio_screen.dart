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
import '../application/cardio_controller.dart';
import '../data/cardio_service.dart';
import '../domain/cardio_session.dart';
import '../domain/cardio_tracking.dart';

final cardioProvider =
    FutureProvider.autoDispose<List<CardioSession>>((ref) async {
  final service = ref.watch(cardioServiceProvider);
  if (service == null) {
    return const [];
  }
  final rows = await service.history(limit: 30);
  return [for (final r in rows) CardioSession.fromJson(r)];
});

final cardioStatsProvider =
    FutureProvider.autoDispose<CardioStats?>((ref) async {
  final service = ref.watch(cardioServiceProvider);
  return service?.stats();
});

/// Activity types shown in the "Start a session" grid.
class _Activity {
  const _Activity(this.type, this.icon, this.name, this.xp, this.hint);
  final String type;
  final IconData icon;
  final String name;
  final String xp;
  final String hint;
}

const _activities = [
  _Activity('running', Icons.directions_run, 'cardioTypeRunning',
      'cardioXp5km', 'cardioHintRunning'),
  _Activity('cycling', Icons.directions_bike, 'cardioTypeCycling',
      'cardioXpBase', 'cardioHintCycling'),
  _Activity('walking', Icons.directions_walk, 'cardioTypeWalking',
      'cardioXp30min', 'cardioHintWalking'),
  _Activity('swimming', Icons.pool, 'cardioTypeSwimming', 'cardioXpBase',
      'cardioHintSwimming'),
  _Activity('hiit', Icons.timer_outlined, 'cardioTypeHiit', 'cardioXpHiit',
      'cardioHintHiit'),
  _Activity('other', Icons.favorite_outline, 'cardioTypeOther', 'cardioXpBase',
      'cardioHintOther'),
];

String _typeName(BuildContext context, String type) {
  for (final a in _activities) {
    if (a.type == type) return context.t('common:${a.name}');
  }
  return cardioLabels[type] ?? context.t('common:cardioTitle');
}

class CardioScreen extends ConsumerWidget {
  const CardioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final sessions = ref.watch(cardioProvider);

    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.surface,
      onRefresh: () async {
        ref.invalidate(cardioProvider);
        ref.invalidate(cardioStatsProvider);
        await ref.read(cardioProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: FitTrackSpacing.tabBarClearance - 60,
        ),
        children: [
          FitTrackScreenHeader(
            title: context.t('common:cardioTitle'),
            subtitle: context.t('common:cardioSubtitle'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitTrackSpacing.lg,
              FitTrackSpacing.md,
              FitTrackSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ResumeBanner(),
                _StatsStrip(stats: ref.watch(cardioStatsProvider).valueOrNull),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('common:cardioXpTitle'),
                        style: FitTrackText.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('common:cardioXpRules'),
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FitTrackSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(
                    context.t('common:cardioStartSession'),
                    style: FitTrackText.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .62,
                  children: [
                    for (final a in _activities) _ActivityTile(activity: a),
                  ],
                ),
                const SizedBox(height: FitTrackSpacing.md),
                sessions.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: c.accent),
                    ),
                  ),
                  error: (_, __) =>
                      _Info(text: context.t('common:cardioLoadFailed')),
                  data: (items) {
                    if (items.isEmpty) {
                      return _Info(
                        text:
                            '${context.t('common:noCardioYet')}. ${context.t('common:startFirstCardio')}',
                      );
                    }
                    return FitTrackCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SizedBox(
                            height: FitTrackSpacing.touchMin,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.t('common:cardioRecent'),
                                    style: FitTrackText.body.copyWith(
                                      color: c.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${items.length}',
                                    style: FitTrackText.caption
                                        .copyWith(color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (final item in items)
                            Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                padding: const EdgeInsets.only(right: 20),
                                alignment: Alignment.centerRight,
                                color: c.bad,
                                child: Icon(Icons.delete_outline, color: c.bg),
                              ),
                              onDismissed: (_) async {
                                await ref
                                    .read(cardioServiceProvider)
                                    ?.deleteSession(item.id);
                                ref.invalidate(cardioProvider);
                                ref.invalidate(cardioStatsProvider);
                              },
                              child: _SessionRow(session: item),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final name = context.t('common:${activity.name}');
    return Semantics(
      button: true,
      label: '$name, ${context.t('common:${activity.xp}')}',
      child: ExcludeSemantics(
        child: FitTrackCard(
          padding: const EdgeInsets.all(12),
          onTap: () => context.push('/cardio/session?type=${activity.type}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.cardioColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                ),
                child: Icon(activity.icon, size: 18, color: c.cardioColor),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: FitTrackText.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('common:${activity.xp}'),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
              const SizedBox(height: 2),
              Text(
                context.t('common:${activity.hint}'),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final CardioSession session;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final mins = (session.durationSeconds ?? 0) ~/ 60;
    final parts = <String>[
      DateFormat('EEE d MMM · h:mm a').format(session.startedAt.toLocal()),
      context.t('common:cardioMinutes', args: {'minutes': mins}),
      if (session.caloriesBurned != null)
        context.t('common:cardioKcal', args: {'kcal': session.caloriesBurned}),
    ];
    return Material(
      color: c.surface,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration:
            BoxDecoration(border: Border(top: BorderSide(color: c.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name ?? _typeName(context, session.type),
                    style: FitTrackText.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            if (session.distanceKm != null)
              Text.rich(
                TextSpan(
                  text: session.distanceKm!.toStringAsFixed(1),
                  style: FitTrackText.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: ' ${context.t('common:cardioKm')}',
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.directions_run, size: 40, color: c.muted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: FitTrackText.body.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _ResumeBanner extends ConsumerStatefulWidget {
  const _ResumeBanner();

  @override
  ConsumerState<_ResumeBanner> createState() => _ResumeBannerState();
}

class _ResumeBannerState extends ConsumerState<_ResumeBanner> {
  @override
  void initState() {
    super.initState();
    // Restore a session that was running when the app was closed.
    Future<void>(() => ref.read(cardioControllerProvider.notifier).restore())
        .catchError((Object _) => false);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(cardioControllerProvider);
    if (active == null) {
      return const SizedBox.shrink();
    }
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FitTrackSpacing.md),
      child: Material(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(FitTrackRadius.lg),
        child: InkWell(
          onTap: () => context.push('/cardio/session?type=${active.type}'),
          borderRadius: BorderRadius.circular(FitTrackRadius.lg),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: FitTrackSpacing.touchMin),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FitTrackRadius.lg),
              border: Border.all(color: c.accent),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: c.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t(
                      'common:cardioInProgress',
                      args: {'type': _typeName(context, active.type)},
                    ),
                    style: FitTrackText.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward, size: 16, color: c.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});
  final CardioStats? stats;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final s = stats;
    Widget cell(String label, String value, {String? unit}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: FitTrackText.stat.copyWith(color: c.ink),
                    children: [
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t('common:cardioLast30'),
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        );
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            cell(
              context.t('common:cardioStatSessions'),
              s == null ? '—' : '${s.totalSessions}',
            ),
            VerticalDivider(width: 1, thickness: 1, color: c.line),
            cell(
              context.t('common:cardioStatDistance'),
              s == null ? '—' : s.totalDistanceKm.toStringAsFixed(1),
              unit: context.t('common:cardioKm'),
            ),
            VerticalDivider(width: 1, thickness: 1, color: c.line),
            cell(
              context.t('common:cardioStatMinutes'),
              s == null ? '—' : '${s.totalMinutes}',
            ),
          ],
        ),
      ),
    );
  }
}
