import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/food_search_service.dart';
import '../domain/food_result.dart';
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
        brand: r['brand'] as String?,
        proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
        caloriesPer100g: (r['calories_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (r['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (r['fat_per_100g'] as num?)?.toDouble(),
        source: FoodSource.favorite,
      ),
  ];
});

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

/// Add food: search (Indian list, OpenFoodFacts, USDA), favorites or manual.
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
  int _tab = 0;
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
    _meal = mealOrder.contains(widget.meal)
        ? widget.meal!
        : defaultMealForNow(now);
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

  Future<void> _select(FoodResult food) async {
    final favorites = ref.read(favoriteFoodsProvider).valueOrNull ?? const [];
    final result = await showModalBottomSheet<_LogRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).card,
      builder: (_) => _QuantitySheet(
        food: food,
        meal: _meal,
        isFavorite: favorites.any((f) => f.name == food.name),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _save(result);
  }

  Future<void> _save(_LogRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final service = ref.read(nutritionServiceProvider);
    if (service == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to log food.')),
      );
      return;
    }
    final scaled = scaleFood(request.food, request.quantityG);
    await service.logFood(
      foodName: request.food.name,
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
        name: request.food.name,
        brand: request.food.brand,
        proteinPer100g: request.food.proteinPer100g,
        caloriesPer100g: request.food.caloriesPer100g,
        carbsPer100g: request.food.carbsPer100g,
        fatPer100g: request.food.fatPer100g,
      );
      ref.invalidate(favoriteFoodsProvider);
    }
    ref.invalidate(nutritionDayProvider(_day));
    messenger.showSnackBar(
      SnackBar(content: Text('Logged ${request.food.name}')),
    );
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.header,
        foregroundColor: colors.text,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log food'),
            Text(
              DateFormat('EEEE, MMM d').format(_day),
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            onPressed: () => context.push('/nutrition/scan'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Photo scan',
            onPressed: () => context.push('/nutrition/photo'),
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              children: [
                for (final m in mealOrder)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mealLabel(m)),
                      selected: _meal == m,
                      onSelected: (_) => setState(() => _meal = m),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Search')),
                ButtonSegment(value: 1, label: Text('Favorites')),
                ButtonSegment(value: 2, label: Text('Manual')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _SearchTab(
                  results: _results,
                  searching: _searching,
                  onQuery: _onQuery,
                  onSelect: _select,
                ),
              1 => _FavoritesTab(onSelect: _select),
              _ => _ManualTab(
                  meal: _meal,
                  onSubmit: _save,
                ),
            },
          ),
        ],
      ),
    );
  }
}

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

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.results,
    required this.searching,
    required this.onQuery,
    required this.onSelect,
  });
  final List<FoodResult> results;
  final bool searching;
  final ValueChanged<String> onQuery;
  final ValueChanged<FoodResult> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: onQuery,
            decoration: const InputDecoration(
              hintText: 'Search foods (dal, paneer, oats…)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    searching ? 'Searching…' : 'No foods found',
                    style: TextStyle(color: colors.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: results.length,
                  itemBuilder: (_, i) => _FoodTile(
                    food: results[i],
                    onTap: () => onSelect(results[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.onSelect});
  final ValueChanged<FoodResult> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final favorites = ref.watch(favoriteFoodsProvider);
    return favorites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Could not load favorites')),
      data: (list) => list.isEmpty
          ? Center(
              child: Text(
                'Star a food when logging to save it here',
                style: TextStyle(color: colors.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: list.length,
              itemBuilder: (_, i) => Dismissible(
                key: ValueKey(list[i].name),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: colors.danger,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) async {
                  final service = ref.read(nutritionServiceProvider);
                  final rows = await service?.favorites() ?? const [];
                  for (final r in rows) {
                    if (r['food_name'] == list[i].name) {
                      await service?.removeFavorite(r['id'] as String);
                    }
                  }
                  ref.invalidate(favoriteFoodsProvider);
                },
                child: _FoodTile(food: list[i], onTap: () => onSelect(list[i])),
              ),
            ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.onTap});
  final FoodResult food;
  final VoidCallback onTap;

  String get _source => switch (food.source) {
        FoodSource.local => 'IN',
        FoodSource.openFoodFacts => 'OFF',
        FoodSource.usda => 'USDA',
        FoodSource.favorite => 'FAV',
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final kcal = food.caloriesPer100g == null
        ? ''
        : ' · ${food.caloriesPer100g!.round()} kcal';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${food.proteinPer100g.toStringAsFixed(1)} g protein / 100 g$kcal',
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _source,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: colors.muted,
                ),
              ),
            ),
          ],
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
  });
  final FoodResult food;
  final String meal;
  final bool isFavorite;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  final _controller = TextEditingController(text: '100');
  late bool _favorite = widget.isFavorite;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _grams => double.tryParse(_controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final scaled = scaleFood(widget.food, _grams);
    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(label, style: TextStyle(fontSize: 10, color: colors.muted)),
            ],
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.food.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Favorite',
                onPressed: () => setState(() => _favorite = !_favorite),
                icon: Icon(
                  _favorite ? Icons.star : Icons.star_border,
                  color: AppColors.xp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              suffixText: 'g',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('PROTEIN g', scaled.protein.toStringAsFixed(1), AppColors.nutrition),
              stat('KCAL', scaled.calories?.round().toString() ?? '—', AppColors.workout),
              stat('CARBS g', scaled.carbs?.toStringAsFixed(1) ?? '—', AppColors.water),
              stat('FAT g', scaled.fat?.toStringAsFixed(1) ?? '—', AppColors.xp),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
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
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.accentText,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('LOG TO ${mealLabel(widget.meal).toUpperCase()}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualTab extends StatefulWidget {
  const _ManualTab({required this.meal, required this.onSubmit});
  final String meal;
  final ValueChanged<_LogRequest> onSubmit;

  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _grams = TextEditingController(text: '100');
  final _protein = TextEditingController();
  final _calories = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _nonNegative(String? v) {
    final n = double.tryParse((v ?? '').trim());
    return n == null || n < 0 ? 'Enter a number' : null;
  }

  String? _positive(String? v) {
    final n = double.tryParse((v ?? '').trim());
    return n == null || n <= 0 ? 'Enter a number' : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final grams = _d(_grams)!;
    // Values were entered for the stated quantity; store them per 100 g.
    final per100 = 100 / grams;
    double? scale(double? v) => v == null ? null : v * per100;
    widget.onSubmit(
      _LogRequest(
        food: FoodResult(
          name: _name.text.trim(),
          proteinPer100g: (_d(_protein) ?? 0) * per100,
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

  Widget _num(
    String label,
    TextEditingController c, {
    bool required = false,
    FormFieldValidator<String>? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator ?? (required ? _positive : null),
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _name,
              validator: _required,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Food name'),
            ),
          ),
          _num('Quantity (g)', _grams, required: true),
          _num('Protein (g) for this quantity', _protein, validator: _nonNegative),
          _num('Calories (kcal)', _calories),
          _num('Carbs (g)', _carbs),
          _num('Fat (g)', _fat),
          FilledButton(onPressed: _submit, child: const Text('LOG FOOD')),
        ],
      ),
    );
  }
}
