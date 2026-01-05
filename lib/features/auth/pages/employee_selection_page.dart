import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/employee_repository.dart';
import '../../../../data/models/employee.dart';
import '../../../../services/employee_session_service.dart';
import 'admin_code_page.dart';

/// Page to select which employee is using the app
class EmployeeSelectionPage extends StatefulWidget {
  const EmployeeSelectionPage({super.key});

  @override
  State<EmployeeSelectionPage> createState() => _EmployeeSelectionPageState();
}

class _EmployeeSelectionPageState extends State<EmployeeSelectionPage> {
  final _employeeRepo = EmployeeRepository();
  final _sessionService = EmployeeSessionService();
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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
    // If employee is admin, ask for code
    if (employee.isAdmin) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AdminCodePageWithEmployee(employee: employee),
        ),
      );
      
      if (result == true && mounted) {
        // Code verified, set employee and go to home
        await _sessionService.setEmployee(employee);
        if (mounted) {
          context.go('/home');
        }
      }
    } else {
      // Regular employee, set and go to home
      await _sessionService.setEmployee(employee);
      if (mounted) {
        context.go('/home');
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
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Créer un employé',
            onPressed: () => context.push('/employees/new'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Colors.white,
                  ),
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
                            Icon(Icons.people_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun employé trouvé',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Créez votre premier employé pour commencer',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/employees/new'),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Créer un employé'),
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
                            backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isAdmin ? Icons.admin_panel_settings : Icons.person,
                              color: isAdmin ? Colors.purple.shade700 : Colors.blue.shade700,
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
                              color: isAdmin ? Colors.purple.shade700 : Colors.grey.shade600,
                              fontWeight: isAdmin ? FontWeight.w500 : FontWeight.normal,
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

