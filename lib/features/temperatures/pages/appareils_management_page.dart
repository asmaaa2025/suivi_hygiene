import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/haccp_badge.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../data/repositories/appareil_repository.dart';
import '../../../../data/models/appareil.dart';

/// Page for managing devices (appareils)
class AppareilsManagementPage extends StatefulWidget {
  const AppareilsManagementPage({super.key});

  @override
  State<AppareilsManagementPage> createState() =>
      _AppareilsManagementPageState();
}

class _AppareilsManagementPageState extends State<AppareilsManagementPage> {
  final _appareilRepo = AppareilRepository();

  List<Appareil> _appareils = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppareils();
  }

  Future<void> _loadAppareils() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[AppareilsManagement] Loading appareils...');
      final appareils = await _appareilRepo.getAll();

      if (mounted) {
        setState(() {
          _appareils = appareils;
          _isLoading = false;
        });
      }
      debugPrint(
        '[AppareilsManagement] ✅ Loaded ${appareils.length} appareils',
      );
    } catch (e, stackTrace) {
      debugPrint('[AppareilsManagement] ❌ Error loading appareils: $e');
      debugPrint('[AppareilsManagement] StackTrace: $stackTrace');

      String errorMessage = 'Erreur lors du chargement des appareils';
      if (e.toString().contains('connecté')) {
        errorMessage = 'Vous devez être connecté pour accéder aux appareils';
      } else if (e.toString().contains('Permission')) {
        errorMessage = 'Permission refusée. Vérifiez vos droits d\'accès.';
      } else if (e.toString().isNotEmpty) {
        final errorStr = e.toString();
        if (errorStr.contains('Exception: ')) {
          errorMessage = errorStr.split('Exception: ').last;
        } else {
          errorMessage = errorStr;
        }
      }

      if (mounted) {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddAppareilDialog() async {
    final nomController = TextEditingController();
    final tempMinController = TextEditingController();
    final tempMaxController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvel appareil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  hintText: 'Ex: Frigo 1, Congélateur',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tempMinController,
                      decoration: const InputDecoration(
                        labelText: 'Temp. min (°C)',
                        hintText: 'Optionnel',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: tempMaxController,
                      decoration: const InputDecoration(
                        labelText: 'Temp. max (°C)',
                        hintText: 'Optionnel',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est obligatoire')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() => _isLoading = true);
        await _appareilRepo.create(
          nom: nomController.text.trim(),
          tempMin: tempMinController.text.isNotEmpty
              ? double.tryParse(tempMinController.text)
              : null,
          tempMax: tempMaxController.text.isNotEmpty
              ? double.tryParse(tempMaxController.text)
              : null,
        );
        _loadAppareils();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appareil créé avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showEditAppareilDialog(Appareil appareil) async {
    final nomController = TextEditingController(text: appareil.nom);
    final tempMinController = TextEditingController(
      text: appareil.tempMin?.toString() ?? '',
    );
    final tempMaxController = TextEditingController(
      text: appareil.tempMax?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'appareil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  hintText: 'Ex: Frigo 1, Congélateur',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tempMinController,
                      decoration: const InputDecoration(
                        labelText: 'Temp. min (°C)',
                        hintText: 'Optionnel',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: tempMaxController,
                      decoration: const InputDecoration(
                        labelText: 'Temp. max (°C)',
                        hintText: 'Optionnel',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est obligatoire')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() => _isLoading = true);
        await _appareilRepo.update(
          id: appareil.id,
          nom: nomController.text.trim(),
          tempMin: tempMinController.text.isNotEmpty
              ? double.tryParse(tempMinController.text)
              : null,
          tempMax: tempMaxController.text.isNotEmpty
              ? double.tryParse(tempMaxController.text)
              : null,
        );
        _loadAppareils();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appareil modifié avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteAppareil(Appareil appareil) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'appareil'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${appareil.nom}" ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Supprimer',
              style: TextStyle(color: AppTheme.statusCritical),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await _appareilRepo.delete(appareil.id);
        _loadAppareils();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Appareil "${appareil.nom}" supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
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
        title: const Text('Gestion des appareils'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAppareilDialog,
            tooltip: 'Ajouter un appareil',
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => const ListItemSkeleton(),
            )
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadAppareils)
          : _appareils.isEmpty
          ? const EmptyState(
              title: 'Aucun appareil',
              message: 'Ajoutez votre premier appareil de mesure',
              icon: Icons.device_thermostat,
            )
          : RefreshIndicator(
              onRefresh: _loadAppareils,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _appareils.length,
                itemBuilder: (context, index) {
                  final appareil = _appareils[index];

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
                                    appareil.nom,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  if (appareil.tempMin != null ||
                                      appareil.tempMax != null)
                                    Row(
                                      children: [
                                        if (appareil.tempMin != null)
                                          Text(
                                            'Min: ${appareil.tempMin!.toStringAsFixed(1)}°C',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        if (appareil.tempMin != null &&
                                            appareil.tempMax != null)
                                          Text(
                                            ' • ',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        if (appareil.tempMax != null)
                                          Text(
                                            'Max: ${appareil.tempMax!.toStringAsFixed(1)}°C',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                      ],
                                    )
                                  else
                                    Text(
                                      'Aucun seuil défini',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textTertiary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Modifier'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: AppTheme.statusCritical,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Supprimer'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditAppareilDialog(appareil);
                                } else if (value == 'delete') {
                                  _deleteAppareil(appareil);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Créé le ${DateFormat('dd/MM/yyyy').format(appareil.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
