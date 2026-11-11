import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/food_draft_store.dart';
import '../domain/food_draft.dart';

class FoodDraftScreen extends StatefulWidget {
  const FoodDraftScreen({super.key});
  @override
  State<FoodDraftScreen> createState() => _FoodDraftScreenState();
}

class _FoodDraftScreenState extends State<FoodDraftScreen> {
  final _name = TextEditingController();
  final _grams = TextEditingController();
  final _protein = TextEditingController();
  final _calories = TextEditingController();
  final _carbs = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  FoodDraftStore? _store;
  FoodDraftCollection _drafts = const FoodDraftCollection([]);
  String _meal = 'snack';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = FoodDraftStore(await SharedPreferences.getInstance());
      if (!mounted) return;
      setState(() { _store = store; _drafts = store.load(); });
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
      setState(() => _error = 'Enter a food name and valid non-negative nutrition values');
      return;
    }
    final store = _store;
    if (store == null) return;
    final updated = _drafts.add(draft);
    try {
      await store.save(updated);
      if (!mounted) return;
      setState(() { _drafts = updated; _error = null; });
      _name.clear(); _grams.clear(); _protein.clear(); _calories.clear();
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
      if (mounted) setState(() { _drafts = updated; _error = null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to remove food draft');
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _grams, _protein, _calories, _carbs, _fat]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Food drafts')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Manual nutrition drafts are saved on this device only. Food scanning is not yet enabled.'),
      const SizedBox(height: 12),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Food name')),
      TextField(controller: _grams, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity (g)')),
      TextField(controller: _calories, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Calories (kcal)')),
      TextField(controller: _protein, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Protein (g)')),
      TextField(controller: _carbs, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Carbs (g)')),
      TextField(controller: _fat, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Fat (g)')),
      DropdownButtonFormField<String>(
        initialValue: _meal,
        decoration: const InputDecoration(labelText: 'Meal'),
        items: const [
          DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
          DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
          DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
          DropdownMenuItem(value: 'snack', child: Text('Snack')),
        ],
        onChanged: (value) { if (value != null) setState(() => _meal = value); },
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _store == null ? null : _add, child: const Text('Save local food draft')),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 20),
      Text('${_drafts.items.length} foods • ${_drafts.totalCalories.toStringAsFixed(0)} kcal • ${_drafts.totalProteinG.toStringAsFixed(1)} g protein'),
      for (var i = 0; i < _drafts.items.length; i++)
        ListTile(
          title: Text(_drafts.items[i].name),
          subtitle: Text('${_drafts.items[i].quantityG.toStringAsFixed(0)} g • ${_drafts.items[i].mealType}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Remove draft',
            onPressed: () => _remove(i)),
        ),
    ]),
  );
}
