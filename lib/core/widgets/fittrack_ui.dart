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
    this.size = 62,
    this.strokeWidth = 5,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: isDark
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1).toDouble(),
          color: color,
          track: colors.border2,
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
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              FitTrackStatRing(
                progress: progress,
                color: color,
                child: Icon(icon, size: 18, color: color),
              ),
              if (done)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '✓',
                      style: TextStyle(
                        color: Color(0xFF04140A),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: FitTrackText.title.copyWith(
              color: done ? color : colors.text,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            style: FitTrackText.micro.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 1),
          Text(
            sublabel,
            style: TextStyle(fontSize: 9, color: colors.faint),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      decoration: BoxDecoration(
        color: colors.header,
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
                Text(title, style: FitTrackText.screenTitle.copyWith(color: colors.text)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colors.muted),
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
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index == selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 3,
              right: index == labels.length - 1 ? 0 : 3,
            ),
            child: Material(
              color: active ? colors.accent : colors.card,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? colors.accent : colors.border2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? colors.accentText : colors.subtext,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
