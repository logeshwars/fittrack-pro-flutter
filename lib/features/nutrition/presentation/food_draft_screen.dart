import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../data/food_draft_store.dart';
import '../domain/food_draft.dart';

class FoodDraftScreen extends StatefulWidget {
  const FoodDraftScreen({super.key});

  @override
  State<FoodDraftScreen> createState() => _FoodDraftScreenState();
}

class _FoodDraftScreenState extends State<FoodDraftScreen> {
  final _name = TextEditingController();
  final _grams = TextEditingController(text: '100');
  final _protein = TextEditingController();
  final _calories = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  FoodDraftStore? _store;
  FoodDraftCollection _drafts = const FoodDraftCollection([]);
  String _meal = 'lunch';
  String? _error;

  static const _meals = <(String, String)>[
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('snack', 'Snack'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = FoodDraftStore(await SharedPreferences.getInstance());
      if (!mounted) return;
      setState(() {
        _store = store;
        _drafts = store.load();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load local food drafts');
    }
  }

  Future<void> _add() async {
    final draft = FoodDraft(
      name: _name.text.trim(),
      quantityG: double.tryParse(_grams.text) ?? double.nan,
      proteinG: double.tryParse(_protein.text) ?? double.nan,
      calories: double.tryParse(_calories.text) ?? double.nan,
      carbsG: double.tryParse(_carbs.text) ?? double.nan,
      fatG: double.tryParse(_fat.text) ?? double.nan,
      mealType: _meal,
    );

    if (!draft.isValid) {
      setState(
        () => _error =
            'Enter a food name and valid non-negative nutrition values',
      );
      return;
    }

    final store = _store;
    if (store == null) return;
    final updated = _drafts.add(draft);

    try {
      await store.save(updated);
      if (!mounted) return;
      setState(() {
        _drafts = updated;
        _error = null;
      });
      _name.clear();
      _grams.text = '100';
      _protein.clear();
      _calories.clear();
      _carbs.clear();
      _fat.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save local food draft');
    }
  }

  Future<void> _remove(int index) async {
    final store = _store;
    if (store == null) return;

    try {
      final updated = _drafts.remove(index);
      await store.save(updated);
      if (mounted) {
        setState(() {
          _drafts = updated;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to remove food draft');
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _grams,
      _protein,
      _calories,
      _carbs,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _Header(
              title: 'Log Manually',
              subtitle: 'Local nutrition draft',
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('FOOD NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Grilled chicken breast',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Label('QUANTITY (g)'),
                  const SizedBox(height: 8),
                  _LargeNumberField(
                    controller: _grams,
                    suffix: 'g',
                  ),
                  const SizedBox(height: 16),
                  const _Label('PROTEIN (g)'),
                  const SizedBox(height: 8),
                  _LargeNumberField(
                    controller: _protein,
                    suffix: 'g',
                    accent: AppColors.nutrition,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactField(
                          label: 'CARBS (g)',
                          controller: _carbs,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CompactField(
                          label: 'FAT (g)',
                          controller: _fat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CompactField(
                    label: 'CALORIES (kcal)',
                    controller: _calories,
                  ),
                  const SizedBox(height: 20),
                  const _Label('MEAL'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _meals.map((meal) {
                      final active = _meal == meal.$1;
                      return InkWell(
                        onTap: () => setState(() => _meal = meal.$1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.nutrition.withValues(alpha: .10)
                                : colors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  active ? AppColors.nutrition : colors.border2,
                            ),
                          ),
                          child: Text(
                            meal.$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  active ? AppColors.nutrition : colors.muted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.danger.withValues(alpha: .35),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: colors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _store == null ? null : _add,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('LOG FOOD'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.accentText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_drafts.items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LOCAL DRAFTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.muted,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Text(
                      '${_drafts.totalCalories.round()} kcal · ${_drafts.totalProteinG.toStringAsFixed(0)}g protein',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var i = 0; i < _drafts.items.length; i++)
                      _DraftFoodRow(
                        item: _drafts.items[i],
                        onRemove: () => _remove(i),
                      ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Drafts are stored only on this device. Cloud nutrition writes and food scanning remain gated during account migration.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: colors.faint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border2),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back, size: 18, color: colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: colors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.nutrition.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.nutrition.withValues(alpha: .25),
              ),
            ),
            child: const Text(
              'LOCAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.nutrition,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: colors.faint,
        letterSpacing: 2,
      ),
    );
  }
}

class _LargeNumberField extends StatelessWidget {
  const _LargeNumberField({
    required this.controller,
    required this.suffix,
    this.accent,
  });

  final TextEditingController controller;
  final String suffix;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent ?? colors.border2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: accent ?? colors.text,
              ),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Text(
            suffix,
            style: TextStyle(
              fontSize: 14,
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0'),
        ),
      ],
    );
  }
}

class _DraftFoodRow extends StatelessWidget {
  const _DraftFoodRow({
    required this.item,
    required this.onRemove,
  });

  final FoodDraft item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final initial = item.name.isEmpty ? '?' : item.name[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border2),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.nutrition,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantityG.toStringAsFixed(0)}g · ${item.calories.toStringAsFixed(0)} kcal · ${item.proteinG.toStringAsFixed(1)}g protein',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.subtext,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 17, color: colors.faint),
          ),
        ],
      ),
    );
  }
}
