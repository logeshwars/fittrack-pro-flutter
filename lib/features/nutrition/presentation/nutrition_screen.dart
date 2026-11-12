import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../settings/data/goal_targets.dart';
import '../domain/nutrition_models.dart';
import '../domain/rda.dart';

const mealOrder = [
  'breakfast',
  'lunch',
  'dinner',
  'snack',
  'post_workout',
];

String mealLabel(String? meal) => switch (meal) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snack',
      'post_workout' => 'Post-workout',
      _ => 'Other',
    };

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Logs for one calendar day (key must be a date-only value).
final nutritionDayProvider = FutureProvider.autoDispose
    .family<List<NutritionLog>, DateTime>((ref, day) async {
  final service = ref.watch(nutritionServiceProvider);
  if (service == null) {
    return const [];
  }
  final rows = await service.logsForDate(day);
  return [for (final row in rows) NutritionLog.fromJson(row)];
});

/// Groups logs by meal in display order; unknown meals land in "other".
Map<String, List<NutritionLog>> groupByMeal(List<NutritionLog> logs) {
  final groups = <String, List<NutritionLog>>{};
  for (final log in logs) {
    final key = mealOrder.contains(log.mealType) ? log.mealType! : 'other';
    groups.putIfAbsent(key, () => []).add(log);
  }
  final ordered = <String, List<NutritionLog>>{};
  for (final key in [...mealOrder, 'other']) {
    final items = groups[key];
    if (items != null) {
      ordered[key] = items;
    }
  }
  return ordered;
}

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  DateTime _day = dayOnly(DateTime.now());
  bool _showMicro = false;

  bool get _isToday => _day == dayOnly(DateTime.now());

  void _shift(int days) =>
      setState(() => _day = dayOnly(_day.add(Duration(days: days))));

  bool _xpBusy = false;

  /// +20 XP once per day when the protein goal is reached.
  void _awardProteinXp(double protein, double goal) {
    if (_xpBusy || !_isToday || goal <= 0 || protein < goal) {
      return;
    }
    _xpBusy = true;
    () async {
      final prefs = await SharedPreferences.getInstance();
      final key = 'fittrack_protein_xp_${DateFormat('yyyy-MM-dd').format(_day)}';
      if (prefs.getBool(key) == true) {
        return;
      }
      await prefs.setBool(key, true);
      await ref.read(gamificationServiceProvider)?.awardXp(20);
    }()
        .catchError((Object _) {})
        .whenComplete(() => _xpBusy = false);
  }

  Future<void> _delete(NutritionLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(nutritionServiceProvider)?.deleteLog(log.id);
    ref.invalidate(nutritionDayProvider(_day));
    messenger.showSnackBar(SnackBar(content: Text('Removed ${log.foodName}')));
  }

  Future<void> _edit(NutritionLog log) async {
    final controller = TextEditingController(text: log.quantityG.round().toString());
    final grams = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(log.foodName),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'g', labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (grams == null || grams <= 0 || log.quantityG <= 0) {
      return;
    }
    final f = grams / log.quantityG;
    double? scale(double? v) => v == null ? null : ((v * f) * 10).round() / 10;
    await ref.read(nutritionServiceProvider)?.updateLog(log.id, {
      'quantity_g': grams,
      'protein_g': scale(log.proteinG),
      'calories': log.calories == null ? null : (log.calories! * f).round(),
      'carbs_g': scale(log.carbsG),
      'fat_g': scale(log.fatG),
      'fiber_g': scale(log.fiberG),
      if (log.micronutrients.isNotEmpty)
        'micronutrients': scaleMicronutrients(log.micronutrients, 100 * f),
    });
    ref.invalidate(nutritionDayProvider(_day));
  }

  void _add([String? meal]) {
    final query = <String, String>{
      'date': DateFormat('yyyy-MM-dd').format(_day),
      if (meal != null) 'meal': meal,
    };
    context.push(Uri(path: '/nutrition/log', queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final logs = ref.watch(nutritionDayProvider(_day));
    final goals = ref.watch(goalTargetsProvider).valueOrNull ?? const GoalTargets();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: colors.accent,
        foregroundColor: colors.accentText,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(nutritionDayProvider(_day));
          await ref.read(nutritionDayProvider(_day).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            FitTrackScreenHeader(
              title: 'Nutrition',
              subtitle: DateFormat('EEEE, MMM d').format(_day),
              icon: Icons.restaurant,
            ),
            _DayBar(
              day: _day,
              isToday: _isToday,
              onPrev: () => _shift(-1),
              onNext: _isToday ? null : () => _shift(1),
              onToday: () => setState(() => _day = dayOnly(DateTime.now())),
            ),
            logs.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: colors.accent)),
              ),
              error: (_, __) => const _Info(text: 'Unable to load nutrition.'),
              data: (items) {
                final totals = NutritionTotals.fromLogs(items);
                final fiber = items.fold<double>(0, (s, l) => s + (l.fiberG ?? 0));
                _awardProteinXp(totals.proteinG, goals.protein);
                final micro = sumMicronutrients([for (final l in items) l.micronutrients]);
                final groups = groupByMeal(items);
                return Column(
                  children: [
                    _BudgetCard(totals: totals, fiber: fiber, goals: goals),
                    _MicroCard(
                      totals: micro,
                      expanded: _showMicro,
                      onToggle: () => setState(() => _showMicro = !_showMicro),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _add,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Log food'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/nutrition/scan'),
                              icon: const Icon(Icons.qr_code_scanner, size: 16),
                              label: const Text('Scan'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/nutrition/photo'),
                              icon: const Icon(Icons.photo_camera_outlined, size: 16),
                              label: const Text('Photo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items.isEmpty)
                      _Empty(onTap: _add)
                    else
                      for (final entry in groups.entries)
                        _MealGroup(
                          meal: entry.key,
                          items: entry.value,
                          onAdd: () => _add(entry.key == 'other' ? null : entry.key),
                          onDelete: _delete,
                          onEdit: _edit,
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

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });
  final DateTime day;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: onPrev,
            icon: Icon(Icons.chevron_left, color: colors.text),
          ),
          Expanded(
            child: Center(
              child: Text(
                isToday ? 'TODAY' : DateFormat('EEE · MMM d').format(day).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: colors.muted,
                ),
              ),
            ),
          ),
          if (!isToday)
            TextButton(onPressed: onToday, child: const Text('Today')),
          IconButton(
            tooltip: 'Next day',
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right,
              color: onNext == null ? colors.faint : colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.totals,
    required this.fiber,
    required this.goals,
  });
  final NutritionTotals totals;
  final double fiber;
  final GoalTargets goals;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final remaining = (goals.calories - totals.calories).round();
    final progress = goals.calories > 0 ? totals.calories / goals.calories : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  'DAILY BUDGET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FitTrackStatRing(
                      size: 124,
                      strokeWidth: 10,
                      progress: progress.clamp(0, 1).toDouble(),
                      color: AppColors.workout,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${totals.calories.round()}',
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
                            style: TextStyle(fontSize: 9, color: colors.faint),
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
                          const SizedBox(height: 10),
                          Text(
                            'DAILY GOAL',
                            style: TextStyle(fontSize: 9, color: colors.faint),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${NumberFormat.decimalPattern().format(goals.calories.round())} kcal',
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
          Divider(height: 1, color: colors.border2, indent: 16, endIndent: 16),
          _MacroRow(label: 'Protein', value: totals.proteinG, goal: goals.protein, color: AppColors.nutrition, icon: Icons.egg_alt_outlined),
          Divider(height: 1, color: colors.border2, indent: 16, endIndent: 16),
          _MacroRow(label: 'Fat', value: totals.fatG, goal: goals.fat, color: AppColors.xp, icon: Icons.opacity),
          Divider(height: 1, color: colors.border2, indent: 16, endIndent: 16),
          _MacroRow(label: 'Carbs', value: totals.carbsG, goal: goals.carbs, color: AppColors.water, icon: Icons.grain),
          Divider(height: 1, color: colors.border2, indent: 16, endIndent: 16),
          _MacroRow(label: 'Fiber', value: fiber, goal: goals.fiber, color: AppColors.recovery, icon: Icons.eco_outlined),
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
    final pct = goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0.0;
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

class _MicroCard extends StatelessWidget {
  const _MicroCard({
    required this.totals,
    required this.expanded,
    required this.onToggle,
  });
  final Map<String, double> totals;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = AppPalette.of(context);
    final tracked = [for (final e in allRda) if (totals.containsKey(e.key)) e];
    final avg = tracked.fold<double>(
          0,
          (s, e) => s + (totals[e.key]! / e.rda).clamp(0, 1).toDouble(),
        ) /
        tracked.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.medication_outlined, color: colors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vitamins & Minerals',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          '${tracked.length} tracked · avg ${(avg * 100).round()}% of RDA',
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  for (final e in tracked)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(
                              e.label,
                              style: TextStyle(fontSize: 12, color: colors.text),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (totals[e.key]! / e.rda).clamp(0, 1).toDouble(),
                                minHeight: 5,
                                backgroundColor: colors.border2,
                                valueColor: const AlwaysStoppedAnimation(AppColors.recovery),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 84,
                            child: Text(
                              '${totals[e.key]!.toStringAsFixed(1)} / ${e.rda % 1 == 0 ? e.rda.round() : e.rda} ${e.unit}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 10, color: colors.subtext),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MealGroup extends StatelessWidget {
  const _MealGroup({
    required this.meal,
    required this.items,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
  });
  final String meal;
  final List<NutritionLog> items;
  final VoidCallback onAdd;
  final ValueChanged<NutritionLog> onDelete;
  final ValueChanged<NutritionLog> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final kcal = items.fold<double>(0, (s, l) => s + (l.calories ?? 0));
    final protein = items.fold<double>(0, (s, l) => s + l.proteinG);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mealLabel(meal).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: AppColors.nutrition,
                  ),
                ),
              ),
              Text(
                '${kcal.round()} kcal · ${protein.round()} g protein',
                style: TextStyle(fontSize: 10, color: colors.muted),
              ),
              IconButton(
                tooltip: 'Add to ${mealLabel(meal)}',
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
                icon: Icon(Icons.add_circle_outline, size: 20, color: colors.accent),
              ),
            ],
          ),
          for (final item in items)
            Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.only(right: 20),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: colors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (_) => onDelete(item),
              child: _LogTile(item: item, onTap: () => onEdit(item)),
            ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.item, required this.onTap});
  final NutritionLog item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final calories = item.calories == null ? '' : ' · ${item.calories!.round()} kcal';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(width: 3, height: 64, color: AppColors.nutrition),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(Icons.restaurant, size: 36, color: colors.faint),
              const SizedBox(height: 10),
              Text(
                'Nothing logged yet',
                style: TextStyle(fontWeight: FontWeight.w800, color: colors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to log your first meal',
                style: TextStyle(fontSize: 12, color: colors.muted),
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
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
