import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/nettoyage_repository.dart';
import '../../../../data/repositories/tache_nettoyage_repository.dart';
import '../../../../data/models/nettoyage.dart';
import '../../../../data/models/tache_nettoyage.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';

/// Page showing cleaning history
class CleaningHistoryPage extends StatefulWidget {
  const CleaningHistoryPage({super.key});

  @override
  State<CleaningHistoryPage> createState() => _CleaningHistoryPageState();
}

class _CleaningHistoryPageState extends State<CleaningHistoryPage> {
  final _nettoyageRepo = NettoyageRepository();
  final _tacheRepo = TacheNettoyageRepository();
  
  List<Nettoyage> _nettoyages = [];
  Map<String, TacheNettoyage> _taches = {}; // Map of tacheId -> TacheNettoyage
  bool _isLoading = true;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    debugPrint('[CleaningHistory] Loading history data...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all completed nettoyages
      debugPrint('[CleaningHistory] Fetching completed nettoyages...');
      final nettoyages = await _nettoyageRepo.getAllCompleted(
        startDate: _startDate,
        endDate: _endDate,
      );
      debugPrint('[CleaningHistory] Found ${nettoyages.length} nettoyages');
      
      // Get all tasks to map tacheId to task name
      debugPrint('[CleaningHistory] Fetching tasks...');
      final allTasks = await _tacheRepo.getAll();
      debugPrint('[CleaningHistory] Found ${allTasks.length} tasks');
      final tachesMap = <String, TacheNettoyage>{};
      for (final task in allTasks) {
        tachesMap[task.id] = task;
      }

      if (mounted) {
        debugPrint('[CleaningHistory] Updating UI with ${nettoyages.length} nettoyages');
        setState(() {
          _nettoyages = nettoyages;
          _taches = tachesMap;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[CleaningHistory] Error: $e');
      debugPrint('[CleaningHistory] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteNettoyage(Nettoyage nettoyage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet historique ?'),
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
        await _nettoyageRepo.delete(nettoyage.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Historique supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Date filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
          ),
          // List
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadData)
              : _nettoyages.isEmpty
                  ? const EmptyState(
                      title: 'Aucun historique',
                      message: 'Vous n\'avez pas encore d\'historique de nettoyage',
                      icon: Icons.history,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _nettoyages.length,
                        itemBuilder: (context, index) {
                          final nettoyage = _nettoyages[index];
                          final tache = _taches[nettoyage.tacheId];
                          final taskName = tache?.nom ?? 'Tâche inconnue';

                          return SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            taskName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                nettoyage.doneAt != null
                                                    ? DateFormat('dd/MM/yyyy à HH:mm')
                                                        .format(nettoyage.doneAt!)
                                                    : DateFormat('dd/MM/yyyy')
                                                        .format(nettoyage.createdAt),
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
                                    ),
                                    // Conforme badge
                                    if (nettoyage.conforme != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: nettoyage.conforme == true
                                              ? AppTheme.statusOk.withOpacity(0.1)
                                              : AppTheme.statusCritical.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              nettoyage.conforme == true
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: 16,
                                              color: nettoyage.conforme == true
                                                  ? AppTheme.statusOk
                                                  : AppTheme.statusCritical,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              nettoyage.conforme == true
                                                  ? 'Conforme'
                                                  : 'Non conforme',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: nettoyage.conforme == true
                                                    ? AppTheme.statusOk
                                                    : AppTheme.statusCritical,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Delete button
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.grey[600],
                                      onPressed: () => _deleteNettoyage(nettoyage),
                                      tooltip: 'Supprimer',
                                    ),
                                  ],
                                ),
                                if (nettoyage.remarque != null &&
                                    nettoyage.remarque!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.note,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            nettoyage.remarque!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (nettoyage.photoUrl != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.image, size: 40),
                                    ),
                                  ),
                                ],
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
