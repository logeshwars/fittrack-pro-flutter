import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(dashboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Today', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Your fitness at a glance', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          state.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (_, __) => const Card(child: ListTile(title: Text('Dashboard unavailable'), subtitle: Text('Check your connection and account permissions.'))),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!data.configured)
                  const Card(child: ListTile(title: Text('Backend not configured'), subtitle: Text('Supply Supabase build-time configuration.')))
                else if (!data.signedIn)
                  const Card(child: ListTile(title: Text('Sign in to view your dashboard'), subtitle: Text('Use the account icon above.'))),
                _MetricCard(label: 'Workouts', value: '${data.workouts}', detail: 'Recent completed workouts', icon: Icons.fitness_center_outlined),
                _MetricCard(label: 'Protein', value: '${data.proteinG.toStringAsFixed(0)} g', detail: 'From recent food logs', icon: Icons.restaurant_outlined),
                _MetricCard(label: 'Cardio', value: '${data.cardioMinutes} min', detail: 'From recent sessions', icon: Icons.directions_run_outlined),
                _MetricCard(label: 'Latest weight', value: data.latestWeightKg == null ? '—' : '${data.latestWeightKg!.toStringAsFixed(1)} kg', detail: 'Most recent measurement', icon: Icons.monitor_weight_outlined),
                const SizedBox(height: 12),
                Text('Explore', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ActionChip(label: const Text('Workouts'), onPressed: () => context.go('/workout')),
                  ActionChip(label: const Text('Nutrition'), onPressed: () => context.go('/nutrition')),
                  ActionChip(label: const Text('Cardio'), onPressed: () => context.go('/cardio')),
                  ActionChip(label: const Text('Progress'), onPressed: () => context.go('/progress')),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail, required this.icon});
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(detail),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    ),
  );
}
