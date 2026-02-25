import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../repositories/oil_change_repository.dart';
import '../../../../data/repositories/audit_log_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../services/cache_service.dart';
import '../../../../services/employee_session_service.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../data/models/oil_change.dart';

class SuiviHuilePage extends StatefulWidget {
  const SuiviHuilePage({super.key});

  @override
  State<SuiviHuilePage> createState() => _SuiviHuilePageState();
}

class _SuiviHuilePageState extends State<SuiviHuilePage> {
  final _formKey = GlobalKey<FormState>();
  final _oilChangeRepo = OilChangeRepository();
  final _auditLogRepo = AuditLogRepository();
  final _orgRepo = OrganizationRepository();
  final _employeeSessionService = EmployeeSessionService();
  final _networkService = NetworkService();
  final _machineController = TextEditingController();
  final _typeHuileController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _remarqueController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _changements = [];
  List<Map<String, dynamic>> _fryers = [];
  bool _isOnline = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadFryers();
    _loadChangements();
    _networkService.connectivityStream.listen((_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    final isOnline = await _networkService.hasConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _loadFryers() async {
    try {
      final fryers = await _oilChangeRepo.getFryers();
      if (mounted) {
        setState(() {
          _fryers = fryers;
        });
      }
    } catch (e) {
      debugPrint('❌ [Suivi Huile] Erreur chargement friteuses: $e');
    }
  }

  @override
  void dispose() {
    _machineController.dispose();
    _typeHuileController.dispose();
    _quantiteController.dispose();
    _remarqueController.dispose();
    super.dispose();
  }

  Future<void> _loadChangements() async {
    setState(() => _isLoading = true);
    try {
      // Try cache first
      final cached = CacheService().get('oil_changes_all');
      if (cached != null) {
        setState(() {
          _changements = List<Map<String, dynamic>>.from(cached);
        });
      }

      // Load from Supabase
      final changements = await _oilChangeRepo.getAll();
      if (mounted) {
        setState(() {
          _changements = changements.map((c) {
            final dateStr = c['date'] as String?;
            final friteuseId = c['friteuse_id'] as String?;
            if (friteuseId == null) {
              return {
                ...c,
                'date': dateStr != null
                    ? DateTime.parse(dateStr)
                    : DateTime.now(),
                'machine': 'Machine inconnue',
              };
            }
            final fryer = _fryers.firstWhere(
              (f) => f['id'] == friteuseId,
              orElse: () => <String, dynamic>{},
            );
            final machineName = fryer.isNotEmpty
                ? (fryer['nom'] as String? ?? 'Machine inconnue')
                : 'Machine inconnue (ID: $friteuseId)';
            return {
              ...c,
              'date': dateStr != null
                  ? DateTime.parse(dateStr)
                  : DateTime.now(),
              'machine': machineName,
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveChangement() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final machineNom = _machineController.text.trim();
      final quantiteStr = _quantiteController.text.trim();
      final quantite =
          double.tryParse(quantiteStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;

      // Find or create friteuse
      var friteuse = _fryers.firstWhere(
        (f) => (f['nom'] as String?)?.toLowerCase() == machineNom.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      String friteuseId;
      if (friteuse.isEmpty) {
        // Create new friteuse with owner_id
        final user = _oilChangeRepo.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        debugPrint('[SuiviHuile] Creating new friteuse: $machineNom');
        final newFriteuse = await _oilChangeRepo.client
            .from('friteuses')
            .insert({
              'nom': machineNom,
              'owner_id': user.id, // Ensure owner_id is set
            })
            .select()
            .single();
        friteuseId = newFriteuse['id'] as String;
        debugPrint('[SuiviHuile] ✅ Created friteuse: $friteuseId');
        await _loadFryers();
      } else {
        friteuseId = friteuse['id'] as String;
        debugPrint('[SuiviHuile] Using existing friteuse: $friteuseId');
      }

      // Save oil change
      // Employee name is automatically retrieved by repository from current session
      final createdChange = await _oilChangeRepo.createOilChange(
        friteuseId: friteuseId,
        quantite: quantite,
        remarque: _remarqueController.text.trim().isEmpty
            ? null
            : _remarqueController.text.trim(),
      );

      // Create audit log entry
      try {
        final orgId = await _orgRepo.getOrCreateOrganization();
        await _auditLogRepo.create(
          organizationId: orgId,
          operationType: 'oil_change',
          operationId: createdChange['id'] as String?,
          action: 'create',
          description: 'Changement d\'huile: $machineNom (${quantite}L)',
          metadata: {
            'friteuse_id': friteuseId,
            'friteuse_nom': machineNom,
            'quantite': quantite,
            'remarque': _remarqueController.text.trim().isEmpty
                ? null
                : _remarqueController.text.trim(),
          },
        );
      } catch (e) {
        debugPrint('[SuiviHuile] Error creating audit log: $e');
        // Don't fail the oil change save if audit log fails
      }

      // Reload list
      await _loadChangements();

      // Reset form
      _machineController.clear();
      _typeHuileController.clear();
      _quantiteController.clear();
      _remarqueController.clear();
      setState(() {
        _selectedDate = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changement d\'huile enregistré')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Suivi d\'Huile'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('$routePrefix/haccp'),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Formulaire
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nouveau changement d\'huile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _machineController,
                            decoration: const InputDecoration(
                              labelText: 'Machine',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.build),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer le nom de la machine';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _typeHuileController,
                            decoration: const InputDecoration(
                              labelText: 'Type d\'huile',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.opacity),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer le type d\'huile';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _quantiteController,
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.straighten),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer la quantité';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _remarqueController,
                            decoration: const InputDecoration(
                              labelText: 'Remarque (optionnel)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveChangement,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Enregistrer'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            // Titre de l'historique
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const Text(
                  'Historique des changements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 8)),
            // Liste des changements
            _changements.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: EmptyState(
                        title: 'Aucun changement enregistré',
                        message:
                            'Vous n\'avez pas encore enregistré de changement d\'huile',
                        icon: Icons.oil_barrel,
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final changement = _changements[index];
                        final oilChange = OilChange.fromJson(changement);
                        final date = changement['date'] is DateTime
                            ? changement['date'] as DateTime
                            : DateTime.parse(changement['date'] as String);
                        final quantite = changement['quantite'];
                        final remarque = changement['remarque'] as String?;
                        final machineName =
                            changement['machine'] as String? ??
                            'Machine inconnue';

                        return SectionCard(
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
                                          machineName,
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
                                              DateFormat(
                                                'dd/MM/yyyy à HH:mm',
                                              ).format(date),
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
                                  // Quantité badge
                                  if (quantite != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.amber,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.opacity,
                                            size: 20,
                                            color: Colors.amber[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$quantite L',
                                            style: TextStyle(
                                              color: Colors.amber[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (remarque != null && remarque.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.note,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          remarque,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (oilChange.photoUrl != null &&
                                  oilChange.photoUrl!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _showPhotoDialog(
                                    context,
                                    oilChange.photoUrl!,
                                  ),
                                  child: Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        oilChange.photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                ),
                                              );
                                            },
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (oilChange.employeeFirstName != null &&
                                  oilChange.employeeLastName != null) ...[
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
                                      'Effectué par: ${oilChange.employeeFirstName} ${oilChange.employeeLastName}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                              // Action buttons
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: AppTheme.primaryBlue,
                                    onPressed: () =>
                                        _editOilChange(context, oilChange),
                                    tooltip: 'Modifier',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    color: AppTheme.statusCritical,
                                    onPressed: () =>
                                        _deleteOilChange(context, oilChange),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }, childCount: _changements.length),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOilChange(
    BuildContext context,
    OilChange oilChange,
  ) async {
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
        await _oilChangeRepo.deleteOilChange(oilChange.id);
        await _loadChangements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Changement d\'huile supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  void _editOilChange(BuildContext context, OilChange oilChange) {
    // For now, we'll just show a message that editing is not yet implemented
    // In the future, we could navigate to an edit form
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'L\'édition des changements d\'huile sera disponible prochainement',
        ),
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
