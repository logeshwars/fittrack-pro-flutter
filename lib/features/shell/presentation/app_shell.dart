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
    final index = _paths.indexWhere((path) => location == path || location.startsWith('$path/'));
    return Scaffold(
      appBar: AppBar(
        title: const Text('FITTRACK PRO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        actions: [
          IconButton(
            tooltip: 'Achievements',
            onPressed: () => context.push('/achievements'),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (value) => context.go(_paths[value]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Nutrition'),
          NavigationDestination(icon: Icon(Icons.directions_run_outlined), selectedIcon: Icon(Icons.directions_run), label: 'Cardio'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
        ],
      ),
    );
  }
}

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.lightMuted)),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.construction_outlined, size: 36),
                const SizedBox(height: 12),
                Text('$title module coming in a later batch', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
