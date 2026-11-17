import 'package:go_router/go_router.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/home/home_shell.dart';
import '../../presentation/onboarding/goal_screen.dart';
import '../../presentation/onboarding/result_screen.dart';
import '../../presentation/onboarding/survey_screen.dart';
import '../../presentation/splash/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/goal',
      builder: (context, state) => const GoalScreen(),
    ),
    GoRoute(
      path: '/survey',
      builder: (context, state) => const SurveyScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) => const ResultScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeShell(),
    ),
  ],
);