import 'dart:typed_data';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../data/photo_scan_service.dart';
import '../domain/food_result.dart';
import '../domain/photo_scan_models.dart';
import 'food_log_screen.dart' show defaultMealForNow;
import 'nutrition_screen.dart';
import 'scan_chrome.dart';
import '../../../core/widgets/fittrack_icons.dart';

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

  /// Fiber for the entered grams, rounded to 0.1 g.
  double get fiber => item.estimatedGrams > 0
      ? (item.fiberG * quantity / item.estimatedGrams * 10).round() / 10
      : 0;
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
  bool? _editOverride;

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
      setState(() => _error = context.t('nutrition:photoSignIn'));
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
    final logged = context.t(
      'nutrition:photoLogged',
      args: {
        'count': [
          for (final r in _rows)
            if (r.selected && r.quantity > 0) r
        ].length,
      },
    );
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
        fiberG: r.item.estimatedGrams > 0 ? r.fiber : null,
        calories: s.calories,
        micronutrients: s.micronutrients.isEmpty ? null : s.micronutrients,
      );
    }
    ref.invalidate(nutritionDayProvider(dayOnly(DateTime.now())));
    messenger.showSnackBar(SnackBar(content: Text(logged)));
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final selected = _rows.where((r) => r.selected).toList();
    double sum(double Function(_ScanRow r) f) =>
        selected.fold<double>(0, (t, r) => t + f(r));
    final kcal = sum((r) => r.scaled.calories ?? 0);
    final protein = sum((r) => r.scaled.protein);
    final carbs = sum((r) => r.scaled.carbs ?? 0);
    final fat = sum((r) => r.scaled.fat ?? 0);
    final fiber = sum((r) => r.fiber);
    final hasResult = _result != null && !_loading;
    final editing = _editOverride ?? _rows.length > 1;
    return Scaffold(
      backgroundColor: FitTrackCamera.bg(Theme.of(context).brightness),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScanHeader(photoSelected: true),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Preview(photo: _photo, loading: _loading),
                        if (_result != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: FitTrackSpacing.md,
                            ),
                            child: Text(
                              context.t(
                                'nutrition:photoScansUsed',
                                args: {
                                  'used': _result!.scansUsed,
                                  'limit': _result!.scansLimit,
                                },
                              ),
                              textAlign: TextAlign.center,
                              style: FitTrackText.caption.copyWith(
                                color: FitTrackCamera.muted,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(FitTrackSpacing.lg),
                          child: Row(
                            children: [
                              Expanded(
                                child: FitTrackButton(
                                  label: context.t('nutrition:photoTake'),
                                  icon: FitIcons.camera,
                                  onPressed: _loading
                                      ? null
                                      : () => _pick(ImageSource.camera),
                                ),
                              ),
                              const SizedBox(width: FitTrackSpacing.md),
                              Expanded(
                                child: FitTrackButton(
                                  label: context.t('nutrition:photoGallery'),
                                  icon: FitIcons.gallery,
                                  variant: FitTrackButtonVariant.secondary,
                                  onPressed: _loading
                                      ? null
                                      : () => _pick(ImageSource.gallery),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            FitTrackSpacing.lg,
                            FitTrackSpacing.lg,
                            FitTrackSpacing.lg,
                            FitTrackSpacing.lg +
                                MediaQuery.paddingOf(context).bottom,
                          ),
                          decoration: BoxDecoration(
                            color: colors.bg,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(FitTrackRadius.xl),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FitTrackTextField(
                                label: context.t('nutrition:photoHintLabel'),
                                controller: _hint,
                                hint: context.t('nutrition:photoHint'),
                                textInputAction: TextInputAction.done,
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: FitTrackSpacing.lg,
                                  ),
                                  child: Text(
                                    _error!,
                                    style: FitTrackText.body.copyWith(
                                      color: colors.textBad,
                                    ),
                                  ),
                                ),
                              if (_limitReached)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: FitTrackSpacing.lg,
                                  ),
                                  child: FitTrackCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.t('nutrition:photoLimit'),
                                          style: FitTrackText.title.copyWith(
                                            color: colors.ink,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: FitTrackSpacing.md,
                                        ),
                                        FitTrackButton(
                                          label: context
                                              .t('nutrition:photoUpgrade'),
                                          fullWidth: true,
                                          onPressed: () =>
                                              context.push('/paywall'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (hasResult && _rows.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: FitTrackSpacing.lg,
                                  ),
                                  child: Text(
                                    context.t('nutrition:photoNoFood'),
                                    style: FitTrackText.body
                                        .copyWith(color: colors.muted),
                                  ),
                                ),
                              if (hasResult && _rows.isNotEmpty) ...[
                                const SizedBox(height: FitTrackSpacing.xl),
                                Text(
                                  _rows.length == 1
                                      ? _rows.first.item.foodName
                                      : context.t(
                                          'nutrition:photoItems',
                                          args: {'count': _rows.length},
                                        ),
                                  style: FitTrackText.titleLg.copyWith(
                                    color: colors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.t('nutrition:photoEstimated'),
                                  style: FitTrackText.label
                                      .copyWith(color: colors.muted),
                                ),
                                const SizedBox(height: FitTrackSpacing.md),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${kcal.round()}',
                                      style: FitTrackText.hero.copyWith(
                                        color: colors.ink,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: FitTrackSpacing.sm),
                                    Text(
                                      context.t('nutrition:unitKcal'),
                                      style: FitTrackText.body
                                          .copyWith(color: colors.muted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FitTrackSpacing.lg),
                                Row(
                                  children: [
                                    _Macro(
                                      label: context.t('nutrition:protein'),
                                      grams: protein,
                                    ),
                                    const SizedBox(width: FitTrackSpacing.sm),
                                    _Macro(
                                      label: context.t('nutrition:carbs'),
                                      grams: carbs,
                                    ),
                                    const SizedBox(width: FitTrackSpacing.sm),
                                    _Macro(
                                      label: context.t('nutrition:fat'),
                                      grams: fat,
                                    ),
                                    const SizedBox(width: FitTrackSpacing.sm),
                                    _Macro(
                                      label: context.t('nutrition:fiber'),
                                      grams: fiber,
                                    ),
                                  ],
                                ),
                                if (editing) ...[
                                  const SizedBox(height: FitTrackSpacing.lg),
                                  for (final row in _rows)
                                    _ScanRowCard(
                                      row: row,
                                      onChanged: () => setState(() {}),
                                    ),
                                ],
                                const SizedBox(height: FitTrackSpacing.md),
                                Text(
                                  context.t('nutrition:photoNote'),
                                  style: FitTrackText.caption
                                      .copyWith(color: colors.muted),
                                ),
                                const SizedBox(height: FitTrackSpacing.lg),
                                SizedBox(
                                  height: FitTrackSpacing.touchMin,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (final m in mealOrder)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: FitTrackSpacing.sm,
                                          ),
                                          child: FitTrackChip(
                                            label: mealText(context, m),
                                            selected: _meal == m,
                                            onTap: () =>
                                                setState(() => _meal = m),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: FitTrackSpacing.md),
                                Row(
                                  children: [
                                    FitTrackButton(
                                      label: context.t(
                                        editing
                                            ? 'nutrition:photoDone'
                                            : 'nutrition:photoEdit',
                                      ),
                                      variant: FitTrackButtonVariant.secondary,
                                      onPressed: () => setState(
                                        () => _editOverride = !editing,
                                      ),
                                    ),
                                    const SizedBox(width: FitTrackSpacing.md),
                                    Expanded(
                                      child: FitTrackButton(
                                        label: context.t(
                                          'nutrition:photoAddTo',
                                          args: {
                                            'meal': mealText(context, _meal),
                                          },
                                        ),
                                        fullWidth: true,
                                        onPressed: selected.isEmpty
                                            ? null
                                            : _logSelected,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
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
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.photo, required this.loading});
  final Uint8List? photo;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.lg,
        FitTrackSpacing.lg,
        FitTrackSpacing.lg,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FitTrackRadius.card),
        child: SizedBox(
          height: 300,
          child: ColoredBox(
            color: FitTrackCamera.panel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null)
                  Image.memory(photo!, fit: BoxFit.cover)
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(FitTrackRadius.xl),
                            border: Border.all(
                              color: FitTrackCamera.ink,
                              width: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: FitTrackSpacing.md),
                        Text(
                          context.t('nutrition:photoFrameHint'),
                          style: FitTrackText.label
                              .copyWith(color: FitTrackCamera.muted),
                        ),
                      ],
                    ),
                  ),
                if (loading)
                  ColoredBox(
                    color: AppTheme.scrim,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: FitTrackSpacing.md),
                          Text(
                            context.t('nutrition:photoAnalyzing'),
                            style: FitTrackText.label
                                .copyWith(color: FitTrackCamera.ink),
                          ),
                        ],
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

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams});
  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Expanded(
      child: Semantics(
        label: '$label ${grams.round()} g',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: FitTrackSpacing.md,
              horizontal: FitTrackSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(FitTrackRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  '${grams.round()} g',
                  style: FitTrackText.title.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: FitTrackText.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: FitTrackSpacing.md),
      child: FitTrackCard(
        padding: const EdgeInsets.all(FitTrackSpacing.md),
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
                    style: FitTrackText.title.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${context.t('nutrition:photoConfidence', args: {
                          'pct': (row.item.confidence * 100).round(),
                        })}'
                    '${row.item.notes.isEmpty ? '' : ' · ${row.item.notes}'}',
                    style: FitTrackText.caption.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: FitTrackSpacing.sm),
                  Text(
                    '${s.calories?.round() ?? 0} ${context.t('nutrition:unitKcal')}'
                    ' · ${s.protein.round()} g ${context.t('nutrition:protein')}'
                    ' · ${(s.carbs ?? 0).round()} g ${context.t('nutrition:carbs')}'
                    ' · ${(s.fat ?? 0).round()} g ${context.t('nutrition:fat')}',
                    style: FitTrackText.caption.copyWith(
                      color: colors.nutritionColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 88,
              child: FitTrackTextField(
                label: context.t('nutrition:photoGrams'),
                controller: row.grams,
                onChanged: (_) => onChanged(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                suffix: Text(
                  'g',
                  style: FitTrackText.body.copyWith(color: colors.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
