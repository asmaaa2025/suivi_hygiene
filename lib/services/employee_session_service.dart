import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/employee.dart';
import 'dart:convert';

/// Service to manage the current employee session
class EmployeeSessionService {
  static final EmployeeSessionService _instance = EmployeeSessionService._internal();
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
        debugPrint('[EmployeeSession] Loaded employee: ${_currentEmployee?.fullName}');
      }
    } catch (e) {
      debugPrint('[EmployeeSession] Error loading employee: $e');
      _currentEmployee = null;
    }
  }

  /// Set the current employee
  Future<void> setEmployee(Employee employee) async {
    try {
      _currentEmployee = employee;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(employee.toJson()));
      debugPrint('[EmployeeSession] Set employee: ${employee.fullName}');
    } catch (e) {
      debugPrint('[EmployeeSession] Error saving employee: $e');
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

