import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/home_screen.dart';
import '../../screens/login_page.dart';
import '../../features/entry/pages/entry_page.dart';
import '../../features/cleaning/pages/cleaning_page.dart';

/// Application router configuration
final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final isLoggedIn = session != null;
    final isLoginRoute = state.matchedLocation == '/login';

    // If not logged in and not on login page, redirect to login
    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }

    // If logged in and on login page, redirect to home
    if (isLoggedIn && isLoginRoute) {
      return '/home';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/entry',
      builder: (context, state) => const EntryPage(),
    ),
    GoRoute(
      path: '/cleaning',
      builder: (context, state) => const CleaningPage(),
    ),
  ],
);
