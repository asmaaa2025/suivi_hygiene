import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/employee.dart';
import 'dart:convert';

/// Service to manage the current employee session
class EmployeeSessionService {
  static final EmployeeSessionService _instance =
      EmployeeSessionService._internal();
  factory EmployeeSessionService() => _instance;
  EmployeeSessionService._internal();

  Employee? _currentEmployee;
  static const String _prefsKey = 'current_employee';

  /// Get the current employee
  Employee? get currentEmployee => _currentEmployee;

  /// Check if an employee is currently selected
  bool get hasEmployee => _currentEmployee != null;

  /// Check if current employee is admin
  bool get isAdmin => _currentEmployee?.isAdmin ?? false;

  /// Initialize and load employee from preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeJson = prefs.getString(_prefsKey);
      if (employeeJson != null) {
        final map = jsonDecode(employeeJson) as Map<String, dynamic>;
        _currentEmployee = Employee.fromJson(map);

        // Validate that employee ID is correct (not organization_id)
        if (_currentEmployee != null) {
          debugPrint(
            '[EmployeeSession] Loaded employee: ${_currentEmployee!.fullName}',
          );
          debugPrint('[EmployeeSession] Employee ID: ${_currentEmployee!.id}');
          debugPrint(
            '[EmployeeSession] Organization ID: ${_currentEmployee!.organizationId}',
          );

          // Safety check: if ID matches organization_id, clear it (invalid data)
          if (_currentEmployee!.id == _currentEmployee!.organizationId ||
              _currentEmployee!.id.isEmpty) {
            debugPrint(
              '[EmployeeSession] ❌ Invalid employee data detected (ID matches org ID or is empty). Clearing session.',
            );
            _currentEmployee = null;
            await clear();
          }
        }
      }
    } catch (e) {
      debugPrint('[EmployeeSession] Error loading employee: $e');
      _currentEmployee = null;
    }
  }

  /// Set the current employee
  Future<void> setEmployee(Employee employee) async {
    try {
      // Validate employee ID before storing
      if (employee.id.isEmpty) {
        debugPrint(
          '[EmployeeSession] ❌ ERROR: Cannot set employee with empty ID!',
        );
        throw Exception('L\'ID de l\'employé est vide. Veuillez réessayer.');
      }

      if (employee.id == employee.organizationId) {
        debugPrint(
          '[EmployeeSession] ❌ ERROR: Employee ID matches Organization ID!',
        );
        throw Exception(
          'L\'ID de l\'employé est identique à l\'ID de l\'organisation. Données invalides.',
        );
      }

      _currentEmployee = employee;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(employee.toJson()));
      debugPrint('[EmployeeSession] ✅ Set employee: ${employee.fullName}');
      debugPrint('[EmployeeSession]   - ID: ${employee.id}');
      debugPrint('[EmployeeSession]   - Org ID: ${employee.organizationId}');
      debugPrint('[EmployeeSession]   - Is Admin: ${employee.isAdmin}');
    } catch (e) {
      debugPrint('[EmployeeSession] ❌ Error saving employee: $e');
      rethrow;
    }
  }

  /// Clear the current employee session
  Future<void> clear() async {
    try {
      _currentEmployee = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('[EmployeeSession] Cleared employee session');
    } catch (e) {
      debugPrint('[EmployeeSession] Error clearing employee: $e');
    }
  }
}
