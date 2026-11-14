import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/fittrack_tokens.dart';
import 'fittrack_icons.dart';

/// Section title above a group of cards: 14 / 600 ink, sentence case, with
/// an optional accent link at the end.
class FitTrackSectionLabel extends StatelessWidget {
  const FitTrackSectionLabel({
    required this.title,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final hasAction = action != null && onAction != null;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 2,
        end: 2,
        bottom: hasAction ? 0 : FitTrackSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: FitTrackText.rowTitle.copyWith(color: colors.ink),
              ),
            ),
          ),
          if (hasAction)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(FitTrackRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: FitTrackSpacing.touchMin,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      action!,
                      style: FitTrackText.label.copyWith(color: colors.accent),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FitTrackStatRing extends StatelessWidget {
  const FitTrackStatRing({
    required this.progress,
    required this.color,
    this.size = 64,
    this.strokeWidth = 7,
    this.child,
    super.key,
  });

  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1).toDouble(),
          color: color,
          track: colors.line,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class FitTrackMiniRing extends StatelessWidget {
  const FitTrackMiniRing({
    required this.progress,
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
    this.done = false,
    super.key,
  });

  final double progress;
  final Color color;
  final IconData icon;
  final String value;
  final String label;
  final String sublabel;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Expanded(
      child: Semantics(
        container: true,
        label: '$label, $value, $sublabel${done ? ', done' : ''}',
        child: ExcludeSemantics(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FitTrackStatRing(
                    progress: progress,
                    color: done ? colors.ok : color,
                    child: Icon(icon, size: 18, color: color),
                  ),
                  if (done)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors.ok,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.bg, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Icon(FitIcons.check, size: 10, color: colors.bg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FitTrackSpacing.sm),
              Text(
                value,
                style: FitTrackText.title.copyWith(
                  color: colors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: FitTrackText.caption.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: FitTrackText.caption.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab screen header: surface with a `line` rule below, 20 / 600 title, a
/// 13px muted subtitle, 16px side padding and an optional trailing widget.
class FitTrackScreenHeader extends StatelessWidget {
  const FitTrackScreenHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Kept for older callers; the boards show no icon beside the title.
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        FitTrackSpacing.gutter,
        MediaQuery.paddingOf(context).top + FitTrackSpacing.md,
        FitTrackSpacing.gutter,
        FitTrackSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        FitTrackText.screenTitle.copyWith(color: colors.ink),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.label.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: FitTrackSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Pushed screen header: surface with a `line` rule below, a 44px back
/// chevron, 18 / 600 title, optional 13px muted subtitle and trailing widget.
class FitTrackTopBar extends StatelessWidget {
  const FitTrackTopBar({
    required this.title,
    required this.backLabel,
    required this.onBack,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Screen-reader label for the back button.
  final String backLabel;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        FitTrackSpacing.xs,
        MediaQuery.paddingOf(context).top + FitTrackSpacing.sm,
        FitTrackSpacing.sm,
        FitTrackSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: backLabel,
            child: ExcludeSemantics(
              child: InkResponse(
                onTap: onBack,
                radius: 24,
                child: SizedBox(
                  width: FitTrackSpacing.touchMin,
                  height: FitTrackSpacing.touchMin,
                  child: Icon(FitIcons.back, size: 20, color: colors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitTrackText.titleLg.copyWith(color: colors.ink),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.label.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Dashed rounded outline, for a card that is still to be filled in.
class FitTrackDashedBorder extends StatelessWidget {
  const FitTrackDashedBorder({
    required this.child,
    required this.color,
    this.radius = FitTrackRadius.card,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _DashedBorderPainter(color: color, radius: radius),
        child: child,
      );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Fixed-column grid whose rows take the height of their tallest cell, so
/// tiles never carry empty space the way a fixed aspect ratio does.
class FitTrackGrid extends StatelessWidget {
  const FitTrackGrid({
    required this.children,
    this.columns = 2,
    this.gap = 10,
    super.key,
  });

  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(
                  child: i + j < children.length
                      ? children[i + j]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }
}

/// Segmented control: a track (radius 10, padding 2) with 44px segments.
/// The selected segment is `surface`, radius 8, ink 600 with a soft shadow;
/// the others are muted 500.
class FitTrackSegmentedTabs extends StatelessWidget {
  const FitTrackSegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
    this.hero = false,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 13px labels, for four or more segments.
  final bool compact;

  /// The rounder, heavier control on the Nutrition hero board: 40px
  /// segments, 4px padding and gap, 800 / 600 labels.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroRadius = FitTrackRadius.hero(Theme.of(context).brightness);
    final segment = BorderRadius.circular(
      hero ? heroRadius * 0.6 : FitTrackRadius.control,
    );
    final base = compact ? FitTrackText.label : FitTrackText.rowTitle;
    final gap = hero ? 4.0 : 0.0;
    return Container(
      padding: EdgeInsets.all(hero ? 4 : 2),
      decoration: BoxDecoration(
        color: hero ? colors.line : colors.segTrack,
        borderRadius: BorderRadius.circular(
          hero ? heroRadius * 0.8 : FitTrackRadius.card,
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: index == 0 ? 0 : gap),
              child: Semantics(
              button: true,
              selected: active,
              label: labels[index],
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: segment,
                  child: Container(
                    height: hero ? 40 : FitTrackSpacing.touchMin,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: active ? colors.surface : Colors.transparent,
                      borderRadius: segment,
                      boxShadow: active && !hero
                          ? [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.45 : 0.12),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: base.copyWith(
                        color: active ? colors.ink : colors.muted,
                        fontWeight: hero
                            ? (active ? FontWeight.w800 : FontWeight.w600)
                            : (active ? FontWeight.w600 : FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          );
        }),
      ),
    );
  }
}
