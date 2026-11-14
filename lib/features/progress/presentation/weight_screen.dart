import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
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
import '../../settings/data/goal_targets.dart';
import '../domain/progress_models.dart';
import '../../../core/widgets/fittrack_icons.dart';

final weightHistoryProvider =
    FutureProvider.autoDispose<List<WeightLog>>((ref) async {
  final service = ref.watch(weightServiceProvider);
  if (service == null) {
    return const [];
  }
  final rows = await service.history(limit: 180);
  return [for (final r in rows) WeightLog.fromJson(r)];
});

/// Trend math shared with tests: change over the window and 7-entry average.
class WeightTrend {
  const WeightTrend(
      {required this.latest, required this.change, required this.average});
  final double? latest;
  final double? change;
  final double? average;

  /// [logs] must be newest first.
  factory WeightTrend.from(List<WeightLog> logs) {
    if (logs.isEmpty) {
      return const WeightTrend(latest: null, change: null, average: null);
    }
    final recent = logs.take(7).map((l) => l.weightKg);
    return WeightTrend(
      latest: logs.first.weightKg,
      change: logs.length < 2 ? null : logs.first.weightKg - logs.last.weightKg,
      average: recent.reduce((a, b) => a + b) / recent.length,
    );
  }
}

const _ranges = [7, 30, 90, 180];

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  int _range = 30;
  final _weight = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final invalid = context.t('common:wtInvalid');
    final signIn = context.t('common:wtSignIn');
    final saved = context.t('common:wtSaved');
    final value = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0 || value > 500) {
      setState(() => _error = invalid);
      return;
    }
    final service = ref.read(weightServiceProvider);
    if (service == null) {
      messenger.showSnackBar(SnackBar(content: Text(signIn)));
      return;
    }
    final text = _note.text.trim();
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await service.logWeight(
        value,
        note: text.isEmpty ? null : text,
        date: _date,
      );
      ref.invalidate(weightHistoryProvider);
      if (mounted) {
        _note.clear();
        setState(() => _date = DateTime.now());
        messenger.showSnackBar(SnackBar(content: Text(saved)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(WeightLog l) async {
    await ref.read(weightServiceProvider)?.deleteLog(l.id);
    ref.invalidate(weightHistoryProvider);
  }

  String _rangeLabel(BuildContext context, int days) => days == 180
      ? context.t('common:wtRange180')
      : context.t('common:wtRangeDays', args: {'n': days});

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final logs = ref.watch(weightHistoryProvider);
    final goal = ref.watch(goalTargetsProvider).valueOrNull?.targetWeight;
    final kg = context.t('profile:kgUnit');

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: c.line)),
        leading: FitTrackIconButton(
          icon: FitIcons.back,
          color: c.ink,
          semanticLabel: context.t('settings:backLabel'),
          onPressed: () => context.pop(),
        ),
        title: Semantics(
          header: true,
          child: Text(
            context.t('common:wtTitle'),
            style: FitTrackText.titleLg.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Message(
          title: context.t('common:wtLoadFailed'),
          action: context.t('common:retry'),
          onAction: () => ref.invalidate(weightHistoryProvider),
        ),
        data: (all) {
          final cutoff = DateTime.now().subtract(Duration(days: _range));
          final windowed = [
            for (final l in all)
              if (l.loggedAt.isAfter(cutoff)) l,
          ];
          final shown =
              windowed.isEmpty ? all.take(1).toList() : windowed;
          final trend = WeightTrend.from(shown);
          final points = [
            for (final e in shown.reversed.toList().asMap().entries)
              FlSpot(e.key.toDouble(), e.value.weightKg),
          ];

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(weightHistoryProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.lg,
                FitTrackSpacing.md,
                FitTrackSpacing.lg,
                FitTrackSpacing.xxl,
              ),
              children: [
                _StatStrip(
                  current: trend.latest,
                  change: trend.change,
                  goal: goal,
                  rangeLabel: _rangeLabel(context, _range),
                  kg: kg,
                ),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackSegmentedTabs(
                  labels: [for (final r in _ranges) _rangeLabel(context, r)],
                  selectedIndex: _ranges.indexOf(_range),
                  onSelected: (i) => setState(() => _range = _ranges[i]),
                ),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackCard(
                  padding: const EdgeInsets.all(FitTrackSpacing.md + 2),
                  child: all.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: FitTrackSpacing.xl,
                          ),
                          child: Center(
                            child: Text(
                              context.t('common:wtEmptySub'),
                              textAlign: TextAlign.center,
                              style: FitTrackText.body.copyWith(color: c.muted),
                            ),
                          ),
                        )
                      : _TrendCard(
                          points: points,
                          shown: shown,
                          goal: goal,
                          average: trend.average,
                          kg: kg,
                        ),
                ),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackCard(
                  padding: const EdgeInsets.all(FitTrackSpacing.md + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          context.t('common:wtLogTitle'),
                          style: FitTrackText.title.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: FitTrackSpacing.md - 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FitTrackTextField(
                              label: '${context.t('common:wtWeightLabel')}'
                                  ' ($kg)',
                              controller: _weight,
                              errorText: _error,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FitTrackSpacing.sm),
                      FitTrackTextField(
                        label: context.t('common:wtNote'),
                        controller: _note,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: FitTrackSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: FitTrackButton(
                              label: DateFormat('EEE, MMM d').format(_date),
                              variant: FitTrackButtonVariant.secondary,
                              icon: FitIcons.calendar,
                              fullWidth: true,
                              onPressed: _pickDate,
                            ),
                          ),
                          const SizedBox(width: FitTrackSpacing.md - 2),
                          Expanded(
                            child: FitTrackButton(
                              label: context.t('common:wtSave'),
                              fullWidth: true,
                              loading: _saving,
                              onPressed:
                                  _saving ? null : () => unawaited(_save()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FitTrackSpacing.md),
                FitTrackCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FitTrackSpacing.md + 2,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SizedBox(
                            height: FitTrackSpacing.touchMin,
                            child: Semantics(
                              header: true,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  context.t('common:wtHistory'),
                                  style: FitTrackText.title.copyWith(
                                    color: c.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (all.isEmpty)
                        Container(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: c.line)),
                          ),
                          padding: const EdgeInsets.all(FitTrackSpacing.lg),
                          width: double.infinity,
                          child: Text(
                            context.t('common:wtEmptyTitle'),
                            style: FitTrackText.body.copyWith(color: c.muted),
                          ),
                        ),
                      for (final l in all.take(60))
                        Dismissible(
                          key: ValueKey(l.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: c.danger,
                            padding: const EdgeInsetsDirectional.only(
                              end: FitTrackSpacing.xl,
                            ),
                            alignment: AlignmentDirectional.centerEnd,
                            child: Icon(
                              FitIcons.delete,
                              semanticLabel: context.t('common:wtDelete'),
                              color: c.accentText,
                            ),
                          ),
                          onDismissed: (_) => unawaited(_delete(l)),
                          child: _HistoryRow(log: l, kg: kg),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.current,
    required this.change,
    required this.goal,
    required this.rangeLabel,
    required this.kg,
  });

  final double? current;
  final double? change;
  final double? goal;
  final String rangeLabel;
  final String kg;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    // Moving toward the goal reads as good; the sign is always printed so
    // colour is never the only signal.
    final towardGoal = change != null &&
        current != null &&
        goal != null &&
        change != 0 &&
        ((goal! < current! && change! < 0) ||
            (goal! > current! && change! > 0));
    final changeText = change == null
        ? '—'
        : '${change! > 0 ? '+' : change! < 0 ? '−' : ''}'
            '${change!.abs().toStringAsFixed(1)}';

    Widget cell(String label, String value, {Color? color, bool first = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FitTrackSpacing.md + 2,
            vertical: FitTrackSpacing.md,
          ),
          decoration: BoxDecoration(
            border: first
                ? null
                : BorderDirectional(start: BorderSide(color: c.line)),
          ),
          child: Semantics(
            container: true,
            label: '$label, $value $kg',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: FitTrackText.caption.copyWith(
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xs),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$value ',
                          style: FitTrackText.stat.copyWith(
                            color: color ?? c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: kg,
                          style: FitTrackText.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FitTrackRadius.card),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          cell(
            context.t('common:wtCurrent'),
            current?.toStringAsFixed(1) ?? '—',
            first: true,
          ),
          cell(rangeLabel, changeText, color: towardGoal ? c.ok : null),
          cell(context.t('common:wtGoal'), goal?.toStringAsFixed(1) ?? '—'),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.points,
    required this.shown,
    required this.goal,
    required this.average,
    required this.kg,
  });

  final List<FlSpot> points;

  /// Logs in the window, newest first.
  final List<WeightLog> shown;
  final double? goal;
  final double? average;
  final String kg;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final ys = [for (final p in points) p.y];
    var lo = ys.reduce((a, b) => a < b ? a : b);
    var hi = ys.reduce((a, b) => a > b ? a : b);
    if (goal != null) {
      lo = lo < goal! ? lo : goal!;
      hi = hi > goal! ? hi : goal!;
    }
    final minY = (lo - 1).floorToDouble();
    final maxY = (hi + 1).ceilToDouble();
    final fmt = DateFormat('d MMM');
    final first = shown.last.weightKg.toStringAsFixed(1);
    final last = shown.first.weightKg.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.t('common:wtTrend'),
                style: FitTrackText.title.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              average == null
                  ? kg
                  : context.t(
                      'common:wtAvg7',
                      args: {'value': average!.toStringAsFixed(1)},
                    ),
              style: FitTrackText.caption.copyWith(color: c.muted),
            ),
          ],
        ),
        const SizedBox(height: FitTrackSpacing.md),
        SizedBox(
          height: 140,
          child: points.length < 2
              ? Center(
                  child: Text(
                    context.t('common:wtNeedTwo'),
                    textAlign: TextAlign.center,
                    style: FitTrackText.body.copyWith(color: c.muted),
                  ),
                )
              : Semantics(
                  image: true,
                  label: context.t(
                    'common:wtChartLabel',
                    args: {'from': first, 'to': last},
                  ),
                  child: ExcludeSemantics(
                    child: LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, meta) => Text(
                                v.toStringAsFixed(0),
                                style: FitTrackText.overline
                                    .copyWith(color: c.muted),
                              ),
                            ),
                          ),
                        ),
                        extraLinesData: goal == null
                            ? null
                            : ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: goal!,
                                    color: c.faint,
                                    strokeWidth: 1,
                                    dashArray: const [4, 4],
                                  ),
                                ],
                              ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points,
                            isCurved: true,
                            barWidth: 3,
                            color: c.waterColor,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, bar) =>
                                  points.length <= 30 || spot == points.last,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: FitTrackSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              fmt.format(shown.last.loggedAt),
              style: FitTrackText.caption.copyWith(color: c.muted),
            ),
            Text(
              context.t('common:wtToday'),
              style: FitTrackText.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.log, required this.kg});

  final WeightLog log;
  final String kg;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final note = log.note;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: FitTrackSpacing.md + 2,
        vertical: FitTrackSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE d MMM').format(log.loggedAt),
                  style: FitTrackText.body.copyWith(color: c.ink),
                ),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
              ],
            ),
          ),
          Text(
            '${log.weightKg.toStringAsFixed(1)} $kg',
            style: FitTrackText.body.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FitTrackSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: FitTrackText.body.copyWith(color: c.muted),
            ),
            const SizedBox(height: FitTrackSpacing.lg),
            FitTrackButton(label: action, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
