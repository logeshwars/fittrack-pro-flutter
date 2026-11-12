import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/photo_scan_service.dart';
import '../domain/food_result.dart';
import '../domain/photo_scan_models.dart';
import 'food_log_screen.dart' show defaultMealForNow;
import 'nutrition_screen.dart';

/// Photograph a meal, let AI estimate it, adjust, then log.
class PhotoScanScreen extends ConsumerStatefulWidget {
  const PhotoScanScreen({super.key});

  @override
  ConsumerState<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _ScanRow {
  _ScanRow(this.item)
      : grams =
            TextEditingController(text: item.estimatedGrams.round().toString());
  final FoodScanItem item;
  final TextEditingController grams;
  bool selected = true;

  double get quantity => double.tryParse(grams.text.trim()) ?? 0;
  ScaledFood get scaled => scaleFood(item.toFoodResult(), quantity);
}

class _PhotoScanScreenState extends ConsumerState<PhotoScanScreen> {
  final _picker = ImagePicker();
  final _hint = TextEditingController();
  Uint8List? _photo;
  List<_ScanRow> _rows = const [];
  PhotoScanResult? _result;
  bool _loading = false;
  bool _limitReached = false;
  String? _error;
  late String _meal = defaultMealForNow(DateTime.now());

  @override
  void dispose() {
    _hint.dispose();
    for (final r in _rows) {
      r.grams.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1600);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _photo = bytes;
      _error = null;
      _limitReached = false;
    });
    await _analyze();
  }

  Future<void> _analyze() async {
    final photo = _photo;
    final service = ref.read(photoScanServiceProvider);
    if (photo == null) {
      return;
    }
    if (service == null) {
      setState(() => _error = 'Sign in to scan meals.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await service.analyze(photo, hint: _hint.text);
      if (!mounted) {
        return;
      }
      for (final r in _rows) {
        r.grams.dispose();
      }
      setState(() {
        _result = result;
        _rows = [for (final i in result.items) _ScanRow(i)];
      });
    } on ScanLimitReached {
      if (mounted) {
        setState(() => _limitReached = true);
      }
    } on PhotoScanFailure catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logSelected() async {
    final service = ref.read(nutritionServiceProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final chosen = [
      for (final r in _rows)
        if (r.selected && r.quantity > 0) r
    ];
    if (service == null || chosen.isEmpty) {
      return;
    }
    for (final r in chosen) {
      final s = r.scaled;
      await service.logFood(
        foodName: r.item.foodName,
        mealType: _meal,
        quantityG: s.quantityG,
        proteinG: s.protein,
        carbsG: s.carbs,
        fatG: s.fat,
        fiberG: r.item.estimatedGrams > 0
            ? (r.item.fiberG * r.quantity / r.item.estimatedGrams * 10)
                    .round() /
                10
            : null,
        calories: s.calories,
        micronutrients: s.micronutrients.isEmpty ? null : s.micronutrients,
      );
    }
    ref.invalidate(nutritionDayProvider(dayOnly(DateTime.now())));
    messenger.showSnackBar(
      SnackBar(content: Text('Logged ${chosen.length} item(s)')),
    );
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final totalKcal = _rows
        .where((r) => r.selected)
        .fold<double>(0, (s, r) => s + (r.scaled.calories ?? 0));
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.header,
        foregroundColor: colors.text,
        title: const Text('Photo scan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(_photo!, height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hint,
            decoration: const InputDecoration(
              hintText: 'Optional hint (e.g. "2 rotis with dal")',
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: colors.danger)),
            ),
          if (_limitReached)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Daily scan limit reached',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.push('/paywall'),
                    child: const Text('Upgrade to Pro'),
                  ),
                ],
              ),
            ),
          if (_result != null && !_loading) ...[
            const SizedBox(height: 16),
            Text(
              'SCANS TODAY ${_result!.scansUsed}/${_result!.scansLimit}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 8),
            if (_rows.isEmpty)
              Text('No food detected.', style: TextStyle(color: colors.muted)),
            for (final row in _rows)
              _ScanRowCard(row: row, onChanged: () => setState(() {})),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
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
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _rows.any((r) => r.selected) ? _logSelected : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.accentText,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text('LOG SELECTED · ${totalKcal.round()} KCAL'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScanRowCard extends StatelessWidget {
  const _ScanRowCard({required this.row, required this.onChanged});
  final _ScanRow row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final s = row.scaled;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: row.selected,
            onChanged: (v) {
              row.selected = v ?? false;
              onChanged();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.item.foodName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(row.item.confidence * 100).round()}% confident'
                  '${row.item.notes.isEmpty ? '' : ' · ${row.item.notes}'}',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s.calories?.round() ?? 0} kcal · P ${s.protein.toStringAsFixed(1)} · '
                  'C ${s.carbs?.toStringAsFixed(1) ?? '0'} · F ${s.fat?.toStringAsFixed(1) ?? '0'}',
                  style: TextStyle(fontSize: 11, color: AppColors.nutrition),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: row.grams,
              onChanged: (_) => onChanged(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'g', isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}
