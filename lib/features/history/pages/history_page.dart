import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/temperature_repository.dart';
import '../../../../data/repositories/reception_repository.dart';
import '../../../../data/repositories/nettoyage_repository.dart';
import '../../../../data/repositories/tache_nettoyage_repository.dart';
import '../../../../repositories/oil_change_repository.dart';
import '../../../../data/repositories/appareil_repository.dart';
import '../../../../data/models/temperature.dart';
import '../../../../data/models/reception.dart';
import '../../../../data/models/nettoyage.dart';
import '../../../../data/models/tache_nettoyage.dart';
import '../../../../data/models/oil_change.dart';
import '../../../../data/models/appareil.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';

/// Unified history entry
class UnifiedHistoryEntry {
  final String id;
  final String type; // 'temperature', 'reception', 'cleaning', 'oil_change'
  final String title;
  final String? description;
  final DateTime createdAt;
  final String? employeeFirstName;
  final String? employeeLastName;
  final bool isAlert; // true if temperature out of range or non-conformity
  final Map<String, dynamic>? metadata;

  UnifiedHistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.createdAt,
    this.employeeFirstName,
    this.employeeLastName,
    this.isAlert = false,
    this.metadata,
  });

  String get employeeName {
    if (employeeFirstName != null && employeeLastName != null) {
      return '$employeeFirstName $employeeLastName';
    }
    if (employeeFirstName != null) return employeeFirstName!;
    if (employeeLastName != null) return employeeLastName!;
    return 'Non spécifié';
  }
}

/// Central unified history page showing all actions from all modules
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _temperatureRepo = TemperatureRepository();
  final _receptionRepo = ReceptionRepository();
  final _nettoyageRepo = NettoyageRepository();
  final _tacheRepo = TacheNettoyageRepository();
  final _oilChangeRepo = OilChangeRepository();
  final _appareilRepo = AppareilRepository();
  
  List<UnifiedHistoryEntry> _entries = [];
  Map<String, Appareil> _appareils = {}; // Map of appareilId -> Appareil
  Map<String, TacheNettoyage> _taches = {}; // Map of tacheId -> TacheNettoyage
  Map<String, String> _friteuses = {}; // Map of friteuseId -> friteuseNom
  bool _isLoading = true;
  String? _error;
  String? _selectedOperationType;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _operationTypes = [
    'all',
    'reception',
    'temperature',
    'cleaning',
    'oil_change',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOperationType = 'all';
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    debugPrint('[HistoryPage] Loading unified history data...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load appareils for temperature display
      final appareils = await _appareilRepo.getAll();
      final appareilsMap = <String, Appareil>{};
      for (final appareil in appareils) {
        appareilsMap[appareil.id] = appareil;
      }
      _appareils = appareilsMap;

      // Load tasks for cleaning task names
      final taches = await _tacheRepo.getAll();
      final tachesMap = <String, TacheNettoyage>{};
      for (final tache in taches) {
        tachesMap[tache.id] = tache;
      }
      _taches = tachesMap;

      // Load fryers for oil change machine names
      final fryers = await _oilChangeRepo.getFryers();
      final friteusesMap = <String, String>{};
      for (final fryer in fryers) {
        final id = fryer['id'] as String?;
        final nom = fryer['nom'] as String?;
        if (id != null && nom != null) {
          friteusesMap[id] = nom;
        }
      }
      _friteuses = friteusesMap;

      final allEntries = <UnifiedHistoryEntry>[];

      // Load temperatures
      if (_selectedOperationType == 'all' || _selectedOperationType == 'temperature') {
        debugPrint('[HistoryPage] Loading temperatures...');
        final temperatures = await _temperatureRepo.getAll(
          startDate: _startDate,
          endDate: _endDate,
        );
        debugPrint('[HistoryPage] Found ${temperatures.length} temperatures');
        
        for (final temp in temperatures) {
          final appareil = _appareils[temp.appareilId];
          final appareilName = appareil?.nom ?? 'Appareil inconnu';
          final isAlert = _isTemperatureAlert(temp.temperature, appareil);
          
          allEntries.add(UnifiedHistoryEntry(
            id: temp.id,
            type: 'temperature',
            title: 'Température: $appareilName',
            description: '${temp.temperature}°C${temp.remarque != null ? ' - ${temp.remarque}' : ''}',
            createdAt: temp.createdAt,
            employeeFirstName: temp.employeeFirstName,
            employeeLastName: temp.employeeLastName,
            isAlert: isAlert,
            metadata: {
              'temperature': temp.temperature,
              'appareil': appareilName,
              'remarque': temp.remarque,
            },
          ));
        }
      }

      // Load receptions
      if (_selectedOperationType == 'all' || _selectedOperationType == 'reception') {
        debugPrint('[HistoryPage] Loading receptions...');
        final receptions = await _receptionRepo.getAll(
          startDate: _startDate,
          endDate: _endDate,
        );
        debugPrint('[HistoryPage] Found ${receptions.length} receptions');
        
        for (final reception in receptions) {
          final isAlert = reception.temperature != null && 
              (reception.temperature! > 7 || reception.temperature! < -18);
          
          allEntries.add(UnifiedHistoryEntry(
            id: reception.id,
            type: 'reception',
            title: 'Réception${reception.fournisseur != null ? ': ${reception.fournisseur}' : ''}',
            description: reception.lot != null 
                ? 'Lot: ${reception.lot}${reception.temperature != null ? ' - ${reception.temperature}°C' : ''}'
                : reception.temperature != null 
                    ? 'Température: ${reception.temperature}°C'
                    : null,
            createdAt: reception.receivedAt,
            employeeFirstName: reception.employeeFirstName,
            employeeLastName: reception.employeeLastName,
            isAlert: isAlert,
            metadata: {
              'fournisseur': reception.fournisseur,
              'lot': reception.lot,
              'temperature': reception.temperature,
            },
          ));
        }
      }

      // Load nettoyages
      if (_selectedOperationType == 'all' || _selectedOperationType == 'cleaning') {
        debugPrint('[HistoryPage] Loading nettoyages...');
        final nettoyages = await _nettoyageRepo.getAllCompleted(
          startDate: _startDate,
          endDate: _endDate,
        );
        debugPrint('[HistoryPage] Found ${nettoyages.length} nettoyages');
        
        for (final nettoyage in nettoyages) {
          final tache = _taches[nettoyage.tacheId];
          final taskName = tache?.nom ?? 'Tâche inconnue';
          
          allEntries.add(UnifiedHistoryEntry(
            id: nettoyage.id,
            type: 'cleaning',
            title: 'Nettoyage: $taskName',
            description: nettoyage.remarque,
            createdAt: nettoyage.doneAt ?? nettoyage.createdAt,
            employeeFirstName: nettoyage.employeeFirstName,
            employeeLastName: nettoyage.employeeLastName,
            isAlert: nettoyage.conforme == false,
            metadata: {
              'tache_id': nettoyage.tacheId,
              'tache_nom': taskName,
              'conforme': nettoyage.conforme,
            },
          ));
        }
      }

      // Load oil changes
      if (_selectedOperationType == 'all' || _selectedOperationType == 'oil_change') {
        debugPrint('[HistoryPage] Loading oil changes...');
        final oilChangesData = await _oilChangeRepo.getAll();
        debugPrint('[HistoryPage] Found ${oilChangesData.length} oil changes');
        
        // Filter by date if needed
        final filteredOilChanges = oilChangesData.where((data) {
          final changedAt = data['changed_at'] != null
              ? DateTime.tryParse(data['changed_at'].toString())
              : (data['created_at'] != null
                  ? DateTime.tryParse(data['created_at'].toString())
                  : null);
          if (changedAt == null) return false;
          if (_startDate != null && changedAt.isBefore(_startDate!)) return false;
          if (_endDate != null) {
            final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            if (changedAt.isAfter(endOfDay)) return false;
          }
          return true;
        }).toList();
        
        for (final data in filteredOilChanges) {
          final oilChange = OilChange.fromJson(data);
          // Get machine name from friteuses map or from oilChange model
          final machineName = oilChange.friteuseNom ?? 
              _friteuses[oilChange.friteuseId] ?? 
              'Machine inconnue';
          
          allEntries.add(UnifiedHistoryEntry(
            id: oilChange.id,
            type: 'oil_change',
            title: 'Changement d\'huile: $machineName',
            description: oilChange.remarque,
            createdAt: oilChange.changedAt,
            employeeFirstName: oilChange.employeeFirstName,
            employeeLastName: oilChange.employeeLastName,
            isAlert: false,
            metadata: {
              'friteuse_id': oilChange.friteuseId,
              'friteuse_nom': machineName,
              'quantite': data['quantite'],
            },
          ));
        }
      }

      // Sort by date (newest first)
      allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('[HistoryPage] ✅ Total entries: ${allEntries.length}');

      if (mounted) {
        setState(() {
          _entries = allEntries;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[HistoryPage] ❌ Error: $e');
      debugPrint('[HistoryPage] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isTemperatureAlert(double temperature, Appareil? appareil) {
    if (appareil == null) return false;
    if (appareil.tempMin != null && temperature < appareil.tempMin!) return true;
    if (appareil.tempMax != null && temperature > appareil.tempMax!) return true;
    return false;
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
      default:
        return Icons.history;
    }
  }

  Color _getOperationTypeColor(String type) {
    switch (type) {
      case 'reception':
        return Colors.green;
      case 'temperature':
        return Colors.blue;
      case 'oil_change':
        return Colors.orange;
      case 'cleaning':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _navigateToDetail(UnifiedHistoryEntry entry) {
    switch (entry.type) {
      case 'reception':
        context.push('/app/receptions');
        break;
      case 'temperature':
        context.push('/app/temperatures');
        break;
      case 'oil_change':
        context.push('/oil-changes');
        break;
      case 'cleaning':
        context.push('/app/cleaning');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique unifié'),
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
                                final typeColor = _getOperationTypeColor(entry.type);
                                
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
                                              color: entry.isAlert
                                                  ? AppTheme.statusCritical.withOpacity(0.1)
                                                  : typeColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: entry.isAlert
                                                  ? Border.all(
                                                      color: AppTheme.statusCritical,
                                                      width: 2,
                                                    )
                                                  : null,
                                            ),
                                            child: Icon(
                                              _getOperationTypeIcon(entry.type),
                                              color: entry.isAlert
                                                  ? AppTheme.statusCritical
                                                  : typeColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        entry.title,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: entry.isAlert
                                                                  ? AppTheme.statusCritical
                                                                  : null,
                                                            ),
                                                      ),
                                                    ),
                                                    if (entry.isAlert)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.statusCritical,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'ALERTE',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (entry.description != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    entry.description!,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            entry.employeeName,
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
