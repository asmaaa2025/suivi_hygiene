import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clock_session.dart';
import '../../../data/models/employee.dart';
import '../../../data/repositories/clock_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

/// Admin clock history page - View clock sessions with filters
class AdminClockHistoryPage extends StatefulWidget {
  const AdminClockHistoryPage({super.key});

  @override
  State<AdminClockHistoryPage> createState() => _AdminClockHistoryPageState();
}

class _AdminClockHistoryPageState extends State<AdminClockHistoryPage> {
  final ClockRepository _clockRepo = ClockRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  List<ClockSession> _sessions = [];
  List<Employee> _employees = [];
  Map<String, Employee> _employeeMap = {};
  bool _isLoading = true;
  String? _error;

  String? _selectedEmployeeId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _openSessionsOnly = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadData();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _employeeRepo.getAll(activeOnly: false);
      setState(() {
        _employees = employees;
        _employeeMap = {for (var emp in employees) emp.id: emp};
      });
    } catch (e) {
      debugPrint('[AdminClockHistory] Error loading employees: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<String>? employeeIds;
      if (_selectedEmployeeId != null) {
        employeeIds = [_selectedEmployeeId!];
      } else {
        // Get all employee IDs from employees list
        employeeIds = _employees.map((emp) => emp.id).toList();
      }

      final sessions = await _clockRepo.getHistoryForEmployees(
        employeeIds: employeeIds.isNotEmpty ? employeeIds : [],
        startDate: _startDate,
        endDate: _endDate,
        openSessionsOnly: _openSessionsOnly,
      );

      if (mounted) {
        setState(() {
          _sessions = sessions;
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

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: firstDayOfMonth, end: lastDayOfMonth),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique de Pointage')),
      body: Column(
        children: [
          // Filters
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Employee filter
                  DropdownButtonFormField<String>(
                    value: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employé',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tous'),
                      ),
                      ..._employees.map(
                        (emp) => DropdownMenuItem<String>(
                          value: emp.id,
                          child: Text(emp.fullName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedEmployeeId = value);
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Date range
                  InkWell(
                    onTap: _selectDateRange,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Période',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                            : 'Toutes les dates',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Open sessions only
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sessions ouvertes uniquement',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Switch(
                        value: _openSessionsOnly,
                        onChanged: (value) {
                          setState(() => _openSessionsOnly = value);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorState(message: _error!, onRetry: _loadData)
                : _sessions.isEmpty
                ? const EmptyState(
                    title: 'Aucune session',
                    message: 'Aucune session de pointage trouvée',
                    icon: Icons.access_time,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final employee = _employeeMap[session.employeeId];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: session.isOpen
                                  ? Colors.orange
                                  : Colors.green,
                              child: Icon(
                                session.isOpen
                                    ? Icons.access_time
                                    : Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              employee?.fullName ??
                                  'Employé ${session.employeeId.substring(0, 8)}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Entrée: ${DateFormat('dd/MM/yyyy HH:mm').format(session.startAt)}',
                                ),
                                if (session.endAt != null)
                                  Text(
                                    'Sortie: ${DateFormat('dd/MM/yyyy HH:mm').format(session.endAt!)}',
                                  ),
                                Text(
                                  session.isOpen
                                      ? 'En cours'
                                      : 'Durée: ${session.durationFormatted}',
                                  style: TextStyle(
                                    color: session.isOpen
                                        ? Colors.orange
                                        : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
