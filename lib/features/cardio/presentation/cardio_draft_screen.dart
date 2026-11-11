import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/local/local_draft_store.dart';
import '../domain/cardio_draft.dart';

class CardioDraftScreen extends StatefulWidget {
  const CardioDraftScreen({super.key});
  @override
  State<CardioDraftScreen> createState() => _CardioDraftScreenState();
}

class _CardioDraftScreenState extends State<CardioDraftScreen> {
  static const _key = 'fittrack_cardio_drafts_v1';
  final _minutes = TextEditingController();
  final _distance = TextEditingController();
  String _type = 'running';
  LocalDraftStore? _store;
  CardioDrafts _drafts = const CardioDrafts([]);
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final store = LocalDraftStore(await SharedPreferences.getInstance());
      if (mounted) setState(() {
        _store = store;
        final raw = store.read(_key);
        _drafts = raw == null ? const CardioDrafts([]) : CardioDrafts.decode(raw);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load local cardio drafts');
    }
  }

  Future<void> _add() async {
    final draft = CardioDraft(type: _type, durationMinutes: int.tryParse(_minutes.text) ?? -1,
      distanceKm: _distance.text.trim().isEmpty ? null : double.tryParse(_distance.text) ?? double.nan);
    if (!draft.isValid) { setState(() => _error = 'Enter valid minutes and distance'); return; }
    final updated = _drafts.add(draft);
    try {
      await _store!.write(_key, updated.encode());
      if (mounted) setState(() { _drafts = updated; _error = null; });
      _minutes.clear(); _distance.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save cardio draft');
    }
  }

  @override
  void dispose() { _minutes.dispose(); _distance.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cardio drafts')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Saved on this device only; not synced to your account.'),
      DropdownButtonFormField<String>(
        initialValue: _type, decoration: const InputDecoration(labelText: 'Activity'),
        items: const [
          DropdownMenuItem(value: 'running', child: Text('Running')),
          DropdownMenuItem(value: 'walking', child: Text('Walking')),
          DropdownMenuItem(value: 'cycling', child: Text('Cycling')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (value) { if (value != null) setState(() => _type = value); },
      ),
      TextField(controller: _minutes, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Duration (minutes)')),
      TextField(controller: _distance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Distance (km, optional)')),
      FilledButton(onPressed: _store == null ? null : _add, child: const Text('Save cardio draft')),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 20),
      Text('${_drafts.items.length} sessions • ${_drafts.totalMinutes} minutes'),
    ]),
  );
}
