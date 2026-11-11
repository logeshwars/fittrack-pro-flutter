import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/progress_repository.dart';
import '../domain/progress_models.dart';

final progressProvider = FutureProvider.autoDispose<({List<WeightLog> weights, List<SleepLog> sleep})>((ref) async {
  if (!AppConfig.hasSupabase) {
    return (weights: <WeightLog>[], sleep: <SleepLog>[]);
  }
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    return (weights: <WeightLog>[], sleep: <SleepLog>[]);
  }
  return ProgressRepository(client).recent(authenticatedUserId: user.id);
});

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final progress = ref.watch(progressProvider);

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: () async {
        ref.invalidate(progressProvider);
        await ref.read(progressProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 44),
        children: [
          const FitTrackScreenHeader(
            title: 'Progress',
            subtitle: 'Analytics, body metrics and consistency',
            icon: Icons.insights,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: FitTrackSegmentedTabs(
              labels: const ['Analytics', 'Achievements'],
              selectedIndex: tab,
              onSelected: (value) => setState(() => tab = value),
            ),
          ),
          if (tab == 1)
            _AchievementsCard(onTap: () => context.push('/achievements'))
          else
            progress.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: colors.accent)),
              ),
              error: (_, __) => const _Info(text: 'Unable to load progress.'),
              data: (data) => _Analytics(
                weights: data.weights,
                sleep: data.sleep,
              ),
            ),
        ],
      ),
    );
  }
}

class _Analytics extends StatelessWidget {
  const _Analytics({required this.weights, required this.sleep});
  final List<WeightLog> weights;
  final List<SleepLog> sleep;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final summary = ProgressSummary.fromLogs(weights: weights, sleep: sleep);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const FitTrackSectionLabel(title: 'Body Metrics'),
                _MetricRow(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Latest weight',
                  value: summary.latestWeightKg == null
                      ? '—'
                      : '${summary.latestWeightKg!.toStringAsFixed(1)} kg',
                  color: AppColors.weight,
                ),
                Divider(color: colors.border2),
                _MetricRow(
                  icon: Icons.trending_up,
                  label: 'Weight change',
                  value: summary.weightChangeKg == null
                      ? '—'
                      : '${summary.weightChangeKg! >= 0 ? '+' : ''}${summary.weightChangeKg!.toStringAsFixed(1)} kg',
                  color: summary.weightChangeKg != null &&
                          summary.weightChangeKg! <= 0
                      ? AppColors.recovery
                      : AppColors.warningDark,
                ),
                Divider(color: colors.border2),
                _MetricRow(
                  icon: Icons.bedtime_outlined,
                  label: 'Average sleep',
                  value: summary.averageSleepHours == null
                      ? '—'
                      : '${summary.averageSleepHours!.toStringAsFixed(1)} h',
                  color: AppColors.sleep,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FitTrackSectionLabel(title: 'Activity Heatmap'),
                Text(
                  'WEIGHT ENTRIES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: colors.faint,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _MiniHeatMap(
                  dates: weights.map((w) => w.loggedAt).toList(),
                  color: AppColors.weight,
                ),
                const SizedBox(height: 18),
                Text(
                  'SLEEP ENTRIES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: colors.faint,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _MiniHeatMap(
                  dates: sleep.map((s) => s.wakeTime).toList(),
                  color: AppColors.sleep,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const FitTrackSectionLabel(title: 'Recent Weight'),
          if (weights.isEmpty)
            const _Info(text: 'No weight entries yet.')
          else
            ...weights.take(6).map(
                  (w) => _HistoryMetric(
                    title: '${w.weightKg.toStringAsFixed(1)} kg',
                    subtitle: DateFormat('EEE · MMM d').format(w.loggedAt),
                    color: AppColors.weight,
                  ),
                ),
          const SizedBox(height: 8),
          const FitTrackSectionLabel(title: 'Recent Sleep'),
          if (sleep.isEmpty)
            const _Info(text: 'No sleep entries yet.')
          else
            ...sleep.take(6).map(
                  (s) => _HistoryMetric(
                    title: '${(s.durationMinutes / 60).toStringAsFixed(1)} hours',
                    subtitle: DateFormat('EEE · MMM d').format(s.wakeTime),
                    color: AppColors.sleep,
                  ),
                ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/progress/draft'),
            icon: const Icon(Icons.add),
            label: const Text('Log weight / sleep'),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHeatMap extends StatelessWidget {
  const _MiniHeatMap({required this.dates, required this.color});
  final List<DateTime> dates;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateSet = dates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    return Row(
      children: List.generate(14, (index) {
        final date = today.subtract(Duration(days: 13 - index));
        final hit = dateSet.contains(date);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 18,
            decoration: BoxDecoration(
              color: hit
                  ? color.withValues(alpha: .75)
                  : colors.cardAlt,
              borderRadius: BorderRadius.circular(3),
              border: date == today
                  ? Border.all(color: colors.accent)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, size: 52, color: AppColors.xp),
              const SizedBox(height: 12),
              Text(
                'Achievements & XP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Open your streak, level, PR and badge progress.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'View achievements',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: colors.accentText,
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

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.muted),
      ),
    );
  }
}
