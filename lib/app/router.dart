import 'package:go_router/go_router.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/workouts/presentation/workout_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
import '../features/cardio/presentation/cardio_screen.dart';
import '../features/progress/presentation/progress_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    GoRoute(path: '/account', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/today', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/workout', builder: (context, state) => const WorkoutScreen()),
        GoRoute(path: '/nutrition', builder: (context, state) => const NutritionScreen()),
        GoRoute(path: '/cardio', builder: (context, state) => const CardioScreen()),
        GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
      ],
    ),
  ],
);
