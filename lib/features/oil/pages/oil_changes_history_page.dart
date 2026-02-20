import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../repositories/oil_change_repository.dart';
import '../../../../data/models/oil_change.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import '../../../../shared/utils/error_handler.dart';
import 'suivi_huile_page.dart';

/// Oil changes history page with full CRUD
class OilChangesHistoryPage extends StatefulWidget {
  const OilChangesHistoryPage({super.key});

  @override
  State<OilChangesHistoryPage> createState() => _OilChangesHistoryPageState();
}

class _OilChangesHistoryPageState extends State<OilChangesHistoryPage> {
  final _oilChangeRepo = OilChangeRepository();

  List<OilChange> _oilChanges = [];
  List<Map<String, dynamic>> _fryers = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPeriod = 'all'; // 'today', 'week', 'all'

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    _loadData();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        _endDate = now;
        break;
      case 'all':
        _startDate = null;
        _endDate = null;
        break;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load fryers for machine names
      final fryers = await _oilChangeRepo.getFryers();
      final fryersMap = <String, String>{};
      for (final fryer in fryers) {
        final id = fryer['id'] as String?;
        final nom = fryer['nom'] as String?;
        if (id != null && nom != null) {
          fryersMap[id] = nom;
        }
      }

      // Load all oil changes
      final allChangesData = await _oilChangeRepo.getAll();

      // Filter by date if needed
      final filteredChanges = allChangesData.where((data) {
        final changedAt = data['changed_at'] != null
            ? DateTime.tryParse(data['changed_at'].toString())
            : (data['created_at'] != null
                  ? DateTime.tryParse(data['created_at'].toString())
                  : null);
        if (changedAt == null) return false;
        if (_startDate != null && changedAt.isBefore(_startDate!)) return false;
        if (_endDate != null) {
          final endOfDay = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
          );
          if (changedAt.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();

      final oilChanges = filteredChanges
          .map((data) => OilChange.fromJson(data))
          .toList();

      // Sort by date (newest first)
      oilChanges.sort((a, b) => b.changedAt.compareTo(a.changedAt));

      if (mounted) {
        setState(() {
          _oilChanges = oilChanges;
          _fryers = fryers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[OilChangesHistory] ❌ Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getMachineName(OilChange change) {
    return change.friteuseNom ??
        (_fryers.firstWhere(
                  (f) => f['id'] == change.friteuseId,
                  orElse: () => <String, dynamic>{},
                )['nom']
                as String? ??
            'Machine inconnue');
  }

  Future<void> _deleteOilChange(OilChange change) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce changement d\'huile ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _oilChangeRepo.deleteOilChange(change.id);
        await _loadData();
        if (mounted) {
          ErrorHandler.showSuccess(context, 'Changement d\'huile supprimé');
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  void _editOilChange(OilChange change) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';
    // Navigate to edit form (we'll need to create this or use the existing form)
    // For now, show a dialog to edit
    _showEditDialog(change);
  }

  void _showEditDialog(OilChange change) {
    final quantiteController = TextEditingController(
      text: change.quantite.toString(),
    );
    final remarqueController = TextEditingController(
      text: change.remarque ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier changement d\'huile: ${_getMachineName(change)}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: quantiteController,
                  decoration: const InputDecoration(
                    labelText: 'Quantité (L) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.opacity),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez saisir une quantité';
                    }
                    final qty = double.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return 'Veuillez saisir une quantité valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: remarqueController,
                  decoration: const InputDecoration(
                    labelText: 'Remarque (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _oilChangeRepo.updateOilChange(
                    id: change.id,
                    quantite: double.parse(quantiteController.text),
                    remarque: remarqueController.text.trim().isEmpty
                        ? null
                        : remarqueController.text.trim(),
                  );
                  Navigator.pop(context);
                  await _loadData();
                  if (mounted) {
                    ErrorHandler.showSuccess(
                      context,
                      'Changement d\'huile modifié',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ErrorHandler.showError(context, e);
                  }
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
          tooltip: 'Retour',
        ),
        title: const Text('Historique des changements d\'huile'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Period filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Aujourd\'hui'),
                    selected: _selectedPeriod == 'today',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPeriod = 'today';
                          _updateDateRange();
                        });
                        _loadData();
                      }
                    },
                    selectedColor: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Semaine'),
                    selected: _selectedPeriod == 'week',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPeriod = 'week';
                          _updateDateRange();
                        });
                        _loadData();
                      }
                    },
                    selectedColor: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Tout'),
                    selected: _selectedPeriod == 'all',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPeriod = 'all';
                          _updateDateRange();
                        });
                        _loadData();
                      }
                    },
                    selectedColor: AppTheme.primaryBlue,
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Erreur: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _oilChanges.isEmpty
                ? const EmptyState(
                    icon: Icons.oil_barrel,
                    title: 'Aucun changement d\'huile',
                    message:
                        'Aucun changement d\'huile trouvé pour cette période',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _oilChanges.length,
                    itemBuilder: (context, index) {
                      final change = _oilChanges[index];
                      final machineName = _getMachineName(change);
                      final employeeName =
                          change.employeeFirstName != null &&
                              change.employeeLastName != null
                          ? '${change.employeeFirstName} ${change.employeeLastName}'
                          : 'Non spécifié';

                      return SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.oil_barrel,
                                  color: AppTheme.statusWarn,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        machineName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${change.quantite}L',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  color: AppTheme.primaryBlue,
                                  onPressed: () => _editOilChange(change),
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  color: AppTheme.statusCritical,
                                  onPressed: () => _deleteOilChange(change),
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  employeeName,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy à HH:mm',
                                  ).format(change.changedAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            if (change.remarque != null &&
                                change.remarque!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                change.remarque!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
