import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/shell/presentation/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/today', builder: (context, state) => const FeaturePlaceholder(title: 'Today', subtitle: 'Your daily fitness overview')),
        GoRoute(path: '/workout', builder: (context, state) => const FeaturePlaceholder(title: 'Workout', subtitle: 'Log workouts and exercises')),
        GoRoute(path: '/nutrition', builder: (context, state) => const FeaturePlaceholder(title: 'Nutrition', subtitle: 'Track food and macros')),
        GoRoute(path: '/cardio', builder: (context, state) => const FeaturePlaceholder(title: 'Cardio', subtitle: 'Track cardio sessions')),
        GoRoute(path: '/progress', builder: (context, state) => const FeaturePlaceholder(title: 'Progress', subtitle: 'Review your progress')),
      ],
    ),
  ],
);
