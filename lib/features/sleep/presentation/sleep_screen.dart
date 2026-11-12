import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../progress/domain/progress_models.dart';

final sleepHistoryProvider =
    FutureProvider.autoDispose<List<SleepLog>>((ref) async {
  final service = ref.watch(sleepServiceProvider);
  if (service == null) {
    return const [];
  }
  final rows = await service.history(limit: 60);
  return [for (final r in rows) SleepLog.fromJson(r)];
});

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final sleep = ref.watch(sleepHistoryProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/sleep/log'),
        backgroundColor: colors.accent,
        foregroundColor: colors.accentText,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accent,
          backgroundColor: colors.card,
          onRefresh: () async {
            ref.invalidate(sleepHistoryProvider);
            await ref.read(sleepHistoryProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _Header(onBack: () => context.pop()),
              sleep.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                ),
                error: (_, __) => const _Empty(
                  title: 'Sleep history unavailable',
                  subtitle: 'Pull to retry.',
                ),
                data: (items) => _Content(
                  items: items,
                  onDelete: (item) async {
                    await ref.read(sleepServiceProvider)?.deleteLog(item.id);
                    ref.invalidate(sleepHistoryProvider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.arrow_back, color: colors.text, size: 19),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                Text(
                  'Recovery & sleep history',
                  style: TextStyle(fontSize: 10, color: colors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.bedtime, color: AppColors.sleep, size: 24),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.items, required this.onDelete});
  final List<SleepLog> items;
  final ValueChanged<SleepLog> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    if (items.isEmpty) {
      return const _Empty(
        title: 'No sleep logged yet',
        subtitle: 'Track your first night to build recovery history.',
      );
    }

    final latest = items.first;
    final avgMinutes =
        items.fold<int>(0, (sum, item) => sum + item.durationMinutes) /
            items.length;
    final qualityValues = items
        .where((item) => item.quality != null)
        .map((item) => item.quality!)
        .toList();
    final avgQuality = qualityValues.isEmpty
        ? null
        : qualityValues.reduce((a, b) => a + b) / qualityValues.length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.accentTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'LAST NIGHT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _duration(latest.durationMinutes),
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sleep,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('h:mm a').format(latest.bedtime.toLocal())} – ${DateFormat('h:mm a').format(latest.wakeTime.toLocal())}',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
              if (latest.quality != null) ...[
                const SizedBox(height: 8),
                Text(
                  List.filled(latest.quality!, '★').join(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.sleep,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.bedtime_outlined,
                  value: _duration(avgMinutes.round()),
                  label: 'AVG SLEEP',
                  color: AppColors.sleep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.calendar_month_outlined,
                  value: '${items.length}',
                  label: 'NIGHTS',
                  color: AppColors.water,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.star_outline,
                  value: avgQuality == null
                      ? '—'
                      : avgQuality.toStringAsFixed(1),
                  label: 'QUALITY',
                  color: AppColors.xp,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SLEEP HISTORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: colors.muted,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: items
                .take(12)
                .map(
                  (item) => Dismissible(
                    key: ValueKey(item.id),
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
                    onDismissed: (_) => onDelete(item),
                    child: _SleepRow(item: item),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  static String _duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: colors.faint,
              fontWeight: FontWeight.w700,
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepRow extends StatelessWidget {
  const _SleepRow({required this.item});
  final SleepLog item;

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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.sleep.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.bedtime,
              size: 19,
              color: AppColors.sleep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _Content._duration(item.durationMinutes),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('EEE · MMM d').format(item.wakeTime.toLocal())} · ${DateFormat('h:mm a').format(item.bedtime.toLocal())} – ${DateFormat('h:mm a').format(item.wakeTime.toLocal())}',
                  style: TextStyle(fontSize: 10, color: colors.muted),
                ),
              ],
            ),
          ),
          if (item.quality != null)
            Text(
              '${item.quality}/5',
              style: const TextStyle(
                color: AppColors.sleep,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
      child: Column(
        children: [
          Icon(Icons.bedtime, size: 56, color: colors.border2),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.faint),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.push('/sleep/log'),
            icon: const Icon(Icons.add),
            label: const Text('Log sleep'),
          ),
        ],
      ),
    );
  }
}
