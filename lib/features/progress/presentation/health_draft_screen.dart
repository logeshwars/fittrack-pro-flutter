import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/local/local_draft_store.dart';
import '../domain/health_drafts.dart';

class HealthDraftScreen extends StatefulWidget {
  const HealthDraftScreen({super.key});
  @override
  State<HealthDraftScreen> createState() => _HealthDraftScreenState();
}

class _HealthDraftScreenState extends State<HealthDraftScreen> {
  static const _key = 'fittrack_health_drafts_v1';
  final _weight = TextEditingController();
  final _sleepHours = TextEditingController();
  LocalDraftStore? _store;
  HealthDrafts _drafts = const HealthDrafts();
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final store = LocalDraftStore(await SharedPreferences.getInstance());
      if (mounted) {
        setState(() {
        _store = store;
        final raw = store.read(_key);
        _drafts = raw == null ? const HealthDrafts() : HealthDrafts.decode(raw);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load local entries');
    }
  }

  Future<void> _addWeight() async {
    final draft = WeightDraft(kg: double.tryParse(_weight.text) ?? double.nan, loggedAt: DateTime.now());
    if (!draft.isValid) { setState(() => _error = 'Enter a valid weight in kg'); return; }
    final updated = _drafts.addWeight(draft);
    try {
      await _store!.write(_key, updated.encode());
      if (mounted) setState(() { _drafts = updated; _error = null; });
      _weight.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save weight');
    }
  }

  Future<void> _addSleep() async {
    final hours = double.tryParse(_sleepHours.text);
    if (hours == null || !hours.isFinite || hours <= 0 || hours > 24) {
      setState(() => _error = 'Enter sleep duration between 0 and 24 hours');
      return;
    }
    final wake = DateTime.now();
    final draft = SleepDraft(bedtime: wake.subtract(Duration(minutes: (hours * 60).round())), wakeTime: wake);
    if (!draft.isValid) { setState(() => _error = 'Invalid sleep duration'); return; }
    final updated = _drafts.addSleep(draft);
    try {
      await _store!.write(_key, updated.encode());
      if (mounted) setState(() { _drafts = updated; _error = null; });
      _sleepHours.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save sleep');
    }
  }

  @override
  void dispose() { _weight.dispose(); _sleepHours.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Health drafts')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Saved on this device only; not synced to your account.'),
      TextField(controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Body weight (kg)')),
      FilledButton(onPressed: _store == null ? null : _addWeight, child: const Text('Save weight draft')),
      const SizedBox(height: 20),
      TextField(controller: _sleepHours, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Hours slept (ending now)')),
      FilledButton(onPressed: _store == null ? null : _addSleep, child: const Text('Save sleep draft')),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 20),
      Text('Local weights: ${_drafts.weights.length}'),
      Text('Local sleep entries: ${_drafts.sleep.length}'),
    ]),
  );
}
