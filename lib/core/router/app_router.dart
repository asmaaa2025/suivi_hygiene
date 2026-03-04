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
import '../../features/oil/pages/oil_changes_history_page.dart';
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
import '../../features/haccp/pages/haccp_hub_page.dart';
import '../../features/haccp/pages/alerts_inbox_page.dart';
import '../../features/haccp/pages/nc_list_page.dart';
import '../../features/haccp/pages/nc_detail_page.dart';
import '../../features/haccp/pages/plan_rappel_page.dart';
import '../../features/haccp/pages/tableau_allergenes_page.dart';
import '../../features/haccp/pages/synthese_hebdomadaire_page.dart';
import '../../modules/haccp/documents/pages/documents_home_screen.dart';
import '../../modules/haccp/documents/pages/document_detail_screen.dart';
import '../../modules/haccp/documents/pages/document_edit_screen.dart';
import '../../modules/haccp/documents/models.dart';
import '../../features/products/pages/product_form_page.dart';
import '../../features/admin/pages/rh_hub_page.dart';

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
          path: '/app/oil-history',
          builder: (context, state) => const OilChangesHistoryPage(),
        ),
        GoRoute(
          path: '/app/entry',
          builder: (context, state) => const EntryPage(),
        ),
        GoRoute(
          path: '/app/haccp',
          builder: (context, state) => const HaccpHubPage(),
        ),
        GoRoute(
          path: '/app/temperatures-history',
          redirect: (context, state) => '/app/temperatures',
        ),
        GoRoute(
          path: '/app/receptions-history',
          redirect: (context, state) => '/app/receptions',
        ),
        GoRoute(
          path: '/app/cleaning-history',
          redirect: (context, state) => '/app/cleaning',
        ),
        GoRoute(
          path: '/app/oil-history',
          redirect: (context, state) => '/app/oil-history',
        ),
        GoRoute(
          path: '/app/alerts/list',
          builder: (context, state) => const AlertsInboxPage(),
        ),
        GoRoute(
          path: '/app/alerts/nc/new',
          builder: (context, state) => const NCDetailPage(),
        ),
        GoRoute(
          path: '/app/alerts/nc/history',
          builder: (context, state) => const NCListPage(),
        ),
        GoRoute(
          path: '/app/alerts/nc/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return NCDetailPage(ncId: id);
          },
        ),
        GoRoute(
          path: '/app/plan-rappel',
          builder: (context, state) => const PlanRappelPage(),
        ),
        GoRoute(
          path: '/app/tableau-allergenes',
          builder: (context, state) => const TableauAllergenesPage(),
        ),
        GoRoute(
          path: '/app/documents',
          builder: (context, state) => const DocumentsHomeScreen(),
        ),
        GoRoute(
          path: '/app/documents/upload',
          redirect: (context, state) => '/app/documents',
        ),
        GoRoute(
          path: '/app/documents/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DocumentDetailScreen(documentId: id);
          },
        ),
        GoRoute(
          path: '/app/documents/:id/edit',
          redirect: (context, state) {
            if (state.extra == null) return '/app/documents';
            return null;
          },
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DocumentEditScreen(
              documentId: id,
              document: state.extra! as Document,
            );
          },
        ),
        GoRoute(
          path: '/app/synthese-hebdomadaire',
          builder: (context, state) => const SyntheseHebdomadairePage(),
        ),
        GoRoute(
          path: '/app/products/new',
          builder: (context, state) => const ProductFormPage(),
        ),
        GoRoute(
          path: '/app/products/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ProductFormPage(productId: id);
          },
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
          path: '/admin/oil-history',
          builder: (context, state) => const OilChangesHistoryPage(),
        ),
        GoRoute(
          path: '/admin/entry',
          builder: (context, state) => const EntryPage(),
        ),
        GoRoute(
          path: '/admin/haccp',
          builder: (context, state) => const HaccpHubPage(),
        ),
        GoRoute(
          path: '/admin/rh-hub',
          builder: (context, state) => const RhHubPage(),
        ),
        GoRoute(
          path: '/admin/temperatures-history',
          redirect: (context, state) => '/admin/temperatures',
        ),
        GoRoute(
          path: '/admin/receptions-history',
          redirect: (context, state) => '/admin/receptions',
        ),
        GoRoute(
          path: '/admin/cleaning-history',
          redirect: (context, state) => '/admin/cleaning',
        ),
        GoRoute(
          path: '/admin/oil-history',
          redirect: (context, state) => '/admin/oil-history',
        ),
        GoRoute(
          path: '/admin/alerts/list',
          builder: (context, state) => const AlertsInboxPage(),
        ),
        GoRoute(
          path: '/admin/alerts/nc/new',
          builder: (context, state) => const NCDetailPage(),
        ),
        GoRoute(
          path: '/admin/alerts/nc/history',
          builder: (context, state) => const NCListPage(),
        ),
        GoRoute(
          path: '/admin/alerts/nc/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return NCDetailPage(ncId: id);
          },
        ),
        GoRoute(
          path: '/admin/plan-rappel',
          builder: (context, state) => const PlanRappelPage(),
        ),
        GoRoute(
          path: '/admin/tableau-allergenes',
          builder: (context, state) => const TableauAllergenesPage(),
        ),
        GoRoute(
          path: '/admin/documents',
          builder: (context, state) => const DocumentsHomeScreen(),
        ),
        GoRoute(
          path: '/admin/documents/upload',
          redirect: (context, state) => '/admin/documents',
        ),
        GoRoute(
          path: '/admin/documents/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DocumentDetailScreen(documentId: id);
          },
        ),
        GoRoute(
          path: '/admin/documents/:id/edit',
          redirect: (context, state) {
            if (state.extra == null) return '/admin/documents';
            return null;
          },
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DocumentEditScreen(
              documentId: id,
              document: state.extra! as Document,
            );
          },
        ),
        GoRoute(
          path: '/admin/synthese-hebdomadaire',
          builder: (context, state) => const SyntheseHebdomadairePage(),
        ),
        GoRoute(
          path: '/admin/products/new',
          builder: (context, state) => const ProductFormPage(),
        ),
        GoRoute(
          path: '/admin/products/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ProductFormPage(productId: id);
          },
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
      path: '/products/new',
      builder: (context, state) => const ProductFormPage(),
    ),
    GoRoute(
      path: '/products/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProductFormPage(productId: id);
      },
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
