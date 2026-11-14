import 'package:flutter/material.dart';
import '../l10n/language_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/fittrack_tokens.dart';
import 'fittrack_icons.dart';

enum FitTrackButtonVariant { primary, secondary, tint, ghost, danger }

enum FitTrackButtonSize { sm, md, lg, pill }

/// Button. 44px tall (`lg` 48 for the call to action at the foot of a
/// page), radius 8, 14 / 600 label. One primary per view. Cancel is
/// secondary, never red. `sm` is 36px tall but keeps a 44px tap area.
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

  /// Radius 8 on every size, full pill for `pill`.
  double get _radius => size == FitTrackButtonSize.pill
      ? FitTrackRadius.pill
      : FitTrackRadius.control;

  TextStyle get _textStyle => switch (size) {
        FitTrackButtonSize.sm => FitTrackText.label,
        FitTrackButtonSize.md => FitTrackText.rowTitle,
        FitTrackButtonSize.lg => FitTrackText.rowTitle,
        FitTrackButtonSize.pill => FitTrackText.caption,
      };

  double get _hPad => switch (size) {
        FitTrackButtonSize.sm => 14.0,
        FitTrackButtonSize.md => 18.0,
        FitTrackButtonSize.lg => 18.0,
        FitTrackButtonSize.pill => 14.0,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final (bg, fg, border) = switch (variant) {
      FitTrackButtonVariant.primary => (c.accent, c.onAccent, c.accent),
      FitTrackButtonVariant.secondary => (c.surface, c.ink, c.lineStrong),
      FitTrackButtonVariant.tint => (c.accentSoft, c.accent, c.accentSoft),
      FitTrackButtonVariant.ghost => (
          Colors.transparent,
          c.accent,
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
                  Icon(icon, size: 16, color: fg),
                if (loading || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _textStyle.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
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
          style: FitTrackText.caption.copyWith(color: c.muted),
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
                  Icon(FitIcons.error, size: 14, color: c.textBad),
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
                  fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card: surface, 1px line, radius 10, padding 14. No shadow.
class FitTrackCard extends StatelessWidget {
  const FitTrackCard({
    required this.child,
    this.padding = const EdgeInsets.all(FitTrackSpacing.cardPad),
    this.onTap,
    this.borderColor,
    this.radius = FitTrackRadius.card,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Defaults to `line`. Pass `accent` for the card in focus.
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final radius = BorderRadius.circular(this.radius);
    return Material(
      color: c.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor ?? c.line),
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
    final radius = BorderRadius.circular(FitTrackRadius.card);
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
                                overline,
                                style: FitTrackText.caption.copyWith(
                                  color: domainColor,
                                  fontWeight: FontWeight.w600,
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
                                    color: c.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: FitTrackText.title.copyWith(color: c.ink),
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

/// Stat tile: caption label, 20 / 600 tabular value with an optional unit
/// in caption style, optional caption line. Padding 12.
class FitTrackStatTile extends StatelessWidget {
  const FitTrackStatTile({
    required this.value,
    required this.label,
    this.caption,
    this.unit,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final String? caption;

  /// Shown after the value in caption style, for example `kg`.
  final String? unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return FitTrackCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FitTrackSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FitTrackText.caption.copyWith(color: c.muted),
          ),
          const SizedBox(height: FitTrackSpacing.xs),
          FitTrackValue(value: value, unit: unit),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FitTrackText.caption.copyWith(color: c.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A 20 / 600 number with its unit in caption style: `52 min`, `9,840 kg`.
class FitTrackValue extends StatelessWidget {
  const FitTrackValue({
    required this.value,
    this.unit,
    this.style,
    this.textAlign,
    super.key,
  });

  final String value;
  final String? unit;

  /// Defaults to [FitTrackText.stat].
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Text.rich(
      TextSpan(
        text: value,
        children: [
          if (unit != null && unit!.isNotEmpty)
            TextSpan(
              text: ' $unit',
              style: FitTrackText.caption.copyWith(
                color: c.muted,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: (style ?? FitTrackText.stat).copyWith(color: c.ink),
    );
  }
}

/// One cell of a [FitTrackStatStrip].
class FitTrackStat {
  const FitTrackStat({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
}

/// Stat strip: equal columns in one card, split by `line` dividers. Each
/// cell is a caption label over a 20 / 600 value.
class FitTrackStatStrip extends StatelessWidget {
  const FitTrackStatStrip({required this.stats, super.key});

  final List<FitTrackStat> stats;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FitTrackRadius.card),
        border: Border.all(color: c.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stats.length; i++)
              Expanded(
                child: Semantics(
                  container: true,
                  label: [
                    stats[i].label,
                    stats[i].value,
                    if (stats[i].unit != null) stats[i].unit!,
                    if (stats[i].caption != null) stats[i].caption!,
                  ].join(' '),
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FitTrackSpacing.cardPad,
                        vertical: FitTrackSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : BorderDirectional(
                                start: BorderSide(color: c.line),
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                FitTrackText.caption.copyWith(color: c.muted),
                          ),
                          const SizedBox(height: FitTrackSpacing.xs),
                          FitTrackValue(
                            value: stats[i].value,
                            unit: stats[i].unit,
                          ),
                          if (stats[i].caption != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              stats[i].caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FitTrackText.caption
                                  .copyWith(color: c.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// List card: a 44px header (14 / 600 title, optional trailing text or
/// link) over rows split by `line` dividers.
class FitTrackListCard extends StatelessWidget {
  const FitTrackListCard({
    required this.children,
    this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String? title;

  /// Muted caption at the end of the header, for example a count.
  final String? trailing;

  /// Accent link at the end of the header, for example `See all`.
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final hasHeader = title != null;
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            SizedBox(
              height: FitTrackSpacing.touchMin,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: FitTrackSpacing.cardPad,
                  end: FitTrackSpacing.cardPad,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitTrackText.rowTitle.copyWith(color: c.ink),
                        ),
                      ),
                    ),
                    if (trailing != null)
                      Text(
                        trailing!,
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                    if (actionLabel != null)
                      FitTrackLink(label: actionLabel!, onTap: onAction),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < children.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: (i == 0 && !hasHeader)
                    ? null
                    : Border(top: BorderSide(color: c.line)),
              ),
              child: children[i],
            ),
        ],
      ),
    );
  }
}

/// Row inside a [FitTrackListCard]: 14 / 600 title, caption line, optional
/// leading and trailing widgets. 64px minimum height, 14px side padding.
class FitTrackRow extends StatelessWidget {
  const FitTrackRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
    this.chevron = false,
    this.endPadding = FitTrackSpacing.cardPad,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  /// Draws the 16px disclosure chevron after [trailing].
  final bool chevron;

  /// 14 by default; 6 when [trailing] is a 44px icon button.
  final double endPadding;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: FitTrackSpacing.cardPad,
          end: endPadding,
          top: FitTrackSpacing.sm,
          bottom: FitTrackSpacing.sm,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: FitTrackSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FitTrackText.rowTitle.copyWith(color: c.ink),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.caption.copyWith(color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: FitTrackSpacing.md),
              trailing!,
            ],
            if (chevron) ...[
              const SizedBox(width: FitTrackSpacing.sm),
              Icon(FitIcons.chevronRight, size: 16, color: c.chevron),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Accent text link, 13 / 600, with a 44px tap height: `See all`, `+ New`.
class FitTrackLink extends StatelessWidget {
  const FitTrackLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FitTrackRadius.control),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: FitTrackSpacing.touchMin,
            ),
            child: Align(
              widthFactor: 1,
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Text(
                  label,
                  style: FitTrackText.label.copyWith(color: c.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small tag, 11 / 700, radius 10: the gold `PR` mark by default.
class FitTrackTag extends StatelessWidget {
  const FitTrackTag({
    required this.label,
    this.background,
    this.foreground,
    super.key,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? c.warnSoft,
        borderRadius: BorderRadius.circular(FitTrackRadius.card),
      ),
      child: Text(
        label,
        style: FitTrackText.overline.copyWith(
          color: foreground ?? c.warn,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// A 32px rounded square holding a domain icon on a soft tint of its color.
class FitTrackIconTile extends StatelessWidget {
  const FitTrackIconTile({
    required this.icon,
    required this.color,
    this.size = 32,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(FitTrackRadius.control),
        ),
        child: Icon(icon, size: size * 0.56, color: color),
      );
}

/// Search field: 44px, radius 10, `line-strong` border, 18px muted glass.
class FitTrackSearchField extends StatelessWidget {
  const FitTrackSearchField({
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.height = FitTrackSpacing.controlMd,
    this.trailing,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsetsDirectional.only(start: FitTrackSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FitTrackRadius.card),
        border: Border.all(color: c.lineStrong),
      ),
      child: Row(
        children: [
          Icon(FitIcons.search, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: c.accent,
              style: FitTrackText.title.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: FitTrackText.title.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w400,
                ),
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else
            const SizedBox(width: FitTrackSpacing.md),
        ],
      ),
    );
  }
}

/// Progress bar: 5px, radius 3, `line` track. Fill is accent by default,
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
            height: 5,
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

/// Filter chip: 44px pill, surface with a `line-strong` outline, 13 / 500;
/// selected is `ink` with an on-accent 13 / 600 label.
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
          color: selected ? c.ink : c.surface,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              height: FitTrackSpacing.touchMin,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: selected ? c.ink : c.lineStrong),
              ),
              child: Text(
                label,
                style: FitTrackText.label.copyWith(
                  color: selected ? c.bg : c.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab bar: 64px, 22px icon + 11px label. Active is accent 700 with a 2px
/// accent marker; inactive is muted 600. Tab order: Today, Workout, Nutrition,
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

  /// Content height; the device's bottom inset is added below it.
  static const height = 64.0;

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
              final color = selected ? c.accent : c.muted;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: labels[i],
                  child: ExcludeSemantics(
                    child: InkResponse(
                      key: Key('fittrack-tab-$i'),
                      onTap: () => onSelected(i),
                      radius: 36,
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
                                const SizedBox(height: FitTrackSpacing.xs),
                                Text(
                                  labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 14 / 11,
                                    color: color,
                                    fontWeight: selected
                                        ? FontWeight.w700
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
                style: FitTrackText.titleLg.copyWith(color: c.ink),
              ),
              if (message != null) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: FitTrackText.label.copyWith(
                    color: c.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: FitTrackSpacing.lg),
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
