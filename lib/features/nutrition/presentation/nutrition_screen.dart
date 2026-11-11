import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../data/nutrition_repository.dart';
import '../domain/nutrition_models.dart';

final nutritionLogsProvider = FutureProvider.autoDispose<List<NutritionLog>>((ref) async {
  if (!AppConfig.hasSupabase) return const [];
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  return NutritionRepository(client).getRecentLogs(authenticatedUserId: user.id);
});

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(nutritionLogsProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(nutritionLogsProvider); await ref.read(nutritionLogsProvider.future); },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Nutrition', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Recent food logs. Food logging will be enabled after identity verification.'),
          const SizedBox(height: 20),
          logs.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (error, stack) => const Card(child: ListTile(title: Text('Unable to load nutrition'), subtitle: Text('Check your connection and account permissions.'))),
            data: (items) {
              if (!AppConfig.hasSupabase) return const Card(child: ListTile(title: Text('Backend not configured')));
              if (Supabase.instance.client.auth.currentUser == null) return const Card(child: ListTile(title: Text('Sign in to view nutrition'), subtitle: Text('Use the account icon in the top bar.')));
              final totals = NutritionTotals.fromLogs(items);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Recent logs totals'),
                  const SizedBox(height: 8),
                  Text('${totals.calories.toStringAsFixed(0)} kcal  •  ${totals.proteinG.toStringAsFixed(0)} g protein'),
                  Text('Carbs ${totals.carbsG.toStringAsFixed(0)} g  •  Fat ${totals.fatG.toStringAsFixed(0)} g'),
                ]))),
                if (items.isEmpty) const Card(child: ListTile(title: Text('No nutrition logs found'))),
                ...items.map((item) => Card(child: ListTile(
                  title: Text(item.foodName),
                  subtitle: Text('${item.quantityG.toStringAsFixed(0)} g • ${item.mealType ?? 'Meal'}'),
                  trailing: Text('${item.proteinG.toStringAsFixed(1)} g protein'),
                ))),
              ]);
            },
          ),
        ],
      ),
    );
  }
}
