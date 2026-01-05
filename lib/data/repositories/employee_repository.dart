import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee.dart';
import 'organization_repository.dart';

/// Repository for employees
class EmployeeRepository {
  final SupabaseClient _client = Supabase.instance.client;
  
  // Expose client for organization access
  SupabaseClient get client => _client;

  /// Get all employees for the current user's organization
  Future<List<Employee>> getAll({bool? activeOnly}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[EmployeeRepo] No authenticated user');
        return [];
      }

      // Get organization ID
      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      debugPrint('[EmployeeRepo] Fetching employees, org: $orgId');
      var query = _client
          .from('employees')
          .select()
          .eq('organization_id', orgId); // Get employees from the organization
      
      if (activeOnly == true) {
        query = query.eq('is_active', true);
      }
      
      final response = await query.order('last_name');
      
      final employees = (response as List)
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[EmployeeRepo] ✅ Fetched ${employees.length} employees');
      return employees;
    } catch (e) {
      debugPrint('[EmployeeRepo] ❌ Error: $e');
      throw Exception('Failed to fetch employees: $e');
    }
  }

  /// Get employee by ID
  Future<Employee?> getById(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('employees')
          .select()
          .eq('id', id)
          .eq('created_by', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[EmployeeRepo] ❌ Error: $e');
      return null;
    }
  }

  /// Create a new employee
  /// If organizationId is not provided, gets or creates one automatically
  Future<Employee> create({
    String? organizationId,
    required String firstName,
    required String lastName,
    required String role,
    bool isAdmin = false,
    String? adminCode,
    String? adminEmail,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get or create organization if not provided
      String finalOrgId = organizationId ?? '';
      if (finalOrgId.isEmpty) {
        final orgRepo = OrganizationRepository();
        finalOrgId = await orgRepo.getOrCreateOrganization();
      }

      final insertData = <String, dynamic>{
        'organization_id': finalOrgId,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'is_active': true,
        'is_admin': isAdmin,
        'created_by': user.id,
      };
      
      // If admin, admin_code and admin_email are REQUIRED by database constraint
      if (isAdmin) {
        final trimmedCode = adminCode?.trim();
        final trimmedEmail = adminEmail?.trim();
        
        if (trimmedCode == null || trimmedCode.isEmpty) {
          throw Exception('Le code administrateur est requis pour créer un admin');
        }
        if (trimmedEmail == null || trimmedEmail.isEmpty) {
          throw Exception('L\'email administrateur est requis pour créer un admin');
        }
        
        insertData['admin_code'] = trimmedCode;
        insertData['admin_email'] = trimmedEmail;
      }
      // If not admin, don't include admin_code and admin_email fields at all
      // (they will default to NULL in the database)

      debugPrint('[EmployeeRepo] Creating employee with data: $insertData');
      final response = await _client
        .from('employees')
        .insert(insertData)
        .select()
        .single();
      
      return Employee.fromJson(response);
    } catch (e) {
      debugPrint('[EmployeeRepo] ❌ Error creating employee: $e');
      throw Exception('Failed to create employee: $e');
    }
  }

  /// Update an employee
  Future<Employee> update({
    required String id,
    String? firstName,
    String? lastName,
    String? role,
    bool? isActive,
    bool? isAdmin,
    String? adminCode,
    String? adminEmail,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (role != null) updates['role'] = role;
      if (isActive != null) updates['is_active'] = isActive;
      
      // Handle admin fields based on isAdmin value
      if (isAdmin != null) {
        updates['is_admin'] = isAdmin;
        if (isAdmin) {
          // If setting to admin, admin_code and admin_email are REQUIRED
          if (adminCode == null || adminCode.isEmpty) {
            throw Exception('Le code administrateur est requis pour un admin');
          }
          if (adminEmail == null || adminEmail.isEmpty) {
            throw Exception('L\'email administrateur est requis pour un admin');
          }
          updates['admin_code'] = adminCode;
          updates['admin_email'] = adminEmail;
        } else {
          // If removing admin status, set to NULL
          updates['admin_code'] = null;
          updates['admin_email'] = null;
        }
      } else {
        // If isAdmin is not being changed, only update admin fields if provided
        if (adminCode != null) updates['admin_code'] = adminCode;
        if (adminEmail != null) updates['admin_email'] = adminEmail;
      }

      final response = await _client
          .from('employees')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      debugPrint('[EmployeeRepo] ❌ Error updating employee: $e');
      throw Exception('Failed to update employee: $e');
    }
  }

  /// Delete an employee
  Future<void> delete(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
    } catch (e) {
      debugPrint('[EmployeeRepo] ❌ Error deleting employee: $e');
      throw Exception('Failed to delete employee: $e');
    }
  }
}

