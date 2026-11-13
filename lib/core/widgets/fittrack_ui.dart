import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/fittrack_tokens.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: FitTrackSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: FitTrackText.overline.copyWith(color: colors.muted),
            ),
          ),
          if (action != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(FitTrackRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitTrackSpacing.xs,
                  vertical: FitTrackSpacing.xs,
                ),
                child: Text(
                  action!,
                  style: FitTrackText.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
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
                        child: Icon(Icons.check, size: 10, color: colors.bg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FitTrackSpacing.sm),
              Text(
                value,
                style: FitTrackText.title.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                style: FitTrackText.overline.copyWith(color: colors.muted),
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
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.xxl, FitTrackSpacing.md, FitTrackSpacing.xxl, 14),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 26, color: colors.accent),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        FitTrackText.screenTitle.copyWith(color: colors.text)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitTrackText.caption.copyWith(color: colors.muted),
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

/// Segmented control (C2/C7): a `line` track (radius 12, padding 3) with a
/// `surface` selected segment, ink w800 label and a soft shadow.
class FitTrackSegmentedTabs extends StatelessWidget {
  const FitTrackSegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final segment = BorderRadius.circular(FitTrackRadius.md);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.line,
        borderRadius: BorderRadius.circular(FitTrackRadius.lg),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selectedIndex;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              label: labels[index],
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: segment,
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: active ? colors.surface : Colors.transparent,
                      borderRadius: segment,
                      boxShadow: active
                          ? const [
                              BoxShadow(
                                color: Color(0x2E000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: FitTrackText.label.copyWith(
                        color: active ? colors.ink : colors.muted,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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
