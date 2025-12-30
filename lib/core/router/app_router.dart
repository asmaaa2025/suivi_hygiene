import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/home_screen.dart';
import '../../screens/login_page.dart';
import '../../features/entry/pages/entry_page.dart';
import '../../features/cleaning/pages/cleaning_page.dart';
import '../../features/cleaning/pages/tache_form_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/temperatures/pages/temperatures_list_page.dart';
import '../../features/temperatures/pages/temperature_form_page.dart';
import '../../features/temperatures/pages/appareils_management_page.dart';
import '../../features/receptions/pages/receptions_list_page.dart';
import '../../features/receptions/pages/reception_form_page.dart';
import '../../features/oil/pages/oil_changes_list_page.dart';
import '../../features/oil/pages/oil_change_form_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/labels/pages/labels_page.dart';
import '../../features/products/pages/products_list_page.dart';
import '../../features/settings/pages/settings_page.dart';

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
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/entry',
      builder: (context, state) => const EntryPage(),
    ),
    GoRoute(
      path: '/cleaning',
      builder: (context, state) => const CleaningPage(),
    ),
    GoRoute(
      path: '/temperatures',
      builder: (context, state) => const TemperaturesListPage(),
    ),
    GoRoute(
      path: '/receptions',
      builder: (context, state) => const ReceptionsListPage(),
    ),
    GoRoute(
      path: '/oil-changes',
      builder: (context, state) => const OilChangesListPage(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryPage(),
    ),
    GoRoute(
      path: '/labels',
      builder: (context, state) => const LabelsPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsListPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    // Cleaning tasks routes
    GoRoute(
      path: '/app/cleaning/taches/new',
      builder: (context, state) => const TacheFormPage(),
    ),
    GoRoute(
      path: '/app/cleaning/taches/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TacheFormPage(tacheId: id);
      },
    ),
    // Form pages routes
    GoRoute(
      path: '/temperatures/new',
      builder: (context, state) => const TemperatureFormPage(),
    ),
    GoRoute(
      path: '/receptions/new',
      builder: (context, state) => const ReceptionFormPage(),
    ),
    GoRoute(
      path: '/oil-changes/new',
      builder: (context, state) => const OilChangeFormPage(),
    ),
    // Appareils management
    GoRoute(
      path: '/appareils',
      builder: (context, state) => const AppareilsManagementPage(),
    ),
  ],
);
