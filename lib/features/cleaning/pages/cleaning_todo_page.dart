import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/tache_nettoyage_repository.dart';
import '../../../../data/repositories/nettoyage_repository.dart';
import '../../../../services/employee_session_service.dart';
import '../../../../data/models/tache_nettoyage.dart';
import '../../../../data/models/nettoyage.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';

/// Page showing cleaning tasks due today
class CleaningTodoPage extends StatefulWidget {
  const CleaningTodoPage({super.key});

  @override
  State<CleaningTodoPage> createState() => _CleaningTodoPageState();
}

class _CleaningTodoPageState extends State<CleaningTodoPage> {
  final _tacheRepo = TacheNettoyageRepository();
  final _nettoyageRepo = NettoyageRepository();
  
  List<TacheNettoyage> _tasks = [];
  Map<String, Nettoyage> _nettoyages = {}; // Map of tacheId -> Nettoyage
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get tasks due for today
      final tasks = await _tacheRepo.getTasksDueForDate(_selectedDate);
      
      // Get nettoyages for today
      final nettoyages = await _nettoyageRepo.getByDate(_selectedDate);
      final nettoyagesMap = <String, Nettoyage>{};
      for (final nettoyage in nettoyages) {
        if (nettoyage.done) {
          nettoyagesMap[nettoyage.tacheId] = nettoyage;
        }
      }

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _nettoyages = nettoyagesMap;
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

  Future<void> _toggleTaskCompletion(TacheNettoyage task) async {
    final isDone = _nettoyages.containsKey(task.id);
    
    try {
      if (isDone) {
        // Mark as not done - delete nettoyage
        final nettoyage = _nettoyages[task.id];
        if (nettoyage != null) {
          await _nettoyageRepo.delete(nettoyage.id);
        }
      } else {
        // Mark as done - create nettoyage
        // Employee name is automatically retrieved by repository from current session
        await _nettoyageRepo.create(
          tacheId: task.id,
          conforme: true,
        );
      }
      
      // Reload data
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDone 
                ? 'Tâche marquée comme non complétée'
                : 'Tâche marquée comme complétée',
            ),
          ),
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

  int get _completedCount {
    return _nettoyages.length;
  }

  double get _completionPercentage {
    if (_tasks.isEmpty) return 0.0;
    return (_completedCount / _tasks.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadData)
              : _tasks.isEmpty
                  ? const EmptyState(
                      title: 'Aucune tâche aujourd\'hui',
                      message: 'Vous n\'avez pas de tâches de nettoyage prévues pour aujourd\'hui',
                      icon: Icons.check_circle_outline,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: Column(
                        children: [
                          // Progress bar section
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: AppTheme.backgroundSecondary,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progression',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$_completedCount / ${_tasks.length}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _completionPercentage / 100,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _completionPercentage == 100
                                        ? AppTheme.statusOk
                                        : AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_completionPercentage.toStringAsFixed(0)}% complété',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          
                          // Tasks list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _tasks.length,
                              itemBuilder: (context, index) {
                                final task = _tasks[index];
                                final isDone = _nettoyages.containsKey(task.id);
                                
                                return SectionCard(
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      Checkbox(
                                        value: isDone,
                                        onChanged: (_) => _toggleTaskCompletion(task),
                                        activeColor: AppTheme.statusOk,
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Task info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.nom,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    decoration: isDone
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                    color: isDone
                                                        ? Colors.grey
                                                        : null,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  task.timeOfDay,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                                const SizedBox(width: 16),
                                                Icon(
                                                  Icons.repeat,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _getRecurrenceText(task),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                              ],
                                            ),
                                            if (isDone && _nettoyages[task.id]?.doneAt != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Complété à ${DateFormat('HH:mm').format(_nettoyages[task.id]!.doneAt!)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppTheme.statusOk,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  String _getRecurrenceText(TacheNettoyage task) {
    switch (task.recurrenceType) {
      case 'daily':
        return 'Quotidien';
      case 'weekly':
        if (task.weekdays != null && task.weekdays!.isNotEmpty) {
          final days = task.weekdays!.map((d) => _getDayName(d)).join(', ');
          return 'Hebdomadaire ($days)';
        }
        return 'Hebdomadaire';
      case 'monthly':
        if (task.dayOfMonth != null) {
          return 'Mensuel (jour $task.dayOfMonth)';
        }
        return 'Mensuel';
      default:
        return task.recurrenceType;
    }
  }

  String _getDayName(int day) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[day - 1];
  }
}
