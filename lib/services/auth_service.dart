import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_role.dart';
import '../data/models/employee.dart';
import 'employee_session_service.dart';

/// Auth service with role resolution
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  final EmployeeSessionService _employeeSession = EmployeeSessionService();

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Get current user role
  /// Priority: 1) Employee.isAdmin -> admin, 2) Employee.role -> manager/employee, 3) Default -> employee
  Future<UserRole> getCurrentUserRole() async {
    try {
      // First check if employee session exists and is admin
      await _employeeSession.initialize();
      if (_employeeSession.isAdmin) {
        debugPrint('[AuthService] Role resolved: admin (from employee session)');
        return UserRole.admin;
      }

      // If employee exists, check role
      final employee = _employeeSession.currentEmployee;
      if (employee != null) {
        // Map employee role to UserRole
        final roleStr = employee.role.toLowerCase();
        if (roleStr.contains('manager') || roleStr.contains('gestionnaire')) {
          debugPrint('[AuthService] Role resolved: manager (from employee role)');
          return UserRole.manager;
        }
        debugPrint('[AuthService] Role resolved: employee (from employee session)');
        return UserRole.employee;
      }

      // Check user_accounts table if available
      final userId = currentUserId;
      if (userId != null) {
        try {
          final response = await _client
              .from('user_accounts')
              .select('role')
              .eq('id', userId)
              .maybeSingle();

          if (response != null) {
            final role = UserRole.fromString(response['role'] as String?);
            if (role != null) {
              debugPrint('[AuthService] Role resolved: ${role.toValue()} (from user_accounts)');
              return role;
            }
          }
        } catch (e) {
          debugPrint('[AuthService] Could not fetch role from user_accounts: $e');
        }
      }

      // Default to employee
      debugPrint('[AuthService] Role resolved: employee (default)');
      return UserRole.employee;
    } catch (e) {
      debugPrint('[AuthService] Error resolving role: $e');
      return UserRole.employee; // Default fallback
    }
  }

  /// Get current user role synchronously (cached)
  /// Note: This should be used with a Riverpod provider for reactive updates
  UserRole? _cachedRole;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  Future<UserRole> getCurrentUserRoleCached() async {
    if (_cachedRole != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedRole!;
    }

    _cachedRole = await getCurrentUserRole();
    _cacheTimestamp = DateTime.now();
    return _cachedRole!;
  }

  /// Clear cached role
  void clearRoleCache() {
    _cachedRole = null;
    _cacheTimestamp = null;
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _employeeSession.clear();
      clearRoleCache();
      await _client.auth.signOut();
      debugPrint('[AuthService] ✅ Logged out successfully');
    } catch (e) {
      debugPrint('[AuthService] ❌ Error logging out: $e');
      throw Exception('Échec de la déconnexion: $e');
    }
  }
}

