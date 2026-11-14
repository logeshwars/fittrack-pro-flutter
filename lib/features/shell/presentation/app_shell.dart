import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_icons.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});
  final Widget child;

  static const _paths = [
    '/today',
    '/workout',
    '/nutrition',
    '/cardio',
    '/progress'
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _paths.indexWhere(
      (path) => location == path || location.startsWith('$path/'),
    );
    final selectedIndex = index < 0 ? 0 : index;

    Widget tabIcon(int tab, Color color, {required bool focused}) =>
        _NavIcon(tab: tab, color: color);
    final labels = [
      fitTrackLabel(context, 'common:today', 'Today'),
      fitTrackLabel(context, 'workout:title', 'Workout'),
      fitTrackLabel(context, 'nutrition:title', 'Nutrition'),
      fitTrackLabel(context, 'common:cardioTitle', 'Cardio'),
      fitTrackLabel(context, 'progress:title', 'Progress'),
    ];

    return Scaffold(
      // Tab screens draw their own header or hero under the status bar.
      body: child,
      bottomNavigationBar: FitTrackTabBar(
        selectedIndex: selectedIndex,
        labels: labels,
        iconBuilder: tabIcon,
        onSelected: (tab) => context.go(_paths[tab]),
      ),
    );
  }
}

/// The five tab glyphs, drawn exactly as in the design boards: 24 grid,
/// 2px stroke, round caps and joins.
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.tab, required this.color});
  final int tab;
  final Color color;

  static const _shapes = [
    // Today
    '<rect x="3" y="3" width="7" height="7" rx="1.5"/>'
        '<rect x="14" y="3" width="7" height="7" rx="1.5"/>'
        '<rect x="3" y="14" width="7" height="7" rx="1.5"/>'
        '<rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    // Workout
    '<path d="M6.5 6.5v11M17.5 6.5v11M3.5 9v6M20.5 9v6M6.5 12h11"/>',
    // Nutrition
    '<path d="M6 3v8M9 3v8M6 7h3M7.5 11v10M17 3c-2 2-3 5-3 8h3v10"/>',
    // Cardio
    '<path d="M3 12h4l2-6 4 12 2-6h6"/>',
    // Progress
    '<path d="M5 20v-7M12 20V5M19 20v-10"/>',
  ];

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="#000000" stroke-width="2" '
        'stroke-linecap="round" stroke-linejoin="round">'
        '${_shapes[tab.clamp(0, _shapes.length - 1)]}</svg>',
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: colors.muted)),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(FitTrackRadius.card),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            children: [
              Icon(FitIcons.placeholder, size: 36, color: colors.faint),
              const SizedBox(height: 12),
              Text(
                '$title module coming in a later batch',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.subtext),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
