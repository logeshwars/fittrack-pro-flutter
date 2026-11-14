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
import '../../../core/widgets/fittrack_icons.dart';

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
      'breakfast' => FitIcons.breakfast,
      'lunch' => FitIcons.lunch,
      'dinner' => FitIcons.dinner,
      'snack' => FitIcons.snack,
      'post_workout' => FitIcons.workout,
      _ => FitIcons.nutrition,
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

    final inset = MediaQuery.paddingOf(context).top;
    // Boards: the hero is 118 (Night) or 170 (Pearl) tall including a 44px
    // status bar; in Pearl the summary card rides 52px up over it.
    final heroH = inset + (isDark ? 74.0 : 126.0);

    Widget top(Widget? summary) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroH,
            child: _PlateHero(isDark: isDark, inset: inset),
          ),
          Positioned(top: inset, left: 0, right: 0, child: header),
          if (summary == null)
            SizedBox(height: heroH)
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                FitTrackSpacing.gutter,
                heroH - 52,
                FitTrackSpacing.gutter,
                0,
              ),
              child: summary,
            ),
        ],
      );
    }

    final tabs = Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.gutter,
        FitTrackSpacing.cardPad,
        FitTrackSpacing.gutter,
        0,
      ),
      child: FitTrackSegmentedTabs(
        hero: true,
        labels: [
          context.t('nutrition:dayTab'),
          context.t('nutrition:weekTab'),
        ],
        selectedIndex: _week ? 1 : 0,
        onSelected: (i) => setState(() => _week = i == 1),
      ),
    );

    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.surface,
      edgeOffset: inset,
      onRefresh: () async {
        ref.invalidate(nutritionDayProvider(_day));
        await ref.read(nutritionDayProvider(_day).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
        children: [
          ...logs.when<List<Widget>>(
            loading: () => [
              top(null),
              tabs,
              Padding(
                padding: const EdgeInsets.all(FitTrackSpacing.xxl),
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
              final micro =
                  sumMicronutrients([for (final l in items) l.micronutrients]);
              final groups = groupByMeal(items);
              final macros = [
                _Macro(context.t('nutrition:protein'), totals.proteinG,
                    goals.protein),
                _Macro(
                    context.t('nutrition:carbs'), totals.carbsG, goals.carbs),
                _Macro(context.t('nutrition:fat'), totals.fatG, goals.fat),
                _Macro(context.t('nutrition:fiber'), fiber, goals.fiber),
              ];
              final summary = _PearlSummary(
                totals: totals,
                goals: goals,
                macros: macros.take(3).toList(),
              );
              final gap = SizedBox(height: isDark ? 12 : 10);
              // Board order: breakfast, lunch, snack, dinner.
              final meals = [
                'breakfast',
                'lunch',
                'snack',
                'dinner',
                if (groups.containsKey('post_workout')) 'post_workout',
                if (groups.containsKey('other')) 'other',
              ];
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
                else ...[
                  if (isDark)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: FitTrackSpacing.cardPad),
                      child: _NightStats(
                        totals: totals,
                        goals: goals,
                        macros: macros,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      FitTrackSpacing.gutter,
                      isDark ? 16 : 14,
                      FitTrackSpacing.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final meal in meals) ...[
                          if (groups[meal] == null)
                            _EmptyMeal(
                              meal: meal,
                              remainingKcal: goals.calories - totals.calories,
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
                              onAdd: () => _add(meal == 'other' ? null : meal),
                              onDelete: _delete,
                              onEdit: _edit,
                            ),
                          gap,
                        ],
                        if (micro.isNotEmpty)
                          _MicroCard(
                            totals: micro,
                            expanded: _showMicro,
                            onToggle: () =>
                                setState(() => _showMicro = !_showMicro),
                          ),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _Macro {
  const _Macro(this.label, this.value, this.goal);
  final String label;
  final double value;
  final double goal;
  double get progress =>
      goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0.0;
}

/// Decorative hero behind the header: a plate drawn in rings.
class _PlateHero extends StatelessWidget {
  const _PlateHero({required this.isDark, required this.inset});
  final bool isDark;

  /// Height of the status bar; the art is placed below it.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [AppColors.heroDarkStart, AppColors.heroDarkEnd]
                : const [AppColors.heroLightStart, AppColors.heroLightEnd],
          ),
        ),
        child: ClipRect(
          child: CustomPaint(
            painter: _PlatePainter(
              ring: isDark ? AppColors.heroDarkRing : AppColors.heroLightDot,
              plate: c.surface,
              dot: c.accentSoft,
              accent: c.accent,
              inset: inset,
            ),
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
    required this.inset,
  });
  final Color ring;
  final Color plate;
  final Color dot;
  final Color accent;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    // Board: centre 70px from the right and 104px down a 44px status bar.
    final cx = size.width - 70;
    final cy = inset + 60;
    Paint stroke(double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ring.withValues(alpha: alpha);
    canvas
      ..drawCircle(Offset(cx, cy), 92, stroke(1))
      ..drawCircle(
        Offset(cx, cy),
        68,
        Paint()..color = plate.withValues(alpha: .92),
      )
      ..drawCircle(Offset(cx, cy), 48, stroke(.7));
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
      old.accent != accent ||
      old.inset != inset;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 36px disc on a wash of the surface, inside a 44px tap area.
    Widget round(IconData icon, String label, VoidCallback? onTap) =>
        Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          child: ExcludeSemantics(
            child: InkResponse(
              onTap: onTap,
              radius: 24,
              child: SizedBox(
                width: FitTrackSpacing.touchMin,
                height: FitTrackSpacing.touchMin,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface.withValues(alpha: 0.72),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: onTap == null ? c.muted : c.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        FitTrackSpacing.xl,
        FitTrackSpacing.md,
        FitTrackSpacing.cardPad,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitTrackText.label.copyWith(color: c.ink),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(
                    context.t('nutrition:foodLog'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (isDark
                            ? FitTrackText.display
                            : FitTrackText.macroStat)
                        .copyWith(color: c.ink, height: 1.1),
                  ),
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
          round(
            FitIcons.chevronLeft,
            context.t('nutrition:previousDay'),
            onPrev,
          ),
          round(
            FitIcons.chevronRight,
            context.t('nutrition:nextDay'),
            onNext,
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
    final radius = FitTrackRadius.hero(Theme.of(context).brightness);
    final left = (goals.calories - totals.calories).round();
    final pct = goals.calories > 0
        ? (totals.calories / goals.calories).clamp(0, 1).toDouble()
        : 0.0;
    final soft = c.onAccent.withValues(alpha: 0.9);
    return SizedBox(
      height: 122,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: FitTrackSpacing.gutter),
        children: [
          Semantics(
            container: true,
            label:
                '${context.t('nutrition:caloriesLeft')}, ${left > 0 ? _n(left) : 0}',
            child: ExcludeSemantics(
              child: Container(
                width: 156,
                padding: const EdgeInsets.all(FitTrackSpacing.cardPad),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('nutrition:caloriesLeft'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.caption.copyWith(
                        color: soft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      left > 0 ? _n(left) : '0',
                      style:
                          FitTrackText.macroStat.copyWith(color: c.onAccent),
                    ),
                    Text(
                      left > 0
                          ? context.t(
                              'nutrition:ofGoalKcal',
                              args: {'goal': _n(goals.calories)},
                            )
                          : context.t('nutrition:goalReached'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.caption.copyWith(color: soft),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          Container(
                            height: 5,
                            color: c.onAccent.withValues(alpha: .3),
                          ),
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
            ),
          ),
          for (final m in macros) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 156,
              child: FitTrackCard(
                radius: radius,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.macroStat.copyWith(color: c.ink),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            FitTrackRadius.hero(Theme.of(context).brightness),
          ),
          boxShadow: AppTheme.lift,
        ),
        child: FitTrackCard(
        radius: FitTrackRadius.hero(Theme.of(context).brightness),
        padding: const EdgeInsets.all(FitTrackSpacing.lg),
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
                    style: FitTrackText.ringStat.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 2),
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
                                  fontWeight: FontWeight.w500,
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
                    if (m != macros.last)
                      const SizedBox(height: FitTrackSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
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
        FitTrackSpacing.gutter,
        FitTrackSpacing.lg,
        FitTrackSpacing.gutter,
        0,
      ),
      child: FitTrackCard(
        radius: FitTrackRadius.hero(Theme.of(context).brightness),
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
                                ? '–'
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
      radius: FitTrackRadius.hero(Theme.of(context).brightness),
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
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(FitIcons.supplement, size: 20, color: c.accent),
                    ),
                    const SizedBox(width: FitTrackSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('nutrition:vitamins'),
                            style:
                                FitTrackText.titleHeavy.copyWith(color: c.ink),
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
                      expanded ? FitIcons.chevronUp : FitIcons.chevronDown,
                      size: 18,
                      color: c.ink,
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
    final radius = FitTrackRadius.hero(Theme.of(context).brightness);
    final addButton = FitTrackIconButton(
      icon: FitIcons.add,
      semanticLabel: context.t('nutrition:addTo', args: {'meal': name}),
      color: c.accent,
      onPressed: onAdd,
    );
    final header = isDark
        ? Container(
            height: 48,
            color: c.accentSoft,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        text: name,
                        children: [
                          TextSpan(
                            text:
                                ' · ${_n(kcal)} ${context.t('nutrition:unitKcal')}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.accent.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.rowTitle.copyWith(
                        color: c.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                addButton,
              ],
            ),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                  child: Icon(_mealIcon(meal), size: 20, color: c.accent),
                ),
                const SizedBox(width: FitTrackSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          name,
                          style: FitTrackText.section.copyWith(color: c.ink),
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
                  icon: collapsed ? FitIcons.chevronDown : FitIcons.chevronUp,
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
      radius: radius,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          header,
          if (isDark || !collapsed)
            for (var i = 0; i < items.length; i++)
              Dismissible(
                key: ValueKey(items[i].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: const EdgeInsetsDirectional.only(
                    end: FitTrackSpacing.xl,
                  ),
                  alignment: AlignmentDirectional.centerEnd,
                  color: c.bad,
                  child: Icon(FitIcons.delete, color: c.bg),
                ),
                onDismissed: (_) => onDelete(items[i]),
                child: _LogRow(
                  item: items[i],
                  meal: meal,
                  thumb: isDark ? 36 : 40,
                  // The Night header is tinted, so the first row needs no rule.
                  divider: !(isDark && i == 0),
                  onTap: () => onEdit(items[i]),
                ),
              ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.item,
    required this.meal,
    required this.thumb,
    required this.divider,
    required this.onTap,
  });
  final NutritionLog item;
  final String meal;
  final double thumb;
  final bool divider;
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
          padding: const EdgeInsets.symmetric(
            horizontal: FitTrackSpacing.lg,
            vertical: FitTrackSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: divider ? Border(top: BorderSide(color: c.line)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(thumb * 0.28),
                ),
                child: Icon(_mealIcon(meal), size: thumb * 0.5, color: c.accent),
              ),
              const SizedBox(width: FitTrackSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              if (item.calories != null) ...[
                const SizedBox(width: FitTrackSpacing.md),
                Text(
                  '${item.calories!.round()}',
                  style: FitTrackText.title.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
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
    final radius = FitTrackRadius.hero(Theme.of(context).brightness);
    final shape = BorderRadius.circular(radius);
    return Semantics(
      button: true,
      label: context.t('nutrition:addTo', args: {'meal': name}),
      child: ExcludeSemantics(
        child: Material(
          color: c.surface,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAdd,
            child: FitTrackDashedBorder(
              color: c.line,
              radius: radius,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: isDark ? 68 : 72),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
                  child: Row(
                    children: [
                      if (!isDark) ...[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(_mealIcon(meal), size: 20, color: c.accent),
                        ),
                        const SizedBox(width: FitTrackSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: (isDark
                                      ? FitTrackText.rowTitle
                                      : FitTrackText.section)
                                  .copyWith(
                                color: c.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (plan != null)
                              Text(
                                plan,
                                style: FitTrackText.caption
                                    .copyWith(color: c.muted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: FitTrackSpacing.md),
                      Container(
                        height: FitTrackSpacing.touchMin,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius:
                              BorderRadius.circular(FitTrackRadius.pill),
                        ),
                        child: Text(
                          context.t('nutrition:addShort'),
                          style: FitTrackText.label.copyWith(
                            color: c.onAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.gutter,
        FitTrackSpacing.gap,
        FitTrackSpacing.gutter,
        0,
      ),
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
