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
import '../../progress/domain/progress_models.dart';
import '../../settings/data/goal_targets.dart';
import '../../../core/widgets/fittrack_icons.dart';

final sleepHistoryProvider =
    FutureProvider.autoDispose<List<SleepLog>>((ref) async {
  final service = ref.watch(sleepServiceProvider);
  if (service == null) {
    return const [];
  }
  final rows = await service.history(limit: 60);
  return [for (final r in rows) SleepLog.fromJson(r)];
});

String _duration(BuildContext context, int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0
      ? context.t('common:slHours', args: {'h': h})
      : context.t('common:slHoursMinutes', args: {'h': h, 'm': m});
}

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final sleep = ref.watch(sleepHistoryProvider);
    final goalMinutes =
        ref.watch(goalTargetsProvider).valueOrNull?.sleepMinutes.round();

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
          children: [
            FitTrackTopBar(
              title: context.t('common:slTitle'),
              backLabel: context.t('settings:backLabel'),
              onBack: () => context.pop(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: colors.accent,
                backgroundColor: colors.surface,
                onRefresh: () async {
                  ref.invalidate(sleepHistoryProvider);
                  await ref.read(sleepHistoryProvider.future);
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
                    sleep.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: colors.accent),
                        ),
                      ),
                      error: (_, __) => _Message(
                        title: context.t('common:slLoadFailed'),
                        actionLabel: context.t('common:retry'),
                        onAction: () => ref.invalidate(sleepHistoryProvider),
                      ),
                      data: (items) => _Content(
                        items: items,
                        goalMinutes: goalMinutes,
                        onDelete: (item) async {
                          await ref
                              .read(sleepServiceProvider)
                              ?.deleteLog(item.id);
                          ref.invalidate(sleepHistoryProvider);
                        },
                      ),
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

class _Content extends StatelessWidget {
  const _Content({
    required this.items,
    required this.goalMinutes,
    required this.onDelete,
  });
  final List<SleepLog> items;
  final int? goalMinutes;
  final ValueChanged<SleepLog> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    if (items.isEmpty) {
      return _Message(
        title: context.t('common:slEmptyTitle'),
        subtitle: context.t('common:slEmptySub'),
        actionLabel: context.t('common:slLogCta'),
        onAction: () => context.push('/sleep/log'),
      );
    }

    final latest = items.first;
    final avgMinutes =
        (items.fold<int>(0, (sum, item) => sum + item.durationMinutes) /
                items.length)
            .round();
    final qualityValues = [
      for (final item in items)
        if (item.quality != null) item.quality!,
    ];
    final avgQuality = qualityValues.isEmpty
        ? null
        : qualityValues.reduce((a, b) => a + b) / qualityValues.length;
    final time = DateFormat('h:mm a');
    final times = context.t(
      'common:slTimes',
      args: {
        'bed': time.format(latest.bedtime.toLocal()),
        'wake': time.format(latest.wakeTime.toLocal()),
      },
    );
    final goal = goalMinutes;
    final progress = goal == null || goal <= 0
        ? 0.0
        : (latest.durationMinutes / goal).clamp(0, 1).toDouble();
    final week = items.take(7).toList().reversed.toList();
    final weekAvg =
        (week.fold<int>(0, (s, i) => s + i.durationMinutes) / week.length)
            .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitTrackCard(
          child: Semantics(
            container: true,
            label: [
              context.t('common:slLastNight'),
              _duration(context, latest.durationMinutes),
              times,
              if (goal != null)
                context.t(
                  'common:slGoal',
                  args: {'goal': _duration(context, goal)},
                ),
            ].join(', '),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('common:slLastNight'),
                    style: FitTrackText.caption.copyWith(
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xs),
                  Text(
                    _duration(context, latest.durationMinutes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitTrackText.statLg.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal == null
                        ? times
                        : '$times · ${context.t('common:slGoal', args: {
                                  'goal': _duration(context, goal)
                                })}',
                    style: FitTrackText.caption.copyWith(
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (goal != null) ...[
                    const SizedBox(height: 10),
                    FitTrackProgressBar(
                      progress: progress,
                      color: c.sleepColor,
                    ),
                  ],
                  if (latest.quality != null) ...[
                    const SizedBox(height: FitTrackSpacing.sm),
                    Text(
                      context.t(
                        'common:slQualityOf',
                        args: {'n': latest.quality!},
                      ),
                      style: FitTrackText.caption.copyWith(
                        color: c.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        _WeekChart(nights: week, average: weekAvg, goalMinutes: goal),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackStatStrip(
          stats: [
            FitTrackStat(
              label: context.t('common:slAvgSleep'),
              value: _duration(context, avgMinutes),
            ),
            FitTrackStat(
              label: context.t('common:slNights'),
              value: '${items.length}',
            ),
            FitTrackStat(
              label: context.t('common:slQuality'),
              value:
                  avgQuality == null ? '–' : avgQuality.toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: FitTrackSpacing.gap),
        FitTrackButton(
          label: context.t('common:slLogCta'),
          icon: FitIcons.add,
          size: FitTrackButtonSize.lg,
          fullWidth: true,
          onPressed: () => context.push('/sleep/log'),
        ),
        const SizedBox(height: FitTrackSpacing.xl),
        FitTrackSectionLabel(title: context.t('common:slHistory')),
        for (final item in items.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: FitTrackSpacing.sm),
            child: Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                padding: const EdgeInsets.only(right: FitTrackSpacing.xl),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: c.danger,
                  borderRadius: BorderRadius.circular(FitTrackRadius.card),
                ),
                child: Icon(
                  FitIcons.delete,
                  semanticLabel: context.t('common:slDelete'),
                  color: Colors.white,
                ),
              ),
              onDismissed: (_) => onDelete(item),
              child: _SleepRow(item: item),
            ),
          ),
      ],
    );
  }
}

/// Last seven logged nights as bars; the latest is drawn in the full domain
/// colour and the rest in its soft tint.
class _WeekChart extends StatelessWidget {
  const _WeekChart({
    required this.nights,
    required this.average,
    required this.goalMinutes,
  });
  final List<SleepLog> nights;
  final int average;
  final int? goalMinutes;

  static const _plotHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final peak = [
      for (final n in nights) n.durationMinutes,
      if (goalMinutes != null) goalMinutes!,
    ].reduce((a, b) => a > b ? a : b);
    final day = DateFormat('E');
    return FitTrackCard(
      padding: const EdgeInsets.all(FitTrackSpacing.lg - 2),
      child: Semantics(
        container: true,
        label: [
          context.t('common:slLast7'),
          context.t('common:slAverage',
              args: {'value': _duration(context, average)}),
          for (final n in nights)
            '${day.format(n.wakeTime.toLocal())} '
                '${_duration(context, n.durationMinutes)}',
        ].join(', '),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      context.t('common:slLast7'),
                      style: FitTrackText.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    context.t(
                      'common:slAverage',
                      args: {'value': _duration(context, average)},
                    ),
                    style: FitTrackText.caption.copyWith(
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitTrackSpacing.lg - 2),
              Container(
                height: _plotHeight,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < nights.length; i++) ...[
                      if (i > 0) const SizedBox(width: FitTrackSpacing.sm),
                      Expanded(
                        child: Container(
                          height: _plotHeight *
                              (nights[i].durationMinutes / peak)
                                  .clamp(0.04, 1),
                          decoration: BoxDecoration(
                            color: i == nights.length - 1
                                ? c.sleepColor
                                : c.sleepSoft,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < nights.length; i++) ...[
                    if (i > 0) const SizedBox(width: FitTrackSpacing.sm),
                    Expanded(
                      child: Text(
                        day.format(nights[i].wakeTime.toLocal()),
                        textAlign: TextAlign.center,
                        style: FitTrackText.caption.copyWith(
                          color: i == nights.length - 1 ? c.ink : c.muted,
                          fontWeight: i == nights.length - 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepRow extends StatelessWidget {
  const _SleepRow({required this.item});
  final SleepLog item;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final time = DateFormat('h:mm a');
    final line = '${DateFormat('EEE · MMM d').format(item.wakeTime.toLocal())}'
        ' · ${time.format(item.bedtime.toLocal())}'
        ' – ${time.format(item.wakeTime.toLocal())}';
    return Semantics(
      container: true,
      label: [
        _duration(context, item.durationMinutes),
        line,
        if (item.quality != null)
          context.t('common:slQualityOf', args: {'n': item.quality!}),
      ].join(', '),
      child: ExcludeSemantics(
        child: FitTrackCard(
          padding: const EdgeInsets.symmetric(
            horizontal: FitTrackSpacing.lg - 2,
            vertical: FitTrackSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.sleepSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(FitIcons.sleep, size: 18, color: c.sleepColor),
              ),
              const SizedBox(width: FitTrackSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _duration(context, item.durationMinutes),
                      style: FitTrackText.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: FitTrackText.caption.copyWith(
                        color: c.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.quality != null)
                Text(
                  context.t('common:slQualityOf', args: {'n': item.quality!}),
                  style: FitTrackText.caption.copyWith(
                    color: c.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.xl,
        FitTrackSpacing.tabBarClearance - FitTrackSpacing.xxl,
        FitTrackSpacing.xl,
        0,
      ),
      child: Column(
        children: [
          Icon(FitIcons.sleep, size: 48, color: c.faint),
          const SizedBox(height: FitTrackSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: FitTrackText.titleLg.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: FitTrackSpacing.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: FitTrackText.body.copyWith(color: c.muted),
            ),
          ],
          const SizedBox(height: FitTrackSpacing.xl),
          FitTrackButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
