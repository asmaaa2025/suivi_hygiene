import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

/// Centralized navigation helpers for consistent routing
class NavigationHelpers {
  /// Navigate to role-based home (landing page)
  static Future<void> goHome(BuildContext context) async {
    debugPrint('[Router] Navigating to Home');
    final authService = AuthService();
    final userRole = await authService.getCurrentUserRole();
    if (userRole.isAdmin) {
      context.go('/admin/home');
    } else {
      context.go('/app/home');
    }
  }

  /// Navigate to HACCP hub (8 tiles)
  static Future<void> goHaccpHub(BuildContext context) async {
    debugPrint('[Router] Navigating to HACCP Hub');
    final authService = AuthService();
    final userRole = await authService.getCurrentUserRole();
    if (userRole.isAdmin) {
      context.go('/admin/haccp-hub');
    } else {
      context.go('/app/haccp-hub');
    }
  }

  /// Navigate to RH hub (2 tiles: Personnel + Historique Pointage)
  static Future<void> goRhHub(BuildContext context) async {
    debugPrint('[Router] Navigating to RH Hub');
    context.go('/admin/rh-hub');
  }

  /// Navigate to Pointage page
  static Future<void> goPointage(BuildContext context) async {
    debugPrint('[Router] Navigating to Pointage');
    final authService = AuthService();
    final userRole = await authService.getCurrentUserRole();
    if (userRole.isAdmin) {
      context.go('/admin/clock');
    } else {
      context.go('/app/clock');
    }
  }

  /// Navigate to History hub
  static Future<void> goHistoryHub(BuildContext context) async {
    debugPrint('[Router] Navigating to History Hub');
    final authService = AuthService();
    final userRole = await authService.getCurrentUserRole();
    if (userRole.isAdmin) {
      context.go('/admin/history');
    } else {
      context.go('/app/history');
    }
  }

  /// Get the appropriate back route based on current location
  static Future<String?> getBackRoute(BuildContext context) async {
    final location = GoRouterState.of(context).matchedLocation;
    final authService = AuthService();
    final userRole = await authService.getCurrentUserRole();
    final prefix = userRole.isAdmin ? '/admin' : '/app';

    // HACCP module pages -> HACCP hub
    if (location.contains('/temperatures') ||
        location.contains('/receptions') ||
        location.contains('/cleaning') ||
        location.contains('/oil')) {
      return '$prefix/haccp-hub';
    }

    // RH pages -> RH hub
    if (location.contains('/rh') || location.contains('/clock-history')) {
      return '/admin/rh-hub';
    }

    // Pointage -> Home (role landing)
    if (location.contains('/clock')) {
      return '$prefix/home';
    }

    // Historiques HACCP (temperatures-history, etc.) -> HACCP hub
    if (location.contains('/temperatures-history') ||
        location.contains('/receptions-history') ||
        location.contains('/oil-history') ||
        location.contains('/cleaning-history')) {
      return '$prefix/haccp-hub';
    }

    // Page Historique unifiée -> HACCP hub
    if (location.contains('/history')) {
      return '$prefix/haccp-hub';
    }

    // Default: go home
    return '$prefix/home';
  }

  /// Navigate back using appropriate route
  static Future<void> goBack(BuildContext context) async {
    final backRoute = await getBackRoute(context);
    if (backRoute != null) {
      debugPrint('[Router] Navigating back to: $backRoute');
      context.go(backRoute);
    } else {
      debugPrint('[Router] No back route, using Navigator.pop');
      if (context.canPop()) {
        context.pop();
      }
    }
  }
}
