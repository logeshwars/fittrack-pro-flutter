import 'package:flutter/material.dart';
import '../l10n/language_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/fittrack_tokens.dart';

enum FitTrackButtonVariant { primary, secondary, tint, ghost, danger }

enum FitTrackButtonSize { sm, md, lg, pill }

/// Button (C1). One primary per view. Cancel is secondary, never red.
/// `sm` is 36px tall but keeps a 44px tap area.
class FitTrackButton extends StatelessWidget {
  const FitTrackButton({
    required this.label,
    required this.onPressed,
    this.variant = FitTrackButtonVariant.primary,
    this.size = FitTrackButtonSize.md,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final FitTrackButtonVariant variant;
  final FitTrackButtonSize size;
  final IconData? icon;
  final bool loading;

  /// Localized text shown while [loading]; falls back to [label].
  final String? loadingLabel;
  final bool fullWidth;

  double get _height => switch (size) {
        FitTrackButtonSize.sm => FitTrackSpacing.controlSm,
        FitTrackButtonSize.md => FitTrackSpacing.controlMd,
        FitTrackButtonSize.lg => FitTrackSpacing.controlLg,
        FitTrackButtonSize.pill => 32.0,
      };

  /// C1: radius 10 / 12 / 14 by size, full pill for `pill`.
  double get _radius => switch (size) {
        FitTrackButtonSize.sm => 10.0,
        FitTrackButtonSize.md => 12.0,
        FitTrackButtonSize.lg => 14.0,
        FitTrackButtonSize.pill => FitTrackRadius.pill,
      };

  double get _fontSize => switch (size) {
        FitTrackButtonSize.sm => 12.0,
        FitTrackButtonSize.md => 13.0,
        FitTrackButtonSize.lg => 14.0,
        FitTrackButtonSize.pill => 11.0,
      };

  double get _hPad => switch (size) {
        FitTrackButtonSize.sm => 14.0,
        FitTrackButtonSize.md => 16.0,
        FitTrackButtonSize.lg => 20.0,
        FitTrackButtonSize.pill => 12.0,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final (bg, fg, border) = switch (variant) {
      FitTrackButtonVariant.primary => (c.accent, c.onAccent, c.accent),
      FitTrackButtonVariant.secondary => (c.surface, c.ink, c.lineStrong),
      FitTrackButtonVariant.tint => (c.accentSoft, c.ink, c.accentSoft),
      FitTrackButtonVariant.ghost => (
          Colors.transparent,
          c.ink,
          Colors.transparent
        ),
      FitTrackButtonVariant.danger => (c.bad, c.onAccent, c.bad),
    };
    final enabled = onPressed != null && !loading;
    final text = loading ? (loadingLabel ?? label) : label;
    final radius = BorderRadius.circular(_radius);

    final body = Opacity(
      // C1: disabled and loading both render at 50%.
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Container(
            height: _height,
            padding: EdgeInsets.symmetric(horizontal: _hPad),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: fg),
                if (loading || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: FitTrackText.label.copyWith(
                      color: fg,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: FitTrackSpacing.touchMin,
          ),
          child: Align(
            heightFactor: 1,
            alignment: Alignment.center,
            child: fullWidth
                ? SizedBox(width: double.infinity, child: body)
                : body,
          ),
        ),
      ),
    );
  }
}

enum FitTrackIconButtonStyle { plain, outlined, filled }

/// Icon-only button (C1): 44 x 44 tap target and a mandatory semantic label.
/// `outlined` and `filled` draw a 36px circle inside the 44px target.
class FitTrackIconButton extends StatelessWidget {
  const FitTrackIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.style = FitTrackIconButtonStyle.plain,
    super.key,
  });

  final FitTrackIconButtonStyle style;

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: SizedBox(
            width: FitTrackSpacing.touchMin,
            height: FitTrackSpacing.touchMin,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: switch (style) {
                  FitTrackIconButtonStyle.plain => null,
                  FitTrackIconButtonStyle.outlined => BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.lineStrong),
                    ),
                  FitTrackIconButtonStyle.filled =>
                    BoxDecoration(shape: BoxShape.circle, color: c.accent),
                },
                child: Icon(
                  icon,
                  size: 20,
                  color: style == FitTrackIconButtonStyle.filled
                      ? c.onAccent
                      : (color ?? c.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Input (C2): label above in caption, 44px field, surface fill,
/// line-strong border, 2px accent focus ring, `bad` error with helper text.
class FitTrackTextField extends StatelessWidget {
  const FitTrackTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(FitTrackRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FitTrackText.caption.copyWith(
            color: c.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: FitTrackSpacing.controlMd),
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: autofocus,
            maxLines: obscureText ? 1 : maxLines,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: FitTrackText.body.copyWith(color: c.ink),
            cursorColor: c.accent,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffix,
              enabledBorder: errorText == null ? null : _border(c.bad),
              focusedBorder: errorText == null ? null : _border(c.bad, 2),
            ),
          ),
        ),
        if (errorText != null || helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Icon(Icons.error_outline, size: 14, color: c.textBad),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    errorText ?? helper!,
                    style: FitTrackText.caption.copyWith(
                      color: errorText != null ? c.textBad : c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum FitTrackBadgeTone { neutral, ok, warn, bad, info, sleep }

/// Status badge (C3): 26px pill. State is carried by icon and text, never
/// color alone.
class FitTrackBadge extends StatelessWidget {
  const FitTrackBadge({
    required this.label,
    this.tone = FitTrackBadgeTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final FitTrackBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final (bg, fg) = switch (tone) {
      FitTrackBadgeTone.neutral => (c.line, c.ink),
      FitTrackBadgeTone.ok => (c.okSoft, c.ok),
      FitTrackBadgeTone.warn => (c.warnSoft, c.warn),
      FitTrackBadgeTone.bad => (c.badSoft, c.textBad),
      FitTrackBadgeTone.info => (c.accentSoft, c.ink),
      FitTrackBadgeTone.sleep => (c.sleepSoft, c.sleepColor),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(FitTrackRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: FitTrackText.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum FitTrackTier { bronze, silver, gold, elite, legend }

/// Rank badge sizes (C3): sm 22 / md 26 / lg 32.
enum FitTrackRankSize {
  sm(22, 8, 10),
  md(26, 10, 12),
  lg(32, 14, 14);

  const FitTrackRankSize(this.height, this.hPad, this.fontSize);
  final double height;
  final double hPad;
  final double fontSize;
}

/// Rank badge (C3): outlined in the tier color with a leading dot. Sizes
/// 22 / 26 / 32 px.
class FitTrackRankBadge extends StatelessWidget {
  const FitTrackRankBadge({
    required this.tier,
    required this.label,
    this.size = FitTrackRankSize.md,
    super.key,
  });

  final FitTrackTier tier;
  final String label;
  final FitTrackRankSize size;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final color = switch (tier) {
      FitTrackTier.bronze => c.tierBronze,
      FitTrackTier.silver => c.tierSilver,
      FitTrackTier.gold => c.tierGold,
      FitTrackTier.elite => c.tierElite,
      FitTrackTier.legend => c.tierLegend,
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          height: size.height,
          padding: EdgeInsets.symmetric(horizontal: size.hPad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FitTrackRadius.pill),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                // C3: the label takes the tier color, not ink.
                style: FitTrackText.caption.copyWith(
                  color: color,
                  fontSize: size.fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card (C4): surface, 1px line, radius 12, padding 16. No shadow.
class FitTrackCard extends StatelessWidget {
  const FitTrackCard({
    required this.child,
    this.padding = const EdgeInsets.all(FitTrackSpacing.lg),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final radius = BorderRadius.circular(FitTrackRadius.lg);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.line),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Log banner (C4): card with a 6px domain stripe, 48px icon column,
/// overline, title, caption, stat line and an optional +XP chip. The stripe,
/// icon and overline share [domainColor]. In Pearl pass `textNutrition` for
/// nutrition so the overline stays readable.
class FitTrackLogBanner extends StatelessWidget {
  const FitTrackLogBanner({
    required this.domainColor,
    required this.icon,
    required this.overline,
    required this.title,
    this.caption,
    this.stat,
    this.xp,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Color domainColor;
  final IconData icon;
  final String overline;
  final String title;
  final String? caption;
  final String? stat;
  final String? xp;

  /// Optional trailing control, usually a 44px [FitTrackIconButton].
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final radius = BorderRadius.circular(FitTrackRadius.lg);
    return Material(
      color: c.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: domainColor),
                SizedBox(
                  width: 48,
                  child: Center(child: Icon(icon, size: 24, color: domainColor)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                overline.toUpperCase(),
                                style: FitTrackText.overline.copyWith(
                                  color: domainColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (xp != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.accentSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  xp!,
                                  style: FitTrackText.overline.copyWith(
                                    color: c.ink,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: FitTrackText.title.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (caption != null)
                          Text(
                            caption!,
                            style: FitTrackText.caption.copyWith(color: c.muted),
                          ),
                        if (stat != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              stat!,
                              style: FitTrackText.caption.copyWith(
                                color: c.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat tile (C4): caption label, 22px tabular value, optional "of N" line.
class FitTrackStatTile extends StatelessWidget {
  const FitTrackStatTile({
    required this.value,
    required this.label,
    this.caption,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FitTrackText.caption.copyWith(color: c.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: FitTrackText.stat.copyWith(
              color: c.ink,
              fontSize: 22,
              letterSpacing: -0.44,
            ),
          ),
          if (caption != null)
            Text(caption!, style: FitTrackText.caption.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

/// Progress bar (C5): 6px, radius 3, `line` track. Fill is accent by default,
/// a domain color, `ok` when complete or `warn` when over target.
class FitTrackProgressBar extends StatelessWidget {
  const FitTrackProgressBar({
    required this.progress,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final double progress;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      label: semanticLabel,
      value: '${(progress.clamp(0, 1) * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: c.line)),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0, 1).toDouble(),
                  child: ColoredBox(color: color ?? c.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chip (C2): 44px, pill, `line-strong` outline; selected is accent.
class FitTrackChip extends StatelessWidget {
  const FitTrackChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? c.accent : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              height: FitTrackSpacing.touchMin,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: selected ? null : Border.all(color: c.lineStrong),
              ),
              child: Text(
                label,
                style: FitTrackText.label.copyWith(
                  color: selected ? c.onAccent : c.ink,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab bar (C7): 60px, 22px icon + 11px label. Active is ink w800 with a 2px
/// accent marker; inactive is muted. Tab order: Today, Workout, Nutrition,
/// Cardio, Progress. Tab keys are `fittrack-tab-$i`.
class FitTrackTabBar extends StatelessWidget {
  const FitTrackTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.iconBuilder,
    required this.labels,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget Function(int tab, Color color, {required bool focused})
      iconBuilder;
  final List<String> labels;

  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: List.generate(labels.length, (i) {
              final selected = i == selectedIndex;
              final color = selected ? c.ink : c.muted;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: labels[i],
                  child: ExcludeSemantics(
                    child: InkResponse(
                      key: Key('fittrack-tab-$i'),
                      onTap: () => onSelected(i),
                      radius: 32,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            height: 2,
                            color: selected ? c.accent : Colors.transparent,
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                iconBuilder(i, color, focused: selected),
                                const SizedBox(height: 3),
                                Text(
                                  labels[i],
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    color: color,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Localized label with an English fallback when the key is missing
/// (`t()` returns the key itself in that case).
String fitTrackLabel(BuildContext context, String key, String fallback) {
  final value = context.t(key);
  return value == key ? fallback : value;
}

/// Bottom sheet (C7): radius 20 on top, drag handle, 50% black scrim.
Future<T?> showFitTrackSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final c = AppPalette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: c.surface,
    barrierColor: AppTheme.scrim,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FitTrackRadius.xl),
      ),
    ),
    builder: (ctx) {
      final colors = AppPalette.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: FitTrackSpacing.md),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: builder(ctx),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Confirm dialog (C6): radius 20, centered, optional 52px icon, buttons
/// stacked full width with the confirm first. Cancel is secondary and never
/// red; a destructive confirm uses `bad`. Callers pass localized labels.
/// Dismissal by tapping outside or back resolves to `false`.
Future<bool> showFitTrackConfirm({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  IconData? icon,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppTheme.scrim,
    builder: (ctx) {
      final c = AppPalette.of(ctx);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(FitTrackSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: destructive ? c.badSoft : c.accentSoft,
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: destructive ? c.bad : c.ink,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: FitTrackText.titleLg.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: FitTrackText.caption.copyWith(color: c.muted),
                ),
              ],
              const SizedBox(height: 14),
              FitTrackButton(
                label: confirmLabel,
                variant: destructive
                    ? FitTrackButtonVariant.danger
                    : FitTrackButtonVariant.primary,
                fullWidth: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: FitTrackSpacing.sm),
              FitTrackButton(
                label: cancelLabel,
                variant: FitTrackButtonVariant.secondary,
                fullWidth: true,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
