import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
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

/// Localized meal name; [mealLabel] stays for screens not yet translated.
String mealText(BuildContext context, String? meal) => switch (meal) {
      'breakfast' => context.t('nutrition:breakfast'),
      'lunch' => context.t('nutrition:lunch'),
      'dinner' => context.t('nutrition:dinner'),
      'snack' => context.t('nutrition:snack'),
      'post_workout' => context.t('nutrition:postworkout'),
      _ => context.t('nutrition:other'),
    };

IconData _mealIcon(String meal) => switch (meal) {
      'breakfast' => Icons.wb_twilight_outlined,
      'lunch' => Icons.lunch_dining_outlined,
      'dinner' => Icons.nights_stay_outlined,
      'snack' => Icons.cookie_outlined,
      'post_workout' => Icons.fitness_center,
      _ => Icons.restaurant,
    };

String _n(num v) => NumberFormat.decimalPattern().format(v.round());

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  DateTime _day = dayOnly(DateTime.now());
  bool _showMicro = false;
  bool _week = false;
  final Set<String> _collapsed = {};

  bool get _isToday => _day == dayOnly(DateTime.now());

  void _shift(int days) =>
      setState(() => _day = dayOnly(_day.add(Duration(days: days))));

  final Set<String> _xpBusy = {};

  /// Daily nutrition goal bonuses: protein +20 XP, calories +15 XP, each
  /// once per day. Mirrors the React Native dashboard awards.
  void _awardDailyGoalXp(NutritionTotals totals, GoalTargets goals) {
    _awardGoalXp('protein', totals.proteinG, goals.protein, 20);
    _awardGoalXp('calories', totals.calories, goals.calories, 15);
  }

  /// Awards [xp] the first time [current] reaches [goal] on the shown day.
  void _awardGoalXp(String name, double current, double goal, int xp) {
    if (_xpBusy.contains(name) || !_isToday || goal <= 0 || current < goal) {
      return;
    }
    _xpBusy.add(name);
    () async {
      final prefs = await SharedPreferences.getInstance();
      final key =
          'fittrack_${name}_xp_${DateFormat('yyyy-MM-dd').format(_day)}';
      if (prefs.getBool(key) == true) {
        return;
      }
      await prefs.setBool(key, true);
      await ref.read(gamificationServiceProvider)?.awardXp(xp);
    }()
        .catchError((Object _) {})
        .whenComplete(() => _xpBusy.remove(name));
  }

  Future<void> _delete(NutritionLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    final message =
        context.t('nutrition:removedFood', args: {'name': log.foodName});
    await ref.read(nutritionServiceProvider)?.deleteLog(log.id);
    ref.invalidate(nutritionDayProvider(_day));
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(NutritionLog log) async {
    final controller =
        TextEditingController(text: log.quantityG.round().toString());
    final grams = await showDialog<double>(
      context: context,
      barrierColor: AppTheme.scrim,
      builder: (ctx) => AlertDialog(
        title: Text(log.foodName),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: ctx.t('nutrition:unitG'),
            labelText: ctx.t('nutrition:quantity'),
          ),
        ),
        actions: [
          FitTrackButton(
            label: ctx.t('common:cancel'),
            variant: FitTrackButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FitTrackButton(
            label: ctx.t('common:save'),
            onPressed: () =>
                Navigator.of(ctx).pop(double.tryParse(controller.text.trim())),
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
    context
        .push(Uri(path: '/nutrition/log', queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logs = ref.watch(nutritionDayProvider(_day));
    final goals =
        ref.watch(goalTargetsProvider).valueOrNull ?? const GoalTargets();

    final header = _Header(
      day: _day,
      isToday: _isToday,
      onPrev: () => _shift(_week ? -7 : -1),
      onNext: _isToday && !_week ? null : () => _shift(_week ? 7 : 1),
      onToday: () => setState(() => _day = dayOnly(DateTime.now())),
    );

    Widget top(Widget? summary) {
      final heroH = isDark ? 118.0 : 170.0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroH,
            child: const _PlateHero(),
          ),
          Positioned(top: 0, left: 0, right: 0, child: header),
          if (summary == null)
            SizedBox(height: heroH)
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                FitTrackSpacing.lg,
                heroH - 52,
                FitTrackSpacing.lg,
                0,
              ),
              child: summary,
            ),
        ],
      );
    }

    final tabs = Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.lg,
        FitTrackSpacing.md,
        FitTrackSpacing.lg,
        0,
      ),
      child: FitTrackSegmentedTabs(
        labels: [
          context.t('nutrition:dayTab'),
          context.t('nutrition:weekTab'),
        ],
        selectedIndex: _week ? 1 : 0,
        onSelected: (i) => setState(() => _week = i == 1),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: context.t('nutrition:logFood'),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: c.accent,
        backgroundColor: c.surface,
        onRefresh: () async {
          ref.invalidate(nutritionDayProvider(_day));
          await ref.read(nutritionDayProvider(_day).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            bottom: FitTrackSpacing.tabBarClearance - 60 + 36,
          ),
          children: [
            ...logs.when<List<Widget>>(
              loading: () => [
                top(null),
                tabs,
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: c.accent),
                  ),
                ),
              ],
              error: (_, __) => [
                top(null),
                tabs,
                _Info(text: context.t('nutrition:unableLoad')),
              ],
              data: (items) {
                final totals = NutritionTotals.fromLogs(items);
                final fiber =
                    items.fold<double>(0, (s, l) => s + (l.fiberG ?? 0));
                _awardDailyGoalXp(totals, goals);
                final micro = sumMicronutrients(
                    [for (final l in items) l.micronutrients]);
                final groups = groupByMeal(items);
                final macros = [
                  _Macro(context.t('nutrition:protein'), totals.proteinG,
                      goals.protein),
                  _Macro(context.t('nutrition:carbs'), totals.carbsG,
                      goals.carbs),
                  _Macro(context.t('nutrition:fat'), totals.fatG, goals.fat),
                  _Macro(context.t('nutrition:fiber'), fiber, goals.fiber),
                ];
                final summary = _PearlSummary(
                  totals: totals,
                  goals: goals,
                  macros: macros,
                );
                return [
                  top(isDark || _week ? null : summary),
                  tabs,
                  if (_week)
                    _WeekList(
                      weekStart: _day.subtract(
                        Duration(days: _day.weekday - DateTime.monday),
                      ),
                      goals: goals,
                      onPick: (d) => setState(() {
                        _day = d;
                        _week = false;
                      }),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: FitTrackSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isDark)
                            _NightStats(
                              totals: totals,
                              goals: goals,
                              macros: macros,
                            ),
                          _Pad(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isDark)
                                  const SizedBox(height: FitTrackSpacing.md),
                                if (micro.isNotEmpty) ...[
                                  _MicroCard(
                                    totals: micro,
                                    expanded: _showMicro,
                                    onToggle: () => setState(
                                      () => _showMicro = !_showMicro,
                                    ),
                                  ),
                                  const SizedBox(height: FitTrackSpacing.md),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: FitTrackButton(
                                        label: context.t('nutrition:logFood'),
                                        icon: Icons.edit_outlined,
                                        fullWidth: true,
                                        onPressed: _add,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: FitTrackButton(
                                        label: context.t('nutrition:scanShort'),
                                        icon: Icons.qr_code_scanner,
                                        variant: FitTrackButtonVariant.secondary,
                                        fullWidth: true,
                                        onPressed: () =>
                                            context.push('/nutrition/scan'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: FitTrackButton(
                                        label:
                                            context.t('nutrition:photoShort'),
                                        icon: Icons.photo_camera_outlined,
                                        variant: FitTrackButtonVariant.secondary,
                                        fullWidth: true,
                                        onPressed: () =>
                                            context.push('/nutrition/photo'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FitTrackSpacing.md),
                                if (items.isEmpty) ...[
                                  _Empty(onTap: _add),
                                  const SizedBox(height: FitTrackSpacing.md),
                                ],
                                for (final meal in [
                                  for (final m in mealOrder)
                                    if (m != 'post_workout' ||
                                        groups.containsKey(m))
                                      m,
                                  if (groups.containsKey('other')) 'other',
                                ]) ...[
                                  if (groups[meal] == null)
                                    _EmptyMeal(
                                      meal: meal,
                                      remainingKcal:
                                          goals.calories - totals.calories,
                                      remainingProtein:
                                          goals.protein - totals.proteinG,
                                      isDark: isDark,
                                      onAdd: () => _add(meal),
                                    )
                                  else
                                    _MealCard(
                                      meal: meal,
                                      items: groups[meal]!,
                                      isDark: isDark,
                                      collapsed: _collapsed.contains(meal),
                                      onToggle: () => setState(() {
                                        if (!_collapsed.remove(meal)) {
                                          _collapsed.add(meal);
                                        }
                                      }),
                                      onAdd: () =>
                                          _add(meal == 'other' ? null : meal),
                                      onDelete: _delete,
                                      onEdit: _edit,
                                    ),
                                  const SizedBox(height: FitTrackSpacing.md),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.lg),
        child: child,
      );
}

class _Macro {
  const _Macro(this.label, this.value, this.goal);
  final String label;
  final double value;
  final double goal;
  double get progress =>
      goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0.0;
}

/// Decorative hero behind the header (tokens only).
class _PlateHero extends StatelessWidget {
  const _PlateHero();

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return ExcludeSemantics(
      child: Container(
        color: c.line,
        child: CustomPaint(
          painter: _PlatePainter(
            ring: c.lineStrong,
            plate: c.surface,
            dot: c.accentSoft,
            accent: c.accent,
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({
    required this.ring,
    required this.plate,
    required this.dot,
    required this.accent,
  });
  final Color ring;
  final Color plate;
  final Color dot;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width - 70;
    final cy = size.height * 0.52;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ring;
    canvas
      ..drawCircle(Offset(cx, cy), 92, stroke)
      ..drawCircle(Offset(cx, cy), 68, Paint()..color = plate.withValues(alpha: .92))
      ..drawCircle(Offset(cx, cy), 48, stroke..color = ring.withValues(alpha: .7));
    final fill = Paint()..color = dot;
    canvas
      ..drawCircle(Offset(cx - 14, cy - 10), 13, fill)
      ..drawCircle(Offset(cx + 14, cy - 14), 13, fill)
      ..drawCircle(Offset(cx, cy + 14), 13, fill)
      ..drawCircle(Offset(cx + 28, cy + 18), 9, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.ring != ring ||
      old.plate != plate ||
      old.dot != dot ||
      old.accent != accent;
}

class _Header extends StatelessWidget {
  const _Header({
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
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.xl,
        FitTrackSpacing.lg,
        FitTrackSpacing.sm,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM').format(day),
                  style: FitTrackText.label.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  context.t('nutrition:foodLog'),
                  style: FitTrackText.statLg.copyWith(color: c.ink),
                ),
              ],
            ),
          ),
          if (!isToday)
            FitTrackButton(
              label: context.t('nutrition:todayLabel'),
              variant: FitTrackButtonVariant.ghost,
              size: FitTrackButtonSize.sm,
              onPressed: onToday,
            ),
          FitTrackIconButton(
            icon: Icons.chevron_left,
            semanticLabel: context.t('nutrition:previousDay'),
            color: c.ink,
            onPressed: onPrev,
          ),
          Opacity(
            opacity: onNext == null ? .6 : 1,
            child: FitTrackIconButton(
              icon: Icons.chevron_right,
              semanticLabel: context.t('nutrition:nextDay'),
              color: onNext == null ? c.muted : c.ink,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

/// Night: horizontally scrolling stat cards (calories left filled).
class _NightStats extends StatelessWidget {
  const _NightStats({
    required this.totals,
    required this.goals,
    required this.macros,
  });
  final NutritionTotals totals;
  final GoalTargets goals;
  final List<_Macro> macros;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final left = (goals.calories - totals.calories).round();
    final pct = goals.calories > 0
        ? (totals.calories / goals.calories).clamp(0, 1).toDouble()
        : 0.0;
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.lg),
        children: [
          Container(
            width: 156,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(FitTrackRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('nutrition:caloriesLeft'),
                  style: FitTrackText.caption.copyWith(
                    color: c.onAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  left > 0 ? _n(left) : '0',
                  style: FitTrackText.statLg.copyWith(color: c.onAccent),
                ),
                Text(
                  left > 0
                      ? context.t(
                          'nutrition:ofGoalKcal',
                          args: {'goal': _n(goals.calories)},
                        )
                      : context.t('nutrition:goalReached'),
                  style: FitTrackText.caption.copyWith(color: c.onAccent),
                ),
                Text(
                  context.t(
                    'nutrition:eatenKcal',
                    args: {'kcal': _n(totals.calories)},
                  ),
                  style: FitTrackText.caption.copyWith(color: c.onAccent),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Container(height: 5, color: c.onAccent.withValues(alpha: .3)),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(height: 5, color: c.onAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final m in macros) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 156,
              child: FitTrackCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${m.value.round()} ${context.t('nutrition:unitG')}',
                      style: FitTrackText.statLg.copyWith(color: c.ink),
                    ),
                    Text(
                      context.t(
                        'nutrition:ofGoalG',
                        args: {'goal': m.goal.round()},
                      ),
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                    const Spacer(),
                    FitTrackProgressBar(
                      progress: m.progress,
                      semanticLabel: m.label,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pearl: ring with calories left beside the macro bars.
class _PearlSummary extends StatelessWidget {
  const _PearlSummary({
    required this.totals,
    required this.goals,
    required this.macros,
  });
  final NutritionTotals totals;
  final GoalTargets goals;
  final List<_Macro> macros;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final left = (goals.calories - totals.calories).round();
    final pct = goals.calories > 0
        ? (totals.calories / goals.calories).clamp(0, 1).toDouble()
        : 0.0;
    return Semantics(
      container: true,
      label: context.t('nutrition:dailyProgress'),
      child: FitTrackCard(
        child: Row(
          children: [
            FitTrackStatRing(
              size: 118,
              strokeWidth: 11,
              progress: pct,
              color: c.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    left > 0 ? _n(left) : '0',
                    style: FitTrackText.stat.copyWith(color: c.ink),
                  ),
                  Text(
                    left > 0
                        ? context.t('nutrition:kcalLeft')
                        : context.t('nutrition:goalReached'),
                    style: FitTrackText.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  for (final m in macros) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          m.label,
                          style: FitTrackText.label.copyWith(
                            color: c.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            text: '${m.value.round()}',
                            style: FitTrackText.label.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    ' / ${m.goal.round()} ${context.t('nutrition:unitG')}',
                                style: FitTrackText.label.copyWith(
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FitTrackProgressBar(
                      progress: m.progress,
                      semanticLabel: m.label,
                    ),
                    if (m != macros.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekList extends ConsumerWidget {
  const _WeekList({
    required this.weekStart,
    required this.goals,
    required this.onPick,
  });
  final DateTime weekStart;
  final GoalTargets goals;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.lg,
        FitTrackSpacing.md,
        FitTrackSpacing.lg,
        0,
      ),
      child: FitTrackCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < 7; i++)
              Builder(builder: (context) {
                final date = dayOnly(weekStart.add(Duration(days: i)));
                final logs =
                    ref.watch(nutritionDayProvider(date)).valueOrNull;
                final totals = logs == null
                    ? null
                    : NutritionTotals.fromLogs(logs);
                final pct = totals == null || goals.calories <= 0
                    ? 0.0
                    : (totals.calories / goals.calories)
                        .clamp(0, 1)
                        .toDouble();
                return InkWell(
                  onTap: () => onPick(date),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.symmetric(
                      horizontal: FitTrackSpacing.lg,
                      vertical: FitTrackSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            DateFormat('EEE d').format(date),
                            style: FitTrackText.body.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: FitTrackProgressBar(
                            progress: pct,
                            semanticLabel: DateFormat('EEEE d').format(date),
                          ),
                        ),
                        const SizedBox(width: FitTrackSpacing.md),
                        SizedBox(
                          width: 92,
                          child: Text(
                            totals == null
                                ? '—'
                                : '${_n(totals.calories)} ${context.t('nutrition:unitKcal')}',
                            textAlign: TextAlign.end,
                            style: FitTrackText.label.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
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
    final c = AppPalette.of(context);
    final tracked = [
      for (final e in allRda)
        if (totals.containsKey(e.key)) e
    ];
    final avg = tracked.fold<double>(
          0,
          (s, e) => s + (totals[e.key]! / e.rda).clamp(0, 1).toDouble(),
        ) /
        tracked.length;
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: context.t('nutrition:vitamins'),
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.medication_outlined, color: c.ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('nutrition:vitamins'),
                            style: FitTrackText.body.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            context.t(
                              'nutrition:microSummary',
                              args: {
                                'count': tracked.length,
                                'pct': (avg * 100).round(),
                              },
                            ),
                            style:
                                FitTrackText.caption.copyWith(color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: c.muted,
                    ),
                  ],
                ),
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
                              style: FitTrackText.caption.copyWith(color: c.ink),
                            ),
                          ),
                          Expanded(
                            child: FitTrackProgressBar(
                              progress: (totals[e.key]! / e.rda)
                                  .clamp(0, 1)
                                  .toDouble(),
                              color: c.ok,
                              semanticLabel: e.label,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 84,
                            child: Text(
                              '${totals[e.key]!.toStringAsFixed(1)} / ${e.rda % 1 == 0 ? e.rda.round() : e.rda} ${e.unit}',
                              textAlign: TextAlign.end,
                              style:
                                  FitTrackText.caption.copyWith(color: c.muted),
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

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.items,
    required this.isDark,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
  });
  final String meal;
  final List<NutritionLog> items;
  final bool isDark;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final ValueChanged<NutritionLog> onDelete;
  final ValueChanged<NutritionLog> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final kcal = items.fold<double>(0, (s, l) => s + (l.calories ?? 0));
    final protein = items.fold<double>(0, (s, l) => s + l.proteinG);
    final name = mealText(context, meal);
    final addButton = FitTrackIconButton(
      icon: Icons.add,
      semanticLabel: context.t('nutrition:addTo', args: {'meal': name}),
      color: isDark ? c.accent : c.ink,
      style: FitTrackIconButtonStyle.filled,
      onPressed: onAdd,
    );
    final header = isDark
        ? Container(
            height: 48,
            color: c.accentSoft,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: name,
                      style: FitTrackText.body.copyWith(
                        color: c.accent,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text:
                              ' · ${_n(kcal)} ${context.t('nutrition:unitKcal')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                addButton,
              ],
            ),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsetsDirectional.only(start: 16, end: 2),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                  child: Icon(_mealIcon(meal), size: 20, color: c.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: FitTrackText.titleLg.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.t(
                          'nutrition:mealSummary',
                          args: {'kcal': _n(kcal), 'protein': protein.round()},
                        ),
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                addButton,
                FitTrackIconButton(
                  icon: collapsed ? Icons.expand_more : Icons.expand_less,
                  semanticLabel: context.t(
                    collapsed ? 'nutrition:expandMeal' : 'nutrition:collapseMeal',
                    args: {'meal': name},
                  ),
                  color: c.ink,
                  onPressed: onToggle,
                ),
              ],
            ),
          );
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FitTrackRadius.lg - 1),
        child: Column(
          children: [
            header,
            if (isDark || !collapsed)
              for (final item in items)
                Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    color: c.bad,
                    child: Icon(Icons.delete_outline, color: c.bg),
                  ),
                  onDismissed: (_) => onDelete(item),
                  child: _LogRow(
                    item: item,
                    thumb: isDark ? 36 : 40,
                    onTap: () => onEdit(item),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.item,
    required this.thumb,
    required this.onTap,
  });
  final NutritionLog item;
  final double thumb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Row(
            children: [
              Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(FitTrackRadius.md),
                ),
                child: Icon(Icons.restaurant, size: 18, color: c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.title.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.t(
                        'nutrition:logCaption',
                        args: {
                          'qty': item.quantityG.round(),
                          'protein': item.proteinG.toStringAsFixed(1),
                        },
                      ),
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              if (item.calories != null)
                Text(
                  '${item.calories!.round()}',
                  style: FitTrackText.title.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMeal extends StatelessWidget {
  const _EmptyMeal({
    required this.meal,
    required this.remainingKcal,
    required this.remainingProtein,
    required this.isDark,
    required this.onAdd,
  });
  final String meal;
  final double remainingKcal;
  final double remainingProtein;
  final bool isDark;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final name = mealText(context, meal);
    final plan = remainingKcal > 0
        ? context.t(
            'nutrition:toPlan',
            args: {
              'kcal': _n(remainingKcal),
              'protein': remainingProtein > 0 ? remainingProtein.round() : 0,
            },
          )
        : null;
    return FitTrackCard(
      onTap: onAdd,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
      child: Row(
        children: [
          if (!isDark) ...[
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: Icon(_mealIcon(meal), size: 20, color: c.ink),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: FitTrackText.title.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (plan != null)
                  Text(plan, style: FitTrackText.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FitTrackButton(
            label: context.t('nutrition:addShort'),
            size: FitTrackButtonSize.pill,
            onPressed: onAdd,
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
    final c = AppPalette.of(context);
    return FitTrackCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.restaurant, size: 32, color: c.muted),
          const SizedBox(height: 10),
          Text(
            context.t('nutrition:nothingLogged'),
            style: FitTrackText.title.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('nutrition:emptyDesc'),
            textAlign: TextAlign.center,
            style: FitTrackText.caption.copyWith(color: c.muted),
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
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FitTrackCard(
        padding: const EdgeInsets.all(FitTrackSpacing.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: FitTrackText.body.copyWith(color: c.muted),
        ),
      ),
    );
  }
}
