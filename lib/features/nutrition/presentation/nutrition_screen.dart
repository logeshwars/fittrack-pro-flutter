import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
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

  static const calorieGoal = 2000.0;
  static const proteinGoal = 150.0;
  static const carbGoal = 250.0;
  static const fatGoal = 65.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final logs = ref.watch(nutritionLogsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/nutrition/log'),
        backgroundColor: colors.accent,
        foregroundColor: colors.accentText,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(nutritionLogsProvider);
          await ref.read(nutritionLogsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            FitTrackScreenHeader(
              title: 'Nutrition',
              subtitle: DateFormat('EEEE, MMM d').format(DateTime.now()),
              icon: Icons.restaurant,
            ),
            logs.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: colors.accent)),
              ),
              error: (_, __) => const _Info(text: 'Unable to load nutrition.'),
              data: (items) {
                final today = DateTime.now();
                final todayItems = items.where((item) {
                  final d = item.loggedAt.toLocal();
                  return d.year == today.year &&
                      d.month == today.month &&
                      d.day == today.day;
                }).toList();
                final totals = NutritionTotals.fromLogs(todayItems);

                return Column(
                  children: [
                    _BudgetCard(totals: totals),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.push('/nutrition/log'),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Log manually'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/nutrition/scan'),
                              icon: const Icon(Icons.qr_code_scanner, size: 16),
                              label: const Text('Scan barcode'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: FitTrackSectionLabel(
                        title: 'Food Log',
                        action: '${todayItems.length} ${todayItems.length == 1 ? 'entry' : 'entries'}',
                        onAction: () {},
                      ),
                    ),
                    if (todayItems.isEmpty)
                      _Empty(onTap: () => context.push('/nutrition/log'))
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: todayItems.map((item) => _MealCard(item: item)).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.totals});
  final NutritionTotals totals;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final remaining = (NutritionScreen.calorieGoal - totals.calories).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY BUDGET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FitTrackStatRing(
                      size: 124,
                      strokeWidth: 10,
                      progress: totals.calories / NutritionScreen.calorieGoal,
                      color: AppColors.workout,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totals.calories.round().toString(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            'kcal',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remaining > 0 ? 'REMAINING' : 'STATUS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: colors.faint,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            remaining > 0
                                ? NumberFormat.decimalPattern().format(remaining)
                                : 'Goal reached',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: remaining > 0 ? colors.text : AppColors.recovery,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'DAILY GOAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: colors.faint,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '2,000 kcal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.subtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border2),
          _MacroRow(
            label: 'Protein',
            value: totals.proteinG,
            goal: NutritionScreen.proteinGoal,
            color: AppColors.nutrition,
            icon: Icons.water_drop_outlined,
          ),
          Divider(height: 1, color: colors.border2, indent: 16, endIndent: 16),
          _MacroRow(
            label: 'Fat',
            value: totals.fatG,
            goal: NutritionScreen.fatGoal,
            color: AppColors.xp,
            icon: Icons.opacity,
          ),
          Divider(height: 1, color: colors.border2, indent: 16, endIndent: 16),
          _MacroRow(
            label: 'Carbs',
            value: totals.carbsG,
            goal: NutritionScreen.carbGoal,
            color: AppColors.water,
            icon: Icons.grain,
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final double goal;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final pct = (value / goal).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: colors.border2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              '${value.round()} / ${goal.round()} g',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: value >= goal ? color : colors.subtext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.item});
  final NutritionLog item;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final calories = item.calories == null ? '' : ' · ${item.calories!.round()} kcal';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 3, height: 74, color: AppColors.nutrition),
          Container(
            width: 48,
            height: 74,
            color: AppColors.nutrition.withValues(alpha: .05),
            alignment: Alignment.center,
            child: const Icon(Icons.restaurant, size: 22, color: AppColors.nutrition),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item.mealType ?? 'Meal').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppColors.nutrition,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.foodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantityG.round()} g · ${item.proteinG.toStringAsFixed(1)} g protein$calories',
                    style: TextStyle(fontSize: 11, color: colors.subtext),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant, size: 52, color: colors.border2),
          const SizedBox(height: 14),
          Text(
            'Nothing logged',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log your first meal to start tracking today.',
            style: TextStyle(fontSize: 12, color: colors.faint),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Log first meal'),
          ),
        ],
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: colors.muted)),
    );
  }
}
