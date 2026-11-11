import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../data/workout_repository.dart';
import '../domain/workout_models.dart';

final workoutHistoryProvider = FutureProvider.autoDispose<List<Workout>>((ref) async {
  if (!AppConfig.hasSupabase) return const [];
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  return WorkoutRepository(client).getHistory(authenticatedUserId: user.id);
});

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(workoutHistoryProvider); await ref.read(workoutHistoryProvider.future); },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Workout', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Your completed workouts. Logging will be enabled after the account migration audit.'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.push('/workout/draft'), icon: const Icon(Icons.edit_note), label: const Text('Create local workout draft')),
          const SizedBox(height: 20),
          history.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (error, stack) => const Card(child: ListTile(title: Text('Unable to load history'), subtitle: Text('Check your connection and account permissions.'))),
            data: (workouts) {
              if (!AppConfig.hasSupabase) return const Card(child: ListTile(title: Text('Backend not configured'), subtitle: Text('Provide Supabase build-time configuration.')));
              if (Supabase.instance.client.auth.currentUser == null) return const Card(child: ListTile(title: Text('Sign in to see your workouts'), subtitle: Text('Use the account icon in the top bar.')));
              if (workouts.isEmpty) return const Card(child: ListTile(title: Text('No completed workouts found')));
              return Column(children: workouts.map((workout) => Card(
                child: ListTile(
                  title: Text(workout.name),
                  subtitle: Text('${workout.startedAt.toLocal().toString().split('.').first} • ${workout.sets.length} sets'),
                  trailing: Text('${workout.totalVolumeKg.toStringAsFixed(0)} kg'),
                ),
              )).toList());
            },
          ),
        ],
      ),
    );
  }
}
