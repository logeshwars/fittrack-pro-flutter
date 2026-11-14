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
import '../../../core/widgets/fittrack_icons.dart';

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
  _Activity('running', FitIcons.run, 'cardioTypeRunning',
      'cardioXp5km', 'cardioHintRunning'),
  _Activity('cycling', FitIcons.cycle, 'cardioTypeCycling',
      'cardioXpBase', 'cardioHintCycling'),
  _Activity('walking', FitIcons.walk, 'cardioTypeWalking',
      'cardioXp30min', 'cardioHintWalking'),
  _Activity('swimming', FitIcons.swim, 'cardioTypeSwimming', 'cardioXpBase',
      'cardioHintSwimming'),
  _Activity('hiit', FitIcons.hiit, 'cardioTypeHiit', 'cardioXpHiit',
      'cardioHintHiit'),
  _Activity('other', FitIcons.otherActivity, 'cardioTypeOther', 'cardioXpBase',
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

    return Column(
      children: [
        FitTrackScreenHeader(
          title: context.t('common:cardioTitle'),
          subtitle: context.t('common:cardioSubtitle'),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.accent,
            backgroundColor: c.surface,
            onRefresh: () async {
              ref.invalidate(cardioProvider);
              ref.invalidate(cardioStatsProvider);
              await ref.read(cardioProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.gutter,
                FitTrackSpacing.gap,
                FitTrackSpacing.gutter,
                FitTrackSpacing.xxl,
              ),
              children: [
                const _ResumeBanner(),
                _StatsStrip(stats: ref.watch(cardioStatsProvider).valueOrNull),
                const SizedBox(height: FitTrackSpacing.gap),
                FitTrackCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('common:cardioXpTitle'),
                        style: FitTrackText.rowTitle.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: FitTrackSpacing.xs),
                      Text(
                        context.t('common:cardioXpRules'),
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FitTrackSpacing.gap),
                FitTrackSectionLabel(
                  title: context.t('common:cardioStartSession'),
                ),
                FitTrackGrid(
                  columns: 3,
                  children: [
                    for (final a in _activities) _ActivityTile(activity: a),
                  ],
                ),
                const SizedBox(height: FitTrackSpacing.gap),
                sessions.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.all(FitTrackSpacing.xxl),
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
                    return FitTrackListCard(
                      title: context.t('common:cardioRecent'),
                      trailing: '${items.length}',
                      children: [
                        for (final item in items)
                          Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              padding: const EdgeInsetsDirectional.only(
                                end: FitTrackSpacing.xl,
                              ),
                              alignment: AlignmentDirectional.centerEnd,
                              color: c.bad,
                              child: Icon(FitIcons.delete, color: c.bg),
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.all(FitTrackSpacing.md),
          onTap: () => context.push('/cardio/session?type=${activity.type}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FitTrackIconTile(icon: activity.icon, color: c.cardioColor),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FitTrackText.rowTitle.copyWith(color: c.ink),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('common:${activity.xp}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
    return ColoredBox(
      color: c.surface,
      child: FitTrackRow(
        minHeight: 56,
        title: session.name ?? _typeName(context, session.type),
        subtitle: parts.join(' · '),
        trailing: session.distanceKm == null
            ? null
            : FitTrackValue(
                value: session.distanceKm!.toStringAsFixed(1),
                unit: context.t('common:cardioKm'),
                style: FitTrackText.rowTitle,
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          FitTrackIconTile(icon: FitIcons.run, color: c.cardioColor, size: 44),
          const SizedBox(height: FitTrackSpacing.md),
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
        borderRadius: BorderRadius.circular(FitTrackRadius.card),
        child: InkWell(
          onTap: () => context.push('/cardio/session?type=${active.type}'),
          borderRadius: BorderRadius.circular(FitTrackRadius.card),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: FitTrackSpacing.touchMin),
            padding: const EdgeInsets.all(FitTrackSpacing.cardPad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FitTrackRadius.card),
              border: Border.all(color: c.accent),
            ),
            child: Row(
              children: [
                Icon(FitIcons.timer, size: 20, color: c.accent),
                const SizedBox(width: FitTrackSpacing.md),
                Expanded(
                  child: Text(
                    context.t(
                      'common:cardioInProgress',
                      args: {'type': _typeName(context, active.type)},
                    ),
                    style: FitTrackText.rowTitle.copyWith(color: c.ink),
                  ),
                ),
                Icon(FitIcons.chevronRight, size: 16, color: c.chevron),
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
    final s = stats;
    final period = context.t('common:cardioLast30');
    return FitTrackStatStrip(
      stats: [
        FitTrackStat(
          label: context.t('common:cardioStatSessions'),
          value: s == null ? '–' : '${s.totalSessions}',
          caption: period,
        ),
        FitTrackStat(
          label: context.t('common:cardioStatDistance'),
          value: s == null ? '–' : s.totalDistanceKm.toStringAsFixed(1),
          unit: context.t('common:cardioKm'),
          caption: period,
        ),
        FitTrackStat(
          label: context.t('common:cardioStatMinutes'),
          value: s == null ? '–' : '${s.totalMinutes}',
          caption: period,
        ),
      ],
    );
  }
}
