import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../data/food_search_service.dart';
import '../domain/food_result.dart';
import '../domain/nutrition_models.dart';
import 'nutrition_screen.dart';

/// Favorites as [FoodResult]s.
final favoriteFoodsProvider =
    FutureProvider.autoDispose<List<FoodResult>>((ref) async {
  final service = ref.watch(nutritionServiceProvider);
  if (service == null) {
    return const [];
  }
  final rows = await service.favorites();
  return [
    for (final r in rows)
      FoodResult(
        name: r['food_name'] as String,
        proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
        caloriesPer100g: (r['calories_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (r['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (r['fat_per_100g'] as num?)?.toDouble(),
        source: FoodSource.favorite,
      ),
  ];
});

/// Foods logged over the last three days, newest first, one row per food.
final recentFoodsProvider = Provider.autoDispose<List<NutritionLog>>((ref) {
  final today = dayOnly(DateTime.now());
  final logs = <NutritionLog>[
    for (var i = 0; i < 3; i++)
      ...ref
              .watch(
                nutritionDayProvider(
                  DateTime(today.year, today.month, today.day - i),
                ),
              )
              .valueOrNull ??
          const <NutritionLog>[],
  ]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  final seen = <String>{};
  return [
    for (final l in logs)
      if (l.quantityG > 0 && seen.add(l.foodName)) l,
  ].take(5).toList();
});

/// A logged entry as a per-100 g [FoodResult], for "add again".
FoodResult foodFromLog(NutritionLog l) {
  final k = 100 / l.quantityG;
  double? s(double? v) => v == null ? null : v * k;
  return FoodResult(
    name: l.foodName,
    proteinPer100g: l.proteinG * k,
    caloriesPer100g: s(l.calories),
    carbsPer100g: s(l.carbsG),
    fatPer100g: s(l.fatG),
    source: FoodSource.local,
  );
}

String defaultMealForNow(DateTime now) {
  final h = now.hour;
  if (h < 11) {
    return 'breakfast';
  }
  if (h < 15) {
    return 'lunch';
  }
  if (h < 18) {
    return 'snack';
  }
  return 'dinner';
}

/// Timestamp to store: now for today, midday for other days.
DateTime logTimestamp(DateTime day, DateTime now) {
  if (dayOnly(day) == dayOnly(now)) {
    return now;
  }
  return DateTime(day.year, day.month, day.day, 12);
}

/// Add food: search (Indian list, OpenFoodFacts, USDA), favorites, recent
/// foods, barcode, photo scan or quick (manual) add.
class FoodLogScreen extends ConsumerStatefulWidget {
  const FoodLogScreen({this.meal, this.date, this.initialFood, super.key});
  final String? meal;
  final DateTime? date;
  final FoodResult? initialFood;

  @override
  ConsumerState<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends ConsumerState<FoodLogScreen> {
  late String _meal;
  late final DateTime _day;
  String _query = '';
  Timer? _debounce;
  List<FoodResult> _results = const [];
  bool _searching = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = dayOnly(widget.date ?? now);
    _meal =
        mealOrder.contains(widget.meal) ? widget.meal! : defaultMealForNow(now);
    _results = searchLocalFoods(_query);
    final initial = widget.initialFood;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _select(initial);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    _query = value;
    _debounce?.cancel();
    setState(() => _results = searchLocalFoods(_query));
    if (value.trim().length < 2) {
      setState(() => _searching = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _remote);
  }

  Future<void> _remote() async {
    final token = ++_searchToken;
    setState(() => _searching = true);
    final results = await ref.read(foodSearchServiceProvider).search(_query);
    if (!mounted || token != _searchToken) {
      return;
    }
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _select(FoodResult food, {double grams = 100}) async {
    final favorites = ref.read(favoriteFoodsProvider).valueOrNull ?? const [];
    final result = await showFitTrackSheet<_LogRequest>(
      context: context,
      builder: (_) => _QuantitySheet(
        food: food,
        meal: _meal,
        initialGrams: grams,
        isFavorite: favorites.any((f) => f.name == food.displayName),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _save(result);
  }

  Future<void> _quickAdd() async {
    final result = await showFitTrackSheet<_LogRequest>(
      context: context,
      builder: (_) => _ManualForm(meal: _meal),
    );
    if (result == null || !mounted) {
      return;
    }
    await _save(result);
  }

  Future<void> _save(_LogRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final signIn = context.t('nutrition:signInToLog');
    final logged = context.t(
      'nutrition:loggedFood',
      args: {'name': request.food.displayName},
    );
    final service = ref.read(nutritionServiceProvider);
    if (service == null) {
      messenger.showSnackBar(SnackBar(content: Text(signIn)));
      return;
    }
    final scaled = scaleFood(request.food, request.quantityG);
    await service.logFood(
      foodName: request.food.displayName,
      mealType: request.meal,
      quantityG: scaled.quantityG,
      proteinG: scaled.protein,
      fatG: scaled.fat,
      carbsG: scaled.carbs,
      calories: scaled.calories,
      loggedAt: logTimestamp(_day, DateTime.now()),
      micronutrients:
          scaled.micronutrients.isEmpty ? null : scaled.micronutrients,
    );
    if (request.favorite) {
      await service.addFavorite(
        name: request.food.displayName,
        brand: request.food.brand,
        proteinPer100g: request.food.proteinPer100g,
        caloriesPer100g: request.food.caloriesPer100g,
        carbsPer100g: request.food.carbsPer100g,
        fatPer100g: request.food.fatPer100g,
      );
      ref.invalidate(favoriteFoodsProvider);
    }
    ref.invalidate(nutritionDayProvider(_day));
    messenger.showSnackBar(SnackBar(content: Text(logged)));
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final favorites = ref.watch(favoriteFoodsProvider);
    final recent = ref.watch(recentFoodsProvider);
    final fromLocal =
        _results.isNotEmpty && _results.every((f) => f.source == FoodSource.local);
    const gap = SizedBox(height: FitTrackSpacing.md);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: c.line)),
        toolbarHeight: 64,
        titleSpacing: 0,
        leading: FitTrackIconButton(
          icon: Icons.arrow_back,
          semanticLabel: context.t('nutrition:goBackLink'),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('nutrition:addFoodTitle'),
              style: FitTrackText.titleLg.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(_day),
              style: FitTrackText.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          FitTrackSpacing.lg,
          FitTrackSpacing.md,
          FitTrackSpacing.lg,
          FitTrackSpacing.xxl,
        ),
        children: [
          SizedBox(
            height: FitTrackSpacing.touchMin,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in mealOrder)
                  Padding(
                    padding: const EdgeInsets.only(right: FitTrackSpacing.sm),
                    child: FitTrackChip(
                      label: mealText(context, m),
                      selected: _meal == m,
                      onTap: () => setState(() => _meal = m),
                    ),
                  ),
              ],
            ),
          ),
          gap,
          _SearchField(onChanged: _onQuery),
          if (_searching)
            Padding(
              padding: const EdgeInsets.only(top: FitTrackSpacing.sm),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: c.accent,
                backgroundColor: c.line,
              ),
            ),
          gap,
          Row(
            children: [
              Expanded(
                child: _MethodTile(
                  title: context.t('nutrition:methodBarcode'),
                  caption: context.t('nutrition:methodBarcodeDesc'),
                  onTap: () => context.push('/nutrition/scan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodTile(
                  title: context.t('nutrition:methodPhoto'),
                  caption: context.t('nutrition:methodPhotoDesc'),
                  onTap: () => context.push('/nutrition/photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodTile(
                  title: context.t('nutrition:methodQuick'),
                  caption: context.t('nutrition:methodQuickDesc'),
                  onTap: _quickAdd,
                ),
              ),
            ],
          ),
          gap,
          _ListCard(
            title: context.t('nutrition:resultsTitle'),
            trailing: context.t(
              fromLocal ? 'nutrition:sourceIndian' : 'nutrition:sourceSearch',
            ),
            emptyText: _searching
                ? context.t('nutrition:searching')
                : context.t('nutrition:noFoodsFound'),
            rows: [
              for (final food in _results)
                _FoodRow(
                  key: ValueKey('r-${food.displayName}-${food.source.name}'),
                  title: food.displayName,
                  caption: _foodCaption(context, food),
                  badge: _sourceCode(context, food.source),
                  addLabel: context.t(
                    'nutrition:addNamed',
                    args: {'name': food.displayName},
                  ),
                  onTap: () => _select(food),
                ),
            ],
          ),
          gap,
          favorites.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _ListCard(
              title: context.t('nutrition:favoritesTitle'),
              emptyText: context.t('nutrition:favoritesLoadFailed'),
              rows: const [],
            ),
            data: (list) => _ListCard(
              title: context.t('nutrition:favoritesTitle'),
              emptyText: context.t('nutrition:favoritesEmpty'),
              rows: [
                for (final food in list)
                  Dismissible(
                    key: ValueKey('f-${food.name}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding:
                          const EdgeInsets.only(right: FitTrackSpacing.xl),
                      color: c.bad,
                      child: Icon(Icons.delete_outline, color: c.surface),
                    ),
                    onDismissed: (_) async {
                      final service = ref.read(nutritionServiceProvider);
                      final rows = await service?.favorites() ?? const [];
                      for (final r in rows) {
                        if (r['food_name'] == food.name) {
                          await service?.removeFavorite(r['id'] as String);
                        }
                      }
                      ref.invalidate(favoriteFoodsProvider);
                    },
                    child: _FoodRow(
                      title: food.displayName,
                      caption: _foodCaption(context, food),
                      addLabel: context.t(
                        'nutrition:addNamed',
                        args: {'name': food.displayName},
                      ),
                      onTap: () => _select(food),
                    ),
                  ),
              ],
            ),
          ),
          if (recent.isNotEmpty) ...[
            gap,
            _ListCard(
              title: context.t('nutrition:recentTitle'),
              emptyText: '',
              rows: [
                for (final l in recent)
                  _FoodRow(
                    key: ValueKey('c-${l.foodName}'),
                    title: l.foodName,
                    caption: l.calories == null
                        ? context.t(
                            'nutrition:recentCaptionNoKcal',
                            args: {'qty': l.quantityG.round()},
                          )
                        : context.t(
                            'nutrition:recentCaption',
                            args: {
                              'qty': l.quantityG.round(),
                              'kcal': l.calories!.round(),
                            },
                          ),
                    addLabel: context.t(
                      'nutrition:addAgain',
                      args: {'name': l.foodName},
                    ),
                    onTap: () =>
                        _select(foodFromLog(l), grams: l.quantityG),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _foodCaption(BuildContext context, FoodResult food) {
  final protein = food.proteinPer100g.toStringAsFixed(1);
  return food.caloriesPer100g == null
      ? context.t('nutrition:foodCaptionNoKcal', args: {'protein': protein})
      : context.t(
          'nutrition:foodCaption',
          args: {'kcal': food.caloriesPer100g!.round(), 'protein': protein},
        );
}

String _sourceCode(BuildContext context, FoodSource source) =>
    switch (source) {
      FoodSource.local => context.t('nutrition:srcLocal'),
      FoodSource.openFoodFacts => context.t('nutrition:srcOff'),
      FoodSource.usda => context.t('nutrition:srcUsda'),
      FoodSource.favorite => context.t('nutrition:srcFav'),
    };

class _LogRequest {
  const _LogRequest({
    required this.food,
    required this.quantityG,
    required this.meal,
    required this.favorite,
  });
  final FoodResult food;
  final double quantityG;
  final String meal;
  final bool favorite;
}

/// Always-visible search field (48px, strong border).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.lineStrong),
        borderRadius: BorderRadius.circular(FitTrackRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: context.t('nutrition:searchFoods'),
              textField: true,
              child: TextField(
                onChanged: onChanged,
                style: FitTrackText.body.copyWith(color: c.ink),
                cursorColor: c.accent,
                decoration: InputDecoration.collapsed(
                  hintText: context.t('nutrition:searchHint'),
                  hintStyle: FitTrackText.body.copyWith(color: c.muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barcode / Photo scan / Quick add entry tile.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.title,
    required this.caption,
    required this.onTap,
  });
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FitTrackSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FitTrackText.title.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: FitTrackSpacing.xs),
            Text(
              caption,
              style: FitTrackText.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with a 44px header (title left, source/caption right) and rows.
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.rows,
    required this.emptyText,
    this.trailing,
  });
  final String title;
  final String? trailing;
  final String emptyText;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: FitTrackSpacing.touchMin,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: FitTrackText.title.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Flexible(
                      child: Text(
                        trailing!,
                        textAlign: TextAlign.end,
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (rows.isEmpty && emptyText.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              padding: const EdgeInsets.all(FitTrackSpacing.lg),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: FitTrackText.body.copyWith(color: c.muted),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

/// One food row: name and caption, optional source badge, 32px add button.
class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.title,
    required this.caption,
    required this.addLabel,
    required this.onTap,
    this.badge,
    super.key,
  });
  final String title;
  final String caption;
  final String addLabel;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FitTrackText.title.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: FitTrackSpacing.sm),
                  FitTrackBadge(label: badge!),
                ],
                Semantics(
                  button: true,
                  label: addLabel,
                  child: ExcludeSemantics(
                    child: InkResponse(
                      onTap: onTap,
                      radius: 22,
                      child: SizedBox(
                        width: FitTrackSpacing.touchMin,
                        height: FitTrackSpacing.touchMin,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: c.accentText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({
    required this.food,
    required this.meal,
    required this.isFavorite,
    required this.initialGrams,
  });
  final FoodResult food;
  final String meal;
  final bool isFavorite;
  final double initialGrams;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final _controller =
      TextEditingController(text: widget.initialGrams.round().toString());
  late bool _favorite = widget.isFavorite;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _grams => double.tryParse(_controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final scaled = scaleFood(widget.food, _grams);
    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: FitTrackText.stat.copyWith(color: color),
              ),
              Text(
                label,
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
            ],
          ),
        );
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.food.displayName,
                  style: FitTrackText.titleLg.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FitTrackIconButton(
                icon: _favorite ? Icons.star : Icons.star_border,
                color: c.xpColor,
                semanticLabel: context.t('nutrition:favoriteToggle'),
                onPressed: () => setState(() => _favorite = !_favorite),
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.sm),
          FitTrackTextField(
            label: context.t('nutrition:quantityShort'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: Padding(
              padding: const EdgeInsets.all(FitTrackSpacing.md),
              child: Text(
                context.t('nutrition:unitG'),
                style: FitTrackText.body.copyWith(color: c.muted),
              ),
            ),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          Row(
            children: [
              stat(
                context.t('nutrition:statProteinG'),
                scaled.protein.toStringAsFixed(1),
                c.nutritionColor,
              ),
              stat(
                context.t('nutrition:statKcal'),
                scaled.calories?.round().toString() ?? '—',
                c.workoutColor,
              ),
              stat(
                context.t('nutrition:statCarbsG'),
                scaled.carbs?.toStringAsFixed(1) ?? '—',
                c.waterColor,
              ),
              stat(
                context.t('nutrition:statFatG'),
                scaled.fat?.toStringAsFixed(1) ?? '—',
                c.xpColor,
              ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.xl),
          FitTrackButton(
            label: context.t(
              'nutrition:logTo',
              args: {'meal': mealText(context, widget.meal)},
            ),
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            onPressed: _grams > 0
                ? () => Navigator.of(context).pop(
                      _LogRequest(
                        food: widget.food,
                        quantityG: _grams,
                        meal: widget.meal,
                        favorite: _favorite,
                      ),
                    )
                : null,
          ),
          const SizedBox(height: FitTrackSpacing.sm),
        ],
      ),
    );
  }
}

/// Quick add: enter a food and its values by hand.
class _ManualForm extends StatefulWidget {
  const _ManualForm({required this.meal});
  final String meal;

  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  final _name = TextEditingController();
  final _grams = TextEditingController(text: '100');
  final _protein = TextEditingController();
  final _calories = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String? _nameError;
  String? _gramsError;
  String? _proteinError;

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    _protein.dispose();
    _calories.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim());

  void _submit() {
    final required = context.t('nutrition:errRequired');
    final number = context.t('nutrition:errEnterNumber');
    final grams = _d(_grams);
    final protein = _d(_protein);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? required : null;
      _gramsError = grams == null || grams <= 0 ? number : null;
      _proteinError = protein == null || protein < 0 ? number : null;
    });
    if (_nameError != null || _gramsError != null || _proteinError != null) {
      return;
    }
    // Values were entered for the stated quantity; store them per 100 g.
    final per100 = 100 / grams!;
    double? scale(double? v) => v == null ? null : v * per100;
    Navigator.of(context).pop(
      _LogRequest(
        food: FoodResult(
          name: _name.text.trim(),
          proteinPer100g: protein! * per100,
          caloriesPer100g: scale(_d(_calories)),
          carbsPer100g: scale(_d(_carbs)),
          fatPer100g: scale(_d(_fat)),
          source: FoodSource.local,
        ),
        quantityG: grams,
        meal: widget.meal,
        favorite: false,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? error,
    bool number = true,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: FitTrackSpacing.md),
        child: FitTrackTextField(
          label: label,
          controller: c,
          errorText: error,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('nutrition:methodQuick'),
            style: FitTrackText.titleLg.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          _field(
            context.t('nutrition:fieldFoodName'),
            _name,
            error: _nameError,
            number: false,
          ),
          _field(
            context.t('nutrition:fieldQuantityG'),
            _grams,
            error: _gramsError,
          ),
          _field(
            context.t('nutrition:fieldProteinForQty'),
            _protein,
            error: _proteinError,
          ),
          _field(context.t('nutrition:fieldCalories'), _calories),
          _field(context.t('nutrition:fieldCarbs'), _carbs),
          _field(context.t('nutrition:fieldFat'), _fat),
          FitTrackButton(
            label: context.t('nutrition:logFoodAction'),
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            onPressed: _submit,
          ),
          const SizedBox(height: FitTrackSpacing.sm),
        ],
      ),
    );
  }
}
