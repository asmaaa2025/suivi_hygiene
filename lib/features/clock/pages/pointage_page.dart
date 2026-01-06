import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clock_session.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/clock_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../services/employee_session_service.dart';

/// Pointage page - Clock in/out for employees
/// Each employee has their own clock sessions (multi-employés)
/// State is persisted in DB, survives app restarts
class PointagePage extends StatefulWidget {
  const PointagePage({super.key});

  @override
  State<PointagePage> createState() => _PointagePageState();
}

class _PointagePageState extends State<PointagePage> {
  final ClockRepository _clockRepo = ClockRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final EmployeeSessionService _employeeSessionService = EmployeeSessionService();
  ClockSession? _currentSession;
  String? _currentEmployeeName;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
  }

  /// Load the open session for the current employee (from DB - persisted)
  Future<void> _loadCurrentSession() async {
    setState(() => _isLoading = true);
    try {
      var currentEmployee = _employeeSessionService.currentEmployee;
      if (currentEmployee == null) {
        throw Exception('Aucun employé sélectionné');
      }

      debugPrint('[PointagePage] Current employee from session: ${currentEmployee.fullName}');
      debugPrint('[PointagePage] Employee ID from session: ${currentEmployee.id}');
      debugPrint('[PointagePage] Organization ID: ${currentEmployee.organizationId}');
      
      // ALWAYS re-fetch employee from DB to ensure we have the correct ID
      // This prevents using cached employees with incorrect IDs (organization_id instead of employee.id)
      Employee dbEmployee;
      
      // Store employee name for search (currentEmployee is guaranteed non-null here)
      final employeeFirstName = currentEmployee.firstName;
      final employeeLastName = currentEmployee.lastName;
      final employeeFullName = currentEmployee.fullName;
      
      // If ID matches organization_id or is empty, we know it's wrong - search by name instead
      if (currentEmployee.id == currentEmployee.organizationId || currentEmployee.id.isEmpty) {
        debugPrint('[PointagePage] ⚠️ ID matches organization_id or is empty - searching by name...');
        final allEmployees = await _employeeRepo.getAll(activeOnly: true);
        try {
          dbEmployee = allEmployees.firstWhere(
            (emp) => emp.firstName.toLowerCase() == employeeFirstName.toLowerCase() 
                  && emp.lastName.toLowerCase() == employeeLastName.toLowerCase(),
          );
          debugPrint('[PointagePage] ✅ Found employee by name: ${dbEmployee.fullName} (ID: ${dbEmployee.id})');
        } catch (e) {
          debugPrint('[PointagePage] ❌ Could not find employee by name: $e');
          throw Exception('L\'employé "$employeeFullName" n\'a pas pu être trouvé dans la base de données. Veuillez re-sélectionner l\'employé.');
        }
      } else {
        // Try to get by ID first
        final dbEmployeeNullable = await _employeeRepo.getById(currentEmployee.id, checkCreatedBy: false);
        
        // If not found by ID, try to find by name
        if (dbEmployeeNullable == null) {
          debugPrint('[PointagePage] ⚠️ Employee not found by ID, searching by name...');
          final allEmployees = await _employeeRepo.getAll(activeOnly: true);
          try {
            dbEmployee = allEmployees.firstWhere(
              (emp) => emp.firstName.toLowerCase() == employeeFirstName.toLowerCase() 
                    && emp.lastName.toLowerCase() == employeeLastName.toLowerCase(),
            );
            debugPrint('[PointagePage] ✅ Found employee by name: ${dbEmployee.fullName} (ID: ${dbEmployee.id})');
          } catch (e) {
            debugPrint('[PointagePage] ❌ Could not find employee by name: $e');
            throw Exception('L\'employé "$employeeFullName" n\'a pas pu être trouvé dans la base de données. Veuillez re-sélectionner l\'employé.');
          }
        } else {
          dbEmployee = dbEmployeeNullable;
        }
      }
      
      // Use the employee from DB (always has correct ID)
      currentEmployee = dbEmployee;
      final employeeId = currentEmployee.id;
      
      debugPrint('[PointagePage] ✅ Using employee from DB: ${currentEmployee.fullName} (ID: $employeeId)');
      
      // Validate that employee exists in DB
      final employeeExists = await _employeeRepo.employeeExists(employeeId);
      if (!employeeExists) {
        debugPrint('[PointagePage] ❌ Employee ID $employeeId does not exist in employees table');
        throw Exception('L\'employé sélectionné (${currentEmployee.fullName}) n\'existe pas dans la base de données. Veuillez re-sélectionner l\'employé depuis la page "Qui es-tu ?".');
      }

      // Auto-close old sessions (>24h) for THIS employee only
      // CRITICAL: Only affects the current employee, never all employees
      await _clockRepo.autoCloseOldSession(employeeId);
      
      // Get open session for THIS employee (from DB - single source of truth)
      final session = await _clockRepo.getOpenSession(employeeId);
      
      // Get current employee name for display (don't filter by created_by for clock-in)
      String? employeeName;
      try {
        final employee = await _employeeRepo.getById(currentEmployee.id, checkCreatedBy: false);
        employeeName = employee?.fullName ?? currentEmployee.fullName;
      } catch (e) {
        debugPrint('[PointagePage] Error loading employee name: $e');
        employeeName = currentEmployee.fullName; // Fallback to cached name
      }
      
      setState(() {
        _currentSession = session;
        _currentEmployeeName = employeeName;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PointagePage] Error loading session: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  /// Clock in - create a new session for the current employee
  Future<void> _clockIn() async {
    if (_isProcessing) return;

    // Check if this employee already has an open session
    if (_currentSession != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez déjà une session de pointage ouverte. Veuillez d\'abord pointer la sortie.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    try {
      var currentEmployee = _employeeSessionService.currentEmployee;
      if (currentEmployee == null) {
        throw Exception('Aucun employé sélectionné');
      }

      debugPrint('[PointagePage] Clock-in attempt for employee: ${currentEmployee.fullName}');
      debugPrint('[PointagePage] Employee ID from session: ${currentEmployee.id}');
      debugPrint('[PointagePage] Organization ID: ${currentEmployee.organizationId}');
      
      // ALWAYS re-fetch employee from DB to ensure we have the correct ID
      // This prevents using cached employees with incorrect IDs (organization_id instead of employee.id)
      Employee dbEmployee;
      
      // Store employee name for search (currentEmployee is guaranteed non-null here)
      final employeeFirstName = currentEmployee.firstName;
      final employeeLastName = currentEmployee.lastName;
      final employeeFullName = currentEmployee.fullName;
      
      // If ID matches organization_id or is empty, we know it's wrong - search by name instead
      if (currentEmployee.id == currentEmployee.organizationId || currentEmployee.id.isEmpty) {
        debugPrint('[PointagePage] ⚠️ ID matches organization_id or is empty - searching by name...');
        final allEmployees = await _employeeRepo.getAll(activeOnly: true);
        try {
          dbEmployee = allEmployees.firstWhere(
            (emp) => emp.firstName.toLowerCase() == employeeFirstName.toLowerCase() 
                  && emp.lastName.toLowerCase() == employeeLastName.toLowerCase(),
          );
          debugPrint('[PointagePage] ✅ Found employee by name: ${dbEmployee.fullName} (ID: ${dbEmployee.id})');
        } catch (e) {
          debugPrint('[PointagePage] ❌ Could not find employee by name: $e');
          throw Exception('L\'employé "$employeeFullName" n\'a pas pu être trouvé dans la base de données. Veuillez re-sélectionner l\'employé.');
        }
      } else {
        // Try to get by ID first
        final dbEmployeeNullable = await _employeeRepo.getById(currentEmployee.id, checkCreatedBy: false);
        
        // If not found by ID, try to find by name
        if (dbEmployeeNullable == null) {
          debugPrint('[PointagePage] ⚠️ Employee not found by ID, searching by name...');
          final allEmployees = await _employeeRepo.getAll(activeOnly: true);
          try {
            dbEmployee = allEmployees.firstWhere(
              (emp) => emp.firstName.toLowerCase() == employeeFirstName.toLowerCase() 
                    && emp.lastName.toLowerCase() == employeeLastName.toLowerCase(),
            );
            debugPrint('[PointagePage] ✅ Found employee by name: ${dbEmployee.fullName} (ID: ${dbEmployee.id})');
          } catch (e) {
            debugPrint('[PointagePage] ❌ Could not find employee by name: $e');
            throw Exception('L\'employé "$employeeFullName" n\'a pas pu être trouvé dans la base de données. Veuillez re-sélectionner l\'employé.');
          }
        } else {
          dbEmployee = dbEmployeeNullable;
        }
      }
      
      // Use the employee from DB (always has correct ID)
      currentEmployee = dbEmployee;
      final employeeId = currentEmployee.id;
      
      debugPrint('[PointagePage] ✅ Using employee from DB: ${currentEmployee.fullName} (ID: $employeeId)');
      
      // Validate that employee exists in DB
      final employeeExists = await _employeeRepo.employeeExists(employeeId);
      if (!employeeExists) {
        debugPrint('[PointagePage] ❌ Employee ID $employeeId does not exist in employees table');
        throw Exception('L\'employé sélectionné (${currentEmployee.fullName}) n\'existe pas dans la base de données. Veuillez re-sélectionner l\'employé depuis la page "Qui es-tu ?".');
      }

      debugPrint('[PointagePage] ✅ Employee $employeeId exists, proceeding with clock-in');

      // Clock in for THIS employee (repository checks for existing session)
      await _clockRepo.clockIn(employeeId: employeeId);
      
      debugPrint('[PointagePage] ✅ Clocked in successfully for employee ${currentEmployee.id}');
      
      // Reload session from DB
      await _loadCurrentSession();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pointage d\'entrée enregistré'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PointagePage] ❌ Error clocking in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Clock out - close the current session for the current employee
  Future<void> _clockOut() async {
    if (_isProcessing) return;

    // Check if this employee has an open session
    if (_currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune session de pointage ouverte. Veuillez d\'abord pointer l\'entrée.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final currentEmployee = _employeeSessionService.currentEmployee;
      if (currentEmployee == null) {
        throw Exception('Aucun employé sélectionné');
      }

      // Use employee ID instead of Supabase auth user ID (for shared tablet scenario)
      final employeeId = currentEmployee.id;

      // Clock out for THIS employee (repository validates session belongs to user)
      // The returned session has endAt set, so we can calculate duration
      final closedSession = await _clockRepo.clockOut(employeeId);
      
      debugPrint('[PointagePage] ✅ Clocked out successfully for employee $employeeId');
      
      // Calculate duration from the closed session
      final duration = closedSession.durationFormatted;
      
      // Reload session from DB (will be null since session is now closed)
      await _loadCurrentSession();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pointage de sortie enregistré (Durée: $duration)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PointagePage] ❌ Error clocking out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pointage'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCurrentSession,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status card
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              _currentSession != null
                                  ? Icons.access_time
                                  : Icons.access_time_filled,
                              size: 64,
                              color: _currentSession != null
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentSession != null
                                  ? 'Session ouverte'
                                  : 'Aucune session ouverte',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (_currentSession != null) ...[
                              const SizedBox(height: 8),
                              if (_currentEmployeeName != null) ...[
                                Text(
                                  'Employé: $_currentEmployeeName',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                'Entrée: ${DateFormat('HH:mm').format(_currentSession!.startAt)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${DateFormat('dd/MM/yyyy').format(_currentSession!.startAt)}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Clocked in since ${DateFormat('HH:mm').format(_currentSession!.startAt)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Action button
                    ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : (_currentSession != null ? _clockOut : _clockIn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentSession != null
                            ? Colors.orange
                            : AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _currentSession != null
                                      ? Icons.logout
                                      : Icons.login,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _currentSession != null
                                      ? 'Pointer la sortie'
                                      : 'Pointer l\'entrée',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Info text
                    Text(
                      _currentSession != null
                          ? 'Vous êtes actuellement en session. Cliquez sur le bouton pour pointer la sortie.'
                          : 'Cliquez sur le bouton pour pointer votre entrée. Votre session sera persistée même si vous fermez l\'application.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

