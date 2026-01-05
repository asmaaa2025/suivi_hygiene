import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/audit_log_repository.dart';
import '../../../../data/repositories/employee_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../data/models/audit_log_entry.dart';
import '../../../../data/models/employee.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';

/// Central history page showing unified audit log
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _auditLogRepo = AuditLogRepository();
  final _employeeRepo = EmployeeRepository();
  
  List<AuditLogEntry> _entries = [];
  Map<String, Employee> _employees = {}; // Map of employeeId -> Employee
  bool _isLoading = true;
  String? _error;
  String? _selectedOperationType;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _operationTypes = [
    'all',
    'reception',
    'temperature',
    'oil_change',
    'cleaning',
    'non_conformity',
    'product',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOperationType = 'all';
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load employees for name resolution
      final employees = await _employeeRepo.getAll();
      final employeesMap = <String, Employee>{};
      for (final emp in employees) {
        employeesMap[emp.id] = emp;
      }

      // Load audit log
      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();
      
      final entries = await _auditLogRepo.getAll(
        organizationId: orgId,
        operationType: _selectedOperationType == 'all' 
            ? null 
            : _selectedOperationType,
        startDate: _startDate,
        endDate: _endDate,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _entries = entries;
          _employees = employeesMap;
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

  String _getOperationTypeLabel(String type) {
    switch (type) {
      case 'reception':
        return 'Réception';
      case 'temperature':
        return 'Température';
      case 'oil_change':
        return 'Changement d\'huile';
      case 'cleaning':
        return 'Nettoyage';
      case 'non_conformity':
        return 'Non-conformité';
      case 'product':
        return 'Produit';
      default:
        return type;
    }
  }

  IconData _getOperationTypeIcon(String type) {
    switch (type) {
      case 'reception':
        return Icons.inventory_2;
      case 'temperature':
        return Icons.thermostat;
      case 'oil_change':
        return Icons.oil_barrel;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'non_conformity':
        return Icons.warning;
      case 'product':
        return Icons.shopping_basket;
      default:
        return Icons.history;
    }
  }

  void _navigateToDetail(AuditLogEntry entry) {
    switch (entry.operationType) {
      case 'reception':
        // Navigate to reception detail if route exists
        break;
      case 'temperature':
        context.push('/temperatures');
        break;
      case 'oil_change':
        context.push('/oil-changes');
        break;
      case 'cleaning':
        context.push('/cleaning');
        break;
      case 'product':
        context.push('/products');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Operation type filter
                DropdownButtonFormField<String>(
                  value: _selectedOperationType,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'opération',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  items: _operationTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type == 'all' ? 'Tous' : _getOperationTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOperationType = value;
                    });
                    _loadData();
                  },
                ),
                const SizedBox(height: 12),
                // Date filters
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                            _loadData();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date début',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('dd/MM/yyyy').format(_startDate!)
                                : 'Toutes',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                            _loadData();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date fin',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('dd/MM/yyyy').format(_endDate!)
                                : 'Toutes',
                          ),
                        ),
                      ),
                    ),
                    if (_startDate != null || _endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _loadData();
                        },
                        tooltip: 'Réinitialiser les dates',
                      ),
                  ],
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
                    : _entries.isEmpty
                        ? const EmptyState(
                            title: 'Aucun historique',
                            message: 'Vos actions récentes apparaîtront ici',
                            icon: Icons.history,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                final employee = entry.actorEmployeeId != null
                                    ? _employees[entry.actorEmployeeId]
                                    : null;
                                
                                return SectionCard(
                                  onTap: () => _navigateToDetail(entry),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getOperationTypeIcon(entry.operationType),
                                              color: AppTheme.primaryBlue,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _getOperationTypeLabel(entry.operationType),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  entry.description ?? entry.action,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            employee != null
                                                ? employee.fullName
                                                : 'Admin',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('dd/MM/yyyy à HH:mm')
                                                .format(entry.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                          ),
                                          // Non-conformity flag for receptions
                                          if (entry.operationType == 'reception' &&
                                              entry.metadata != null &&
                                              (entry.metadata!['is_non_conformant'] == true)) ...[
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.statusWarn.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppTheme.statusWarn,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 14,
                                                    color: AppTheme.statusWarn,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Non conforme',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.statusWarn,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
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
