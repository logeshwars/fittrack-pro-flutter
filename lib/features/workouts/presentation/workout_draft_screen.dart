import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/workout_draft_store.dart';
import '../domain/workout_draft.dart';

class WorkoutDraftScreen extends StatefulWidget {
  const WorkoutDraftScreen({super.key});
  @override
  State<WorkoutDraftScreen> createState() => _WorkoutDraftScreenState();
}

class _WorkoutDraftScreenState extends State<WorkoutDraftScreen> {
  final _exercise = TextEditingController();
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  WorkoutDraft? _draft;
  WorkoutDraftStore? _store;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = WorkoutDraftStore(prefs);
      if (!mounted) return;
      setState(() {
        _store = store;
        _draft = store.load() ?? WorkoutDraft(name: 'New workout', startedAt: DateTime.now());
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to open local draft');
    }
  }

  Future<void> _addSet() async {
    final exercise = _exercise.text.trim();
    final weight = double.tryParse(_weight.text);
    final reps = int.tryParse(_reps.text);
    if (exercise.isEmpty || weight == null || !weight.isFinite || weight < 0 ||
        reps == null || reps < 1 || reps > 1000) {
      setState(() => _error = 'Enter an exercise, valid weight and reps');
      return;
    }
    final draft = _draft;
    final store = _store;
    if (draft == null || store == null) return;
    final updated = draft.addSet(DraftSet(exerciseName: exercise, weightKg: weight, reps: reps));
    try {
      await store.save(updated);
      if (!mounted) return;
      setState(() { _draft = updated; _error = null; });
      _weight.clear();
      _reps.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save local draft');
    }
  }

  Future<void> _removeSet(int index) async {
    final draft = _draft;
    final store = _store;
    if (draft == null || store == null) return;
    try {
      final updated = draft.removeSet(index);
      await store.save(updated);
      if (mounted) setState(() { _draft = updated; _error = null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save local draft');
    }
  }

  Future<void> _discard() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.clear();
      if (!mounted) return;
      setState(() {
        _draft = WorkoutDraft(name: 'New workout', startedAt: DateTime.now());
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to discard draft');
    }
  }

  @override
  void dispose() {
    _exercise.dispose();
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout draft')),
      body: draft == null
          ? Center(child: Text(_error ?? 'Loading draft…'))
          : ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Saved only on this device. Not uploaded to your account.'),
              const SizedBox(height: 16),
              TextField(controller: _exercise, decoration: const InputDecoration(labelText: 'Exercise')),
              TextField(controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)')),
              TextField(controller: _reps, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps')),
              const SizedBox(height: 12),
              FilledButton(onPressed: _addSet, child: const Text('Add set to draft')),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              Text('${draft.sets.length} sets · ${draft.totalVolumeKg.toStringAsFixed(1)} kg volume'),
              for (var i = 0; i < draft.sets.length; i++)
                ListTile(
                  title: Text(draft.sets[i].exerciseName),
                  subtitle: Text('${draft.sets[i].weightKg} kg × ${draft.sets[i].reps}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Remove set',
                    onPressed: () => _removeSet(i)),
                ),
              OutlinedButton(onPressed: _discard, child: const Text('Discard local draft')),
            ]),
    );
  }
}
