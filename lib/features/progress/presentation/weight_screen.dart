import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/progress_models.dart';

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
  const WeightTrend({required this.latest, required this.change, required this.average});
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

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  int _range = 30;

  Future<void> _log() async {
    final weight = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weight,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(DateFormat('EEE, MMM d').format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheet(() => date = picked);
                  }
                },
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final value = double.tryParse(weight.text.trim());
    final text = note.text.trim();
    weight.dispose();
    note.dispose();
    if (saved != true || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (value == null || value <= 0 || value > 500) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a valid weight')));
      return;
    }
    await ref
        .read(weightServiceProvider)
        ?.logWeight(value, note: text.isEmpty ? null : text, date: date);
    ref.invalidate(weightHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final logs = ref.watch(weightHistoryProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.header,
        foregroundColor: colors.text,
        title: const Text('Body weight'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _log,
        backgroundColor: colors.accent,
        foregroundColor: colors.accentText,
        child: const Icon(Icons.add),
      ),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load weight history')),
        data: (all) {
          if (all.isEmpty) {
            return Center(
              child: Text(
                'No weigh-ins yet. Tap + to add one.',
                style: TextStyle(color: colors.muted),
              ),
            );
          }
          final cutoff = DateTime.now().subtract(Duration(days: _range));
          final windowed = [for (final l in all) if (l.loggedAt.isAfter(cutoff)) l];
          final shown = windowed.isEmpty ? all.take(1).toList() : windowed;
          final trend = WeightTrend.from(shown);
          final points = [
            for (final l in shown.reversed.toList().asMap().entries)
              FlSpot(l.key.toDouble(), l.value.weightKg),
          ];
          final ys = [for (final p in points) p.y];
          final minY = (ys.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
          final maxY = (ys.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'LATEST',
                      value: '${trend.latest?.toStringAsFixed(1) ?? '—'} kg',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'CHANGE',
                      value: trend.change == null
                          ? '—'
                          : '${trend.change! > 0 ? '+' : ''}${trend.change!.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'AVG (7)',
                      value: '${trend.average?.toStringAsFixed(1) ?? '—'} kg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7D')),
                  ButtonSegment(value: 30, label: Text('30D')),
                  ButtonSegment(value: 90, label: Text('90D')),
                  ButtonSegment(value: 180, label: Text('6M')),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: points.length < 2
                    ? Center(
                        child: Text(
                          'Add another weigh-in to see a trend',
                          style: TextStyle(color: colors.muted),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) =>
                                FlLine(color: colors.border2, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            bottomTitles: const AxisTitles(),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 34,
                                getTitlesWidget: (v, meta) => Text(
                                  v.toStringAsFixed(0),
                                  style: TextStyle(fontSize: 10, color: colors.muted),
                                ),
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: points,
                              isCurved: true,
                              barWidth: 3,
                              color: AppColors.weight,
                              dotData: FlDotData(show: points.length <= 30),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.weight.withValues(alpha: .12),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              for (final l in all.take(60))
                Dismissible(
                  key: ValueKey(l.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: colors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await ref.read(weightServiceProvider)?.deleteLog(l.id);
                    ref.invalidate(weightHistoryProvider);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEE, MMM d').format(l.loggedAt),
                                style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
                              ),
                              if (l.note != null && l.note!.isNotEmpty)
                                Text(
                                  l.note!,
                                  style: TextStyle(fontSize: 11, color: colors.muted),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${l.weightKg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.weight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.text),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, letterSpacing: 1.4, color: colors.muted)),
      ],
    );
  }
}
