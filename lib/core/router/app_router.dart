import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/entry/pages/entry_page.dart';
import '../../features/cleaning/pages/cleaning_page.dart';
import '../../features/cleaning/pages/tache_form_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/actions/pages/actions_dashboard_page.dart';
import '../../features/temperatures/pages/temperatures_list_page.dart';
import '../../features/temperatures/pages/temperature_form_page.dart';
import '../../features/temperatures/pages/appareils_management_page.dart';
import '../../features/receptions/pages/receptions_list_page.dart';
import '../../features/receptions/pages/reception_form_page.dart';
import '../../features/oil/pages/oil_changes_list_page.dart';
import '../../features/oil/pages/suivi_huile_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/labels/pages/labels_page.dart';
import '../../features/products/pages/products_list_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/suppliers/pages/suppliers_list_page.dart';
import '../../features/suppliers/pages/supplier_form_page.dart';
import '../../features/employees/pages/employees_list_page.dart';
import '../../features/employees/pages/employee_form_page.dart';
import '../../features/auth/pages/employee_selection_page.dart';
import '../../features/auth/pages/admin_code_page.dart';
import '../../services/employee_session_service.dart';
import '../../services/auth_service.dart';
import '../../features/shells/normal_shell.dart';
import '../../features/shells/admin_shell.dart';
import '../../features/clock/pages/pointage_page.dart';
import '../../features/admin/pages/personnel_registry_page.dart';
import '../../features/admin/pages/personnel_form_page.dart';
import '../../features/admin/pages/admin_clock_history_page.dart';

/// Application router configuration with RBAC and dual shells
final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final isLoggedIn = session != null;
    final location = state.matchedLocation;

    // Public routes that don't require authentication
    final publicRoutes = ['/login', '/employee-selection', '/admin-code'];
    final isPublicRoute = publicRoutes.contains(location);

    // If not logged in and not on public route, redirect to login
    if (!isLoggedIn && !isPublicRoute) {
      debugPrint('[Router] Not logged in, redirecting to login');
      return '/login';
    }

    // If logged in, check role and route access
    if (isLoggedIn) {
      // Initialize services
      final employeeSessionService = EmployeeSessionService();
      await employeeSessionService.initialize();
      final authService = AuthService();
      final userRole = await authService.getCurrentUserRole();

      debugPrint(
        '[Router] User role: ${userRole.toValue()}, location: $location',
      );

      // ALWAYS redirect to employee-selection first when app starts
      // This ensures "Qui es-tu ?" is shown every time the app opens
      // Only redirect if coming from login or root, not if already navigating within app
      if (location == '/login') {
        // After login, always go to employee selection
        return '/employee-selection';
      }

      // Allow access to employee-selection and admin-code pages
      if (location == '/employee-selection' || location == '/admin-code') {
        return null; // Allow access
      }

      // Employees routes - Admin only (employees should not see admin info like codes)
      // Allow access for admins even without employee selected (needed to create first employee)
      if (location.startsWith('/employees') ||
          location.startsWith('/admin/employees')) {
        if (!userRole.isAdmin) {
          debugPrint('[Router] Access denied to employees route (admin only)');
          return userRole.isAdmin ? '/admin/home' : '/app/home';
        }
        // Allow access for admins even without employee selected (needed to create first employee)
        return null;
      }

      // If no employee selected, redirect to employee-selection
      if (!employeeSessionService.hasEmployee) {
        return '/employee-selection';
      }

      // RBAC: Check admin routes
      if (location.startsWith('/admin')) {
        if (!userRole.canAccessAdminShell) {
          debugPrint(
            '[Router] Access denied to admin route, redirecting to app',
          );
          return '/app/home';
        }
      }

      // RBAC: Check normal app routes
      if (location.startsWith('/app')) {
        if (!userRole.canAccessNormalShell) {
          debugPrint('[Router] Access denied to app route');
          return '/login';
        }
      }

      // Legacy routes: redirect to new structure
      if (location == '/home' || location == '/') {
        if (userRole.isAdmin) {
          return '/admin/home';
        } else {
          return '/app/home';
        }
      }
    }

    return null; // No redirect needed
  },
  routes: [
    // Public routes
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/employee-selection',
      builder: (context, state) => const EmployeeSelectionPage(),
    ),
    GoRoute(
      path: '/admin-code',
      builder: (context, state) => const AdminCodePage(),
    ),

    // Normal shell routes (/app/*)
    ShellRoute(
      builder: (context, state, child) {
        return NormalShell(location: state.matchedLocation, child: child);
      },
      routes: [
        GoRoute(
          path: '/app/home',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/app/clock',
          builder: (context, state) => const PointagePage(),
        ),
        GoRoute(
          path: '/app/temperatures',
          builder: (context, state) => const TemperaturesListPage(),
        ),
        GoRoute(
          path: '/app/receptions',
          builder: (context, state) => const ReceptionsListPage(),
        ),
        GoRoute(
          path: '/app/cleaning',
          builder: (context, state) => const CleaningPage(),
        ),
        GoRoute(
          path: '/app/history',
          builder: (context, state) => const HistoryPage(),
        ),
        // Form pages
        GoRoute(
          path: '/app/temperatures/new',
          builder: (context, state) => const TemperatureFormPage(),
        ),
        GoRoute(
          path: '/app/temperatures/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TemperatureFormPage(temperatureId: id);
          },
        ),
        GoRoute(
          path: '/app/receptions/new',
          builder: (context, state) => const ReceptionFormPage(),
        ),
        GoRoute(
          path: '/app/receptions/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ReceptionFormPage(receptionId: id);
          },
        ),
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
        GoRoute(
          path: '/app/oil',
          builder: (context, state) => const SuiviHuilePage(),
        ),
        GoRoute(
          path: '/app/entry',
          builder: (context, state) => const EntryPage(),
        ),
      ],
    ),

    // Employees routes (admin only) - Outside shell to allow access without employee selected
    GoRoute(
      path: '/admin/employees',
      builder: (context, state) => const EmployeesListPage(),
    ),
    GoRoute(
      path: '/admin/employees/new',
      builder: (context, state) => const EmployeeFormPage(),
    ),
    GoRoute(
      path: '/admin/employees/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EmployeeFormPage(employeeId: id);
      },
    ),

    // Admin shell routes (/admin/*)
    ShellRoute(
      builder: (context, state, child) {
        return AdminShell(location: state.matchedLocation, child: child);
      },
      routes: [
        // Same pages as normal shell
        GoRoute(
          path: '/admin/home',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/admin/clock',
          builder: (context, state) => const PointagePage(),
        ),
        GoRoute(
          path: '/admin/temperatures',
          builder: (context, state) => const TemperaturesListPage(),
        ),
        GoRoute(
          path: '/admin/receptions',
          builder: (context, state) => const ReceptionsListPage(),
        ),
        GoRoute(
          path: '/admin/cleaning',
          builder: (context, state) => const CleaningPage(),
        ),
        GoRoute(
          path: '/admin/history',
          builder: (context, state) => const HistoryPage(),
        ),
        // Form pages
        GoRoute(
          path: '/admin/temperatures/new',
          builder: (context, state) => const TemperatureFormPage(),
        ),
        GoRoute(
          path: '/admin/temperatures/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TemperatureFormPage(temperatureId: id);
          },
        ),
        GoRoute(
          path: '/admin/receptions/new',
          builder: (context, state) => const ReceptionFormPage(),
        ),
        GoRoute(
          path: '/admin/receptions/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ReceptionFormPage(receptionId: id);
          },
        ),
        GoRoute(
          path: '/admin/cleaning/taches/new',
          builder: (context, state) => const TacheFormPage(),
        ),
        GoRoute(
          path: '/admin/cleaning/taches/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TacheFormPage(tacheId: id);
          },
        ),
        // Admin-specific pages
        GoRoute(
          path: '/admin/rh',
          builder: (context, state) => const PersonnelRegistryPage(),
        ),
        GoRoute(
          path: '/admin/rh/new',
          builder: (context, state) => const PersonnelFormPage(),
        ),
        GoRoute(
          path: '/admin/rh/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return PersonnelFormPage(personnelId: id);
          },
        ),
        GoRoute(
          path: '/admin/clock-history',
          builder: (context, state) => const AdminClockHistoryPage(),
        ),
        GoRoute(
          path: '/admin/oil',
          builder: (context, state) => const SuiviHuilePage(),
        ),
        GoRoute(
          path: '/admin/entry',
          builder: (context, state) => const EntryPage(),
        ),
      ],
    ),

    // Legacy routes (for backward compatibility - redirect handled in redirect function)
    GoRoute(
      path: '/home',
      redirect: (context, state) async {
        final authService = AuthService();
        final userRole = await authService.getCurrentUserRole();
        return userRole.isAdmin ? '/admin/home' : '/app/home';
      },
    ),
    GoRoute(
      path: '/actions',
      builder: (context, state) => const ActionsDashboardPage(),
    ),
    GoRoute(
      path: '/entry',
      redirect: (context, state) async {
        final authService = AuthService();
        final userRole = await authService.getCurrentUserRole();
        return userRole.isAdmin ? '/admin/entry' : '/app/entry';
      },
    ),
    GoRoute(path: '/cleaning', redirect: (context, state) => '/app/cleaning'),
    GoRoute(
      path: '/temperatures',
      redirect: (context, state) => '/app/temperatures',
    ),
    GoRoute(
      path: '/receptions',
      redirect: (context, state) => '/app/receptions',
    ),
    GoRoute(
      path: '/oil-changes',
      builder: (context, state) => const OilChangesListPage(),
    ),
    GoRoute(path: '/history', redirect: (context, state) => '/app/history'),
    GoRoute(path: '/labels', builder: (context, state) => const LabelsPage()),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsListPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    // Form pages routes (legacy)
    GoRoute(
      path: '/temperatures/new',
      redirect: (context, state) => '/app/temperatures/new',
    ),
    GoRoute(
      path: '/receptions/new',
      redirect: (context, state) => '/app/receptions/new',
    ),
    GoRoute(
      path: '/oil-changes/new',
      redirect: (context, state) async {
        final authService = AuthService();
        final userRole = await authService.getCurrentUserRole();
        return userRole.isAdmin ? '/admin/oil' : '/app/oil';
      },
    ),
    // Appareils management
    GoRoute(
      path: '/appareils',
      builder: (context, state) => const AppareilsManagementPage(),
    ),
    // Suppliers routes
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => const SuppliersListPage(),
    ),
    GoRoute(
      path: '/suppliers/new',
      builder: (context, state) => const SupplierFormPage(),
    ),
    GoRoute(
      path: '/suppliers/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return SupplierFormPage(supplierId: id);
      },
    ),
    // Employees routes
    GoRoute(
      path: '/employees',
      builder: (context, state) => const EmployeesListPage(),
    ),
    GoRoute(
      path: '/employees/new',
      builder: (context, state) => const EmployeeFormPage(),
    ),
    GoRoute(
      path: '/employees/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EmployeeFormPage(employeeId: id);
      },
    ),
  ],
);
