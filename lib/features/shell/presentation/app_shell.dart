import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});
  final Widget child;

  static const _paths = ['/today', '/workout', '/nutrition', '/cardio', '/progress'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final colors = AppPalette.of(context);
    final index = _paths.indexWhere(
      (path) => location == path || location.startsWith('$path/'),
    );
    final selectedIndex = index < 0 ? 0 : index;

    const icons = [
      Icons.today_outlined,
      Icons.fitness_center_outlined,
      Icons.restaurant_outlined,
      Icons.directions_run_outlined,
      Icons.insights_outlined,
    ];
    const selectedIcons = [
      Icons.today,
      Icons.fitness_center,
      Icons.restaurant,
      Icons.directions_run,
      Icons.insights,
    ];
    const domains = [
      AppColors.recovery,
      AppColors.workout,
      AppColors.nutrition,
      AppColors.cardio,
      AppColors.xp,
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.header,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: List.generate(_paths.length, (tabIndex) {
                final selected = selectedIndex == tabIndex;
                final color = selected ? domains[tabIndex] : colors.faint;
                return Expanded(
                  child: InkResponse(
                    key: Key('fittrack-tab-$tabIndex'),
                    onTap: () => context.go(_paths[tabIndex]),
                    radius: 30,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 150),
                          scale: selected ? 1.08 : 1,
                          child: Icon(
                            selected ? selectedIcons[tabIndex] : icons[tabIndex],
                            size: 26,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: selected ? 16 : 4,
                          height: 3,
                          decoration: BoxDecoration(
                            color: selected ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
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
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
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
