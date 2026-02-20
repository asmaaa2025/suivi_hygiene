import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/employee_repository.dart';
import '../../../../data/repositories/clock_repository.dart';
import '../../../../data/models/employee.dart';
import '../../../../services/employee_session_service.dart';
import '../../../../services/auth_service.dart';
import 'admin_code_page.dart';

/// Page to select which employee is using the app
class EmployeeSelectionPage extends StatefulWidget {
  const EmployeeSelectionPage({super.key});

  @override
  State<EmployeeSelectionPage> createState() => _EmployeeSelectionPageState();
}

class _EmployeeSelectionPageState extends State<EmployeeSelectionPage> {
  final _employeeRepo = EmployeeRepository();
  final _clockRepo = ClockRepository();
  final _sessionService = EmployeeSessionService();
  final _authService = AuthService();
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload employees when returning to this page (e.g., after creating an employee)
    // Use microtask to avoid reloading during build
    Future.microtask(() {
      if (mounted) {
        _loadEmployees();
      }
    });
  }

  Future<bool> _isAdmin() async {
    try {
      final authService = AuthService();
      final userRole = await authService.getCurrentUserRole();
      return userRole.isAdmin;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employees = await _employeeRepo.getAll(activeOnly: true);
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectEmployee(Employee employee) async {
    // Create a mutable variable for the employee (in case we need to replace it with DB version)
    Employee selectedEmployee = employee;

    // Validate employee ID is correct (not organization_id)
    debugPrint(
      '[EmployeeSelection] Selecting employee: ${selectedEmployee.fullName}',
    );
    debugPrint('[EmployeeSelection] Employee ID: ${selectedEmployee.id}');
    debugPrint(
      '[EmployeeSelection] Organization ID: ${selectedEmployee.organizationId}',
    );

    if (selectedEmployee.id.isEmpty) {
      debugPrint('[EmployeeSelection] ❌ Employee ID is empty!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erreur: L\'ID de l\'employé est vide. Veuillez réessayer.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (selectedEmployee.id == selectedEmployee.organizationId) {
      debugPrint(
        '[EmployeeSelection] ❌ ERROR: Employee ID matches Organization ID!',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erreur: L\'ID de l\'employé est incorrect. Veuillez réessayer.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // ALWAYS re-fetch employee from DB to ensure we have the correct ID
    // This prevents issues with cached employees that might have incorrect IDs
    try {
      debugPrint(
        '[EmployeeSelection] 🔍 Re-fetching employee from DB to ensure correct ID...',
      );

      Employee? dbEmployee;

      // If ID matches organization_id, we know it's wrong - search by name instead
      if (selectedEmployee.id == selectedEmployee.organizationId) {
        debugPrint(
          '[EmployeeSelection] ⚠️ ID matches organization_id - searching by name instead...',
        );
        final allEmployees = await _employeeRepo.getAll(activeOnly: true);
        try {
          dbEmployee = allEmployees.firstWhere(
            (emp) =>
                emp.firstName.toLowerCase() ==
                    selectedEmployee.firstName.toLowerCase() &&
                emp.lastName.toLowerCase() ==
                    selectedEmployee.lastName.toLowerCase(),
          );
          debugPrint(
            '[EmployeeSelection] ✅ Found employee by name: ${dbEmployee.fullName} (ID: ${dbEmployee.id})',
          );
        } catch (e) {
          debugPrint(
            '[EmployeeSelection] ❌ Could not find employee by name: $e',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erreur: L\'employé "${selectedEmployee.fullName}" n\'a pas pu être trouvé dans la base de données.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      } else {
        // Try to get by ID first
        dbEmployee = await _employeeRepo.getById(
          selectedEmployee.id,
          checkCreatedBy: false,
        );

        // If not found by ID, try to find by name and organization
        if (dbEmployee == null) {
          debugPrint(
            '[EmployeeSelection] ⚠️ Employee not found by ID, searching by name and organization...',
          );
          final allEmployees = await _employeeRepo.getAll(activeOnly: true);
          try {
            dbEmployee = allEmployees.firstWhere(
              (emp) =>
                  emp.firstName.toLowerCase() ==
                      selectedEmployee.firstName.toLowerCase() &&
                  emp.lastName.toLowerCase() ==
                      selectedEmployee.lastName.toLowerCase(),
            );
            debugPrint(
              '[EmployeeSelection] ✅ Found employee by name: ${dbEmployee.fullName} (ID: ${dbEmployee.id})',
            );
          } catch (e) {
            debugPrint(
              '[EmployeeSelection] ❌ Could not find employee by name: $e',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Erreur: L\'employé "${selectedEmployee.fullName}" n\'a pas pu être trouvé dans la base de données.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }

      // Verify the employee ID exists in DB
      final employeeExists = await _employeeRepo.employeeExists(dbEmployee.id);
      if (!employeeExists) {
        debugPrint(
          '[EmployeeSelection] ❌ Employee ID ${dbEmployee.id} does not exist in employees table!',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: L\'employé "${dbEmployee.fullName}" n\'existe pas dans la base de données. Veuillez le recréer.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Use the employee from DB (always has correct ID)
      if (dbEmployee.id != selectedEmployee.id) {
        debugPrint(
          '[EmployeeSelection] ✅ Found employee in DB with different ID. Old: ${selectedEmployee.id}, New: ${dbEmployee.id}',
        );
      } else {
        debugPrint(
          '[EmployeeSelection] ✅ Employee ID ${dbEmployee.id} verified in database',
        );
      }
      selectedEmployee = dbEmployee;
    } catch (e) {
      debugPrint('[EmployeeSelection] ❌ Error verifying employee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la vérification de l\'employé: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // If employee is admin, ask for code
    if (selectedEmployee.isAdmin) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AdminCodePageWithEmployee(employee: selectedEmployee),
        ),
      );

      if (result == true && mounted) {
        // Code verified, set employee and check clock status
        await _sessionService.setEmployee(selectedEmployee);
        debugPrint(
          '[EmployeeSelection] ✅ Employee set: ${selectedEmployee.fullName} (ID: ${selectedEmployee.id})',
        );
        await _checkClockAndNavigate();
      }
    } else {
      // Regular employee, set and check clock status
      await _sessionService.setEmployee(selectedEmployee);
      debugPrint(
        '[EmployeeSelection] ✅ Employee set: ${selectedEmployee.fullName} (ID: ${selectedEmployee.id})',
      );
      await _checkClockAndNavigate();
    }
  }

  /// Check if the selected employee has an open clock session (from DB - persisted)
  /// If not, prompt to clock in
  Future<void> _checkClockAndNavigate() async {
    if (!mounted) return;

    try {
      final currentEmployee = _sessionService.currentEmployee;
      if (currentEmployee == null) {
        debugPrint('[EmployeeSelection] No employee selected');
        return;
      }

      // Use employee ID directly (for shared tablet scenario where multiple employees use same Supabase account)
      final employeeId = currentEmployee.id;

      // Check if THIS employee has an open session in DB (persisted - survives app restarts)
      final openSession = await _clockRepo.getOpenSession(employeeId);

      if (openSession == null && mounted) {
        // No open session for this employee, ask if user wants to clock in
        final shouldClockIn = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Pointage d\'entrée'),
            content: const Text(
              'Vous n\'avez pas de session de pointage ouverte. Voulez-vous pointer maintenant ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Pointer maintenant'),
              ),
            ],
          ),
        );

        if (shouldClockIn == true && mounted) {
          // Navigate to clock page
          final userRole = await _authService.getCurrentUserRole();
          if (userRole.isAdmin) {
            context.go('/admin/clock');
          } else {
            context.go('/app/clock');
          }
          return;
        }
      } else if (openSession != null) {
        // Employee has an open session - show info and navigate
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vous avez une session de pointage ouverte. Vous pouvez pointer la sortie depuis la page Pointage.',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[EmployeeSelection] Error checking clock: $e');
    }

    // Navigate to home
    if (mounted) {
      final userRole = await _authService.getCurrentUserRole();
      if (userRole.isAdmin) {
        context.go('/admin/home');
      } else {
        context.go('/app/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qui es-tu ?'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          // Only show "Create employee" button for admins
          FutureBuilder<bool>(
            future: _isAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Créer un employé',
                  onPressed: () => context.push('/admin/employees/new'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 80, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    'Qui es-tu ?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez votre nom',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(height: 8),
                            Text('Erreur: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadEmployees,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_employees.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun employé trouvé',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Créez votre premier employé pour commencer',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  context.push('/admin/employees/new'),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Créer un premier employé'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._employees.map((employee) {
                      final isAdmin = employee.isAdmin;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAdmin
                                ? Colors.purple.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: isAdmin
                                  ? Colors.purple.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                          title: Text(
                            employee.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${employee.role}${isAdmin ? ' • Admin' : ''}',
                            style: TextStyle(
                              color: isAdmin
                                  ? Colors.purple.shade700
                                  : Colors.grey.shade600,
                              fontWeight: isAdmin
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _selectEmployee(employee),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
