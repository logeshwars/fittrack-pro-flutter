import 'package:go_router/go_router.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/forgot_password_screen.dart';
import '../core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/gamification/presentation/gamification_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/workouts/presentation/workout_screen.dart';
import '../features/workouts/presentation/workout_draft_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
import '../features/nutrition/presentation/food_draft_screen.dart';
import '../features/cardio/presentation/cardio_screen.dart';
import '../features/cardio/presentation/cardio_draft_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/progress/presentation/health_draft_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screens.dart';

final appRouter = GoRouter(
  initialLocation: '/today',
  redirect: (context, state) {
    if (!AppConfig.hasSupabase) return null;
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    final path = state.uri.path;
    final isPublicAuth = path == '/account' || path == '/forgot-password';

    if (!signedIn && !isPublicAuth) return '/account';
    if (signedIn && path == '/account') return '/today';
    return null;
  },
  routes: [
    GoRoute(path: '/account', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/achievements', builder: (context, state) => const GamificationScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings/personal', builder: (context, state) => const PersonalSettingsScreen()),
    GoRoute(path: '/settings/goals', builder: (context, state) => const GoalsSettingsScreen()),
    GoRoute(path: '/settings/alerts', builder: (context, state) => const AlertsSettingsScreen()),
    GoRoute(path: '/settings/theme', builder: (context, state) => const ThemeSettingsScreen()),
    GoRoute(path: '/settings/app-settings', builder: (context, state) => const AppSettingsScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/today', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/workout', builder: (context, state) => const WorkoutScreen(), routes: [
          GoRoute(path: 'draft', builder: (context, state) => const WorkoutDraftScreen()),
        ]),
        GoRoute(path: '/nutrition', builder: (context, state) => const NutritionScreen(), routes: [
          GoRoute(path: 'draft', builder: (context, state) => const FoodDraftScreen()),
        ]),
        GoRoute(path: '/cardio', builder: (context, state) => const CardioScreen(), routes: [
          GoRoute(path: 'draft', builder: (context, state) => CardioDraftScreen(activityType: state.uri.queryParameters['type'])),
        ]),
        GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen(), routes: [
          GoRoute(path: 'draft', builder: (context, state) => const HealthDraftScreen()),
        ]),
      ],
    ),
  ],
);
