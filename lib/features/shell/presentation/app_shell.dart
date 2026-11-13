import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/custom_icons.dart';
import '../../../core/widgets/fittrack_components.dart';

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
        switch (tab) {
          0 => TabTodayIcon(size: 22, color: color, focused: focused),
          1 => TabWorkoutIcon(size: 22, color: color, focused: focused),
          2 => TabNutritionIcon(size: 22, color: color, focused: focused),
          3 => TabCardioIcon(size: 22, color: color, focused: focused),
          _ => TabProgressIcon(size: 22, color: color, focused: focused),
        };
    final labels = [
      fitTrackLabel(context, 'common:today', 'Today'),
      fitTrackLabel(context, 'workout:title', 'Workout'),
      fitTrackLabel(context, 'nutrition:title', 'Nutrition'),
      fitTrackLabel(context, 'common:cardioTitle', 'Cardio'),
      fitTrackLabel(context, 'progress:title', 'Progress'),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      bottomNavigationBar: FitTrackTabBar(
        selectedIndex: selectedIndex,
        labels: labels,
        iconBuilder: tabIcon,
        onSelected: (tab) => context.go(_paths[tab]),
      ),
    );
  }
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
            borderRadius: BorderRadius.circular(FitTrackRadius.lg),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            children: [
              Icon(Icons.construction_outlined, size: 36, color: colors.faint),
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
