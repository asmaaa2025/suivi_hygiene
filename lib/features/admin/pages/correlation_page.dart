import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clock_session.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/haccp_action.dart';
import '../../../data/repositories/clock_repository.dart';
import '../../../data/repositories/haccp_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

/// Correlation page - Correlate clock sessions with HACCP actions
class CorrelationPage extends StatefulWidget {
  const CorrelationPage({super.key});

  @override
  State<CorrelationPage> createState() => _CorrelationPageState();
}

class _CorrelationPageState extends State<CorrelationPage> {
  final ClockRepository _clockRepo = ClockRepository();
  final HaccpRepository _haccpRepo = HaccpRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  List<Employee> _employees = [];
  Map<String, Employee> _employeeMap = {};
  String? _selectedEmployeeId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showAnomaliesOnly = false;

  List<ClockSession> _sessions = [];
  List<HaccpAction> _actions = [];
  Map<String, List<HaccpAction>> _actionsBySession = {};
  List<HaccpAction> _anomalies = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _employeeRepo.getAll(activeOnly: false);
      setState(() {
        _employees = employees;
        _employeeMap = {for (var emp in employees) emp.id: emp};
      });
    } catch (e) {
      debugPrint('[Correlation] Error loading employees: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    if (_selectedEmployeeId == null) {
      setState(() {
        _sessions = [];
        _actions = [];
        _actionsBySession = {};
        _anomalies = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load sessions
      final sessions = await _clockRepo.getHistoryForEmployees(
        employeeIds: [_selectedEmployeeId!],
        startDate: _startDate,
        endDate: _endDate,
      );

      // Load actions - Note: HACCP actions might still use userId (auth.users)
      // For now, we'll load all actions and filter by time range
      // TODO: Update HACCP actions to use employee_id if needed
      final actions = await _haccpRepo.getActionsForUsers(
        userIds: [
          _selectedEmployeeId!,
        ], // This might need to be updated if HACCP uses employee_id
        startDate: _startDate,
        endDate: _endDate,
      );

      // Correlate actions with sessions
      final actionsBySession = <String, List<HaccpAction>>{};
      final anomalies = <HaccpAction>[];

      for (final action in actions) {
        // Find session that contains this action
        ClockSession? containingSession;
        for (final session in sessions) {
          if (action.occurredAt.isAfter(session.startAt) &&
              (session.endAt == null ||
                  action.occurredAt.isBefore(session.endAt!))) {
            containingSession = session;
            break;
          }
        }

        if (containingSession != null) {
          actionsBySession
              .putIfAbsent(containingSession.id, () => [])
              .add(action);
        } else {
          // Action outside any session = anomaly
          anomalies.add(action);
        }
      }

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _actions = actions;
          _actionsBySession = actionsBySession;
          _anomalies = anomalies;
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
    final displaySessions = _showAnomaliesOnly
        ? _sessions
              .where(
                (s) => _anomalies.any(
                  (a) =>
                      a.occurredAt.isAfter(s.startAt) &&
                      (s.endAt == null || a.occurredAt.isBefore(s.endAt!)),
                ),
              )
              .toList()
        : _sessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Corrélation Pointage / HACCP')),
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
                      labelText: 'Employé *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Sélectionner un employé'),
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
                  // Anomalies only
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Anomalies uniquement',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Switch(
                        value: _showAnomaliesOnly,
                        onChanged: (value) {
                          setState(() => _showAnomaliesOnly = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Stats
          if (!_isLoading && _selectedEmployeeId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              '${_sessions.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Sessions'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              '${_actions.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Actions HACCP'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              '${_anomalies.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Text('Anomalies'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorState(message: _error!, onRetry: _loadData)
                : _selectedEmployeeId == null
                ? const EmptyState(
                    title: 'Sélectionner un employé',
                    message:
                        'Veuillez sélectionner un employé pour voir les corrélations',
                    icon: Icons.person_search,
                  )
                : displaySessions.isEmpty
                ? const EmptyState(
                    title: 'Aucune session',
                    message: 'Aucune session trouvée pour cette période',
                    icon: Icons.timeline,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: displaySessions.length,
                      itemBuilder: (context, index) {
                        final session = displaySessions[index];
                        final sessionActions =
                            _actionsBySession[session.id] ?? [];
                        final employee = _employeeMap[session.employeeId];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
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
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(session.startAt)} - ${session.endAt != null ? DateFormat('HH:mm').format(session.endAt!) : 'En cours'}',
                                ),
                                Text(
                                  '${sessionActions.length} action(s) HACCP',
                                  style: TextStyle(
                                    color: sessionActions.isEmpty
                                        ? Colors.grey
                                        : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              if (sessionActions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Aucune action HACCP pendant cette session',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                ...sessionActions.map((action) {
                                  return ListTile(
                                    leading: Icon(
                                      _getActionIcon(action.type),
                                      color: _getActionColor(action.type),
                                    ),
                                    title: Text(action.type.displayName),
                                    subtitle: Text(
                                      DateFormat(
                                        'dd/MM/yyyy HH:mm',
                                      ).format(action.occurredAt),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // Anomalies section
          if (_anomalies.isNotEmpty && !_showAnomaliesOnly)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Anomalies (${_anomalies.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._anomalies.take(3).map((action) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${action.type.displayName} le ${DateFormat('dd/MM/yyyy HH:mm').format(action.occurredAt)} (hors session)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                  if (_anomalies.length > 3)
                    Text(
                      '... et ${_anomalies.length - 3} autre(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getActionIcon(HaccpActionType type) {
    switch (type) {
      case HaccpActionType.temperature:
        return Icons.thermostat;
      case HaccpActionType.reception:
        return Icons.inventory;
      case HaccpActionType.cleaning:
        return Icons.cleaning_services;
      case HaccpActionType.correctiveAction:
        return Icons.build;
      case HaccpActionType.docUpload:
        return Icons.description;
      case HaccpActionType.oilChange:
        return Icons.oil_barrel;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(HaccpActionType type) {
    switch (type) {
      case HaccpActionType.temperature:
        return Colors.blue;
      case HaccpActionType.reception:
        return Colors.green;
      case HaccpActionType.cleaning:
        return Colors.purple;
      case HaccpActionType.correctiveAction:
        return Colors.orange;
      case HaccpActionType.docUpload:
        return Colors.teal;
      case HaccpActionType.oilChange:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
