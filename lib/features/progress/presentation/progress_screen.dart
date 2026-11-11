import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../data/progress_repository.dart';
import '../domain/progress_models.dart';

final progressProvider = FutureProvider.autoDispose<({List<WeightLog> weights, List<SleepLog> sleep})>((ref) async {
  if (!AppConfig.hasSupabase) return (weights: <WeightLog>[], sleep: <SleepLog>[]);
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return (weights: <WeightLog>[], sleep: <SleepLog>[]);
  return await ProgressRepository(client).recent(authenticatedUserId: user.id);
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(progressProvider); await ref.read(progressProvider.future); },
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Progress', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Weight and sleep history. Logging remains disabled until account migration is verified.'),
        const SizedBox(height: 20),
        progress.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Card(child: ListTile(title: Text('Unable to load progress'))),
          data: (data) {
            if (!AppConfig.hasSupabase) return const Card(child: ListTile(title: Text('Backend not configured')));
            if (Supabase.instance.client.auth.currentUser == null) return const Card(child: ListTile(title: Text('Sign in to see progress')));
            final summary = ProgressSummary.fromLogs(weights: data.weights, sleep: data.sleep);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Card(child: ListTile(title: const Text('Latest weight'), subtitle: Text(summary.latestWeightKg == null ? 'No entries' : '${summary.latestWeightKg!.toStringAsFixed(1)} kg'), trailing: const Icon(Icons.monitor_weight_outlined))),
              Card(child: ListTile(title: const Text('Weight change (recent entries)'), subtitle: Text(summary.weightChangeKg == null ? 'Not enough entries' : '${summary.weightChangeKg!.toStringAsFixed(1)} kg'))),
              Card(child: ListTile(title: const Text('Average sleep (recent entries)'), subtitle: Text(summary.averageSleepHours == null ? 'No entries' : '${summary.averageSleepHours!.toStringAsFixed(1)} hours'), trailing: const Icon(Icons.bedtime_outlined))),
              const SizedBox(height: 20),
              Text('Weight history', style: Theme.of(context).textTheme.titleLarge),
              ...data.weights.map((item) => ListTile(title: Text('${item.weightKg.toStringAsFixed(1)} kg'), subtitle: Text(item.loggedAt.toIso8601String().split('T').first))),
              const SizedBox(height: 12),
              Text('Sleep history', style: Theme.of(context).textTheme.titleLarge),
              ...data.sleep.map((item) => ListTile(title: Text('${(item.durationMinutes/60).toStringAsFixed(1)} hours'), subtitle: Text(item.wakeTime.toLocal().toString().split('.').first))),
            ]);
          },
        ),
      ]),
    );
  }
}
