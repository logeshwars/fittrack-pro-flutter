import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../data/cardio_repository.dart';
import '../domain/cardio_session.dart';

final cardioProvider = FutureProvider.autoDispose<List<CardioSession>>((ref) async {
  if (!AppConfig.hasSupabase) return [];
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  return user == null ? [] : CardioRepository(client).recent(authenticatedUserId: user.id);
});

class CardioScreen extends ConsumerWidget {
  const CardioScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(cardioProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(cardioProvider); await ref.read(cardioProvider.future); },
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Cardio', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Recent sessions. Tracking will be enabled after identity verification.'),
        const SizedBox(height: 20),
        sessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Card(child: ListTile(title: Text('Unable to load cardio sessions'))),
          data: (items) {
            if (!AppConfig.hasSupabase) return const Card(child: ListTile(title: Text('Backend not configured')));
            if (Supabase.instance.client.auth.currentUser == null) return const Card(child: ListTile(title: Text('Sign in to see cardio history')));
            if (items.isEmpty) return const Card(child: ListTile(title: Text('No cardio sessions found')));
            return Column(children: items.map((item) => Card(child: ListTile(
              leading: const Icon(Icons.directions_run),
              title: Text(item.name ?? item.type),
              subtitle: Text(item.startedAt.toLocal().toString().split('.').first),
              trailing: Text(item.distanceKm != null ? '${item.distanceKm!.toStringAsFixed(1)} km' : '${(item.durationSeconds ?? 0) ~/ 60} min'),
            ))).toList());
          },
        ),
      ]),
    );
  }
}
