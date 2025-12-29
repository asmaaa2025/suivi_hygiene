import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/haccp_badge.dart';
import '../../../../data/repositories/tache_nettoyage_repository.dart';
import '../../../../data/models/tache_nettoyage.dart';
import 'tache_form_page.dart';

/// CRUD page for managing cleaning tasks
class TachesManagementPage extends StatefulWidget {
  const TachesManagementPage({super.key});

  @override
  State<TachesManagementPage> createState() => _TachesManagementPageState();
}

class _TachesManagementPageState extends State<TachesManagementPage> {
  final _tacheRepo = TacheNettoyageRepository();

  List<TacheNettoyage> _taches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taches = await _tacheRepo.getAll();
      setState(() {
        _taches = taches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTache(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette tâche ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer',
                style: TextStyle(color: AppTheme.statusCritical)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tacheRepo.delete(id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  String _getRecurrenceSummary(TacheNettoyage tache) {
    switch (tache.recurrenceType) {
      case 'daily':
        return 'Tous les ${tache.interval} jour(s) à ${tache.timeOfDay}';
      case 'weekly':
        if (tache.weekdays == null || tache.weekdays!.isEmpty) {
          return 'Hebdomadaire à ${tache.timeOfDay}';
        }
        final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        final dayNames = tache.weekdays!.map((d) => days[d - 1]).join(', ');
        return 'Toutes les ${tache.interval} semaine(s): $dayNames à ${tache.timeOfDay}';
      case 'monthly':
        return 'Le ${tache.dayOfMonth} de chaque ${tache.interval} mois à ${tache.timeOfDay}';
      default:
        return tache.timeOfDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des tâches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push('/app/cleaning/taches/new');
              if (result == true) {
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadData)
              : _taches.isEmpty
                  ? const EmptyState(
                      title: 'Aucune tâche',
                      message: 'Créez votre première tâche de nettoyage',
                      icon: Icons.cleaning_services,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _taches.length,
                        itemBuilder: (context, index) {
                          final tache = _taches[index];

                          return SectionCard(
                            color:
                                !tache.isActive ? Colors.grey.shade300 : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tache.nom,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  decoration: !tache.isActive
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getRecurrenceSummary(tache),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    HaccpBadge(
                                      status: tache.isActive
                                          ? HaccpStatus.ok
                                          : HaccpStatus.warning,
                                      label:
                                          tache.isActive ? 'Actif' : 'Inactif',
                                    ),
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  color: AppTheme.primaryBlue),
                                              const SizedBox(width: 8),
                                              const Text('Modifier'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Row(
                                            children: [
                                              Icon(
                                                tache.isActive
                                                    ? Icons.block
                                                    : Icons.check,
                                                color: tache.isActive
                                                    ? AppTheme.statusWarn
                                                    : AppTheme.statusOk,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(tache.isActive
                                                  ? 'Désactiver'
                                                  : 'Activer'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color:
                                                      AppTheme.statusCritical),
                                              const SizedBox(width: 8),
                                              const Text('Supprimer'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          final result = await context.push(
                                            '/app/cleaning/taches/${tache.id}',
                                          );
                                          if (result == true) {
                                            _loadData();
                                          }
                                        } else if (value == 'toggle') {
                                          try {
                                            await _tacheRepo.update(
                                              id: tache.id,
                                              isActive: !tache.isActive,
                                            );
                                            _loadData();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content:
                                                        Text('Erreur: $e')),
                                              );
                                            }
                                          }
                                        } else if (value == 'delete') {
                                          _deleteTache(tache.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/app/cleaning/taches/new');
          if (result == true) {
            _loadData();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
