import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/config/app_config.dart';
import '../data/gamification_repository.dart';
import '../domain/gamification_stats.dart';

final gamificationProvider = FutureProvider.autoDispose<GamificationStats?>((ref) async {
  ref.watch(authStateProvider);
  if (!AppConfig.hasSupabase) return null;
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;
  return GamificationRepository(client).readOwnStats(authenticatedUserId: user.id);
});

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(gamificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Training achievements')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Read-only achievements. XP awards are disabled until account migration is verified.'),
        const SizedBox(height: 16),
        stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const ListTile(
            title: Text('Unable to load achievements'),
            subtitle: Text('Check account permissions and connection.'),
          ),
          data: (value) {
            if (!AppConfig.hasSupabase) {
              return const ListTile(title: Text('Backend not configured'));
            }
            if (Supabase.instance.client.auth.currentUser == null) {
              return const ListTile(title: Text('Sign in to see achievements'));
            }
            if (value == null) {
              return const ListTile(title: Text('No achievements profile found'));
            }
            return Column(children: [
              ListTile(title: const Text('Level'), trailing: Text('${value.level}')),
              ListTile(title: const Text('Total XP'), trailing: Text('${value.totalXp}')),
              ListTile(title: const Text('Rank'), trailing: Text(value.rankTier)),
              ListTile(title: const Text('Current streak'), trailing: Text('${value.currentStreak} days')),
              ListTile(title: const Text('Longest streak'), trailing: Text('${value.longestStreak} days')),
              ListTile(title: const Text('Workouts'), trailing: Text('${value.totalWorkouts}')),
              ListTile(title: const Text('Personal records'), trailing: Text('${value.totalPrs}')),
              ListTile(title: const Text('Lifetime volume'), trailing: Text('${value.totalVolumeKg.toStringAsFixed(0)} kg')),
            ]);
          },
        ),
      ]),
    );
  }
}
