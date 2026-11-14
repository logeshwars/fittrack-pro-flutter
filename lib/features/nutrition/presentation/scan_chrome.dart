import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_icons.dart';

/// Header for the two scan screens: back button, "Scan food" title and the
/// Barcode / Photo scan switch. Drawn on the dark camera chrome in both themes.
class ScanHeader extends StatelessWidget {
  const ScanHeader({required this.photoSelected, super.key});

  /// Whether the Photo scan tab is the active one.
  final bool photoSelected;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool active, String route) => Expanded(
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                onTap: active ? null : () => context.pushReplacement(route),
                child: Container(
                  height: FitTrackSpacing.touchMin,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? FitTrackCamera.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                  ),
                  child: Text(
                    label,
                    style: FitTrackText.body.copyWith(
                      color: active
                          ? FitTrackCamera.bg(Brightness.dark)
                          : FitTrackCamera.muted,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitTrackSpacing.xs,
            FitTrackSpacing.sm,
            FitTrackSpacing.sm,
            FitTrackSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: FitTrackSpacing.touchMin,
                height: FitTrackSpacing.touchMin,
                child: IconButton(
                  tooltip: context.t('nutrition:goBackLink'),
                  onPressed: () => context.pop(),
                  icon: const Icon(FitIcons.back, color: FitTrackCamera.ink),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                context.t('nutrition:scanFoodTitle'),
                style: FitTrackText.titleLg.copyWith(
                  color: FitTrackCamera.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: FitTrackCamera.panel,
              borderRadius: BorderRadius.circular(FitTrackRadius.md),
            ),
            child: Row(
              children: [
                tab(
                  context.t('nutrition:methodBarcode'),
                  !photoSelected,
                  '/nutrition/scan',
                ),
                tab(
                  context.t('nutrition:methodPhoto'),
                  photoSelected,
                  '/nutrition/photo',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
