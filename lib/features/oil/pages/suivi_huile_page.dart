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
import '../../../../shared/widgets/app_module_tile.dart';
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
  List<Map<String, dynamic>> _fryers = [];
  final Map<String, DateTime> _lastChangesByFryer = {};
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
      // Load all oil changes once and compute the last change per fryer
      final allChangesData = await _oilChangeRepo.getAll();

      final Map<String, DateTime> lastByFryer = {};
      for (final data in allChangesData) {
        final fryerId = data['friteuse_id']?.toString();
        if (fryerId == null || fryerId.isEmpty) continue;

        DateTime? changedAt;
        if (data['changed_at'] != null) {
          changedAt = DateTime.tryParse(data['changed_at'].toString());
        }
        changedAt ??= (data['created_at'] != null
            ? DateTime.tryParse(data['created_at'].toString())
            : null);
        if (changedAt == null) continue;

        final existing = lastByFryer[fryerId];
        if (existing == null || changedAt.isAfter(existing)) {
          lastByFryer[fryerId] = changedAt;
        }
      }

      if (mounted) {
        setState(() {
          _lastChangesByFryer
            ..clear()
            ..addAll(lastByFryer);
        });
      }
    } catch (e) {
      debugPrint('[SuiviHuile] Error loading last changes: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCreateFriteuseDialog() async {
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle friteuse'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom de la friteuse',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_fire_department),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final user = _oilChangeRepo.client.auth.currentUser;
                if (user == null) {
                  throw Exception('Utilisateur non authentifié');
                }
                await _oilChangeRepo.client.from('friteuses').insert({
                  'nom': name,
                  'owner_id': user.id,
                });
                await _loadFryers();
                await _loadChangements();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Friteuse ajoutée'),
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
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageFriteuseDialog(Map<String, dynamic> fryer) async {
    final nameController = TextEditingController(
      text: fryer['nom'] as String? ?? '',
    );
    final fryerId = fryer['id']?.toString();
    if (fryerId == null || fryerId.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gérer la friteuse'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom de la friteuse',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              try {
                await _oilChangeRepo.client
                    .from('friteuses')
                    .update({'nom': newName}).eq('id', fryerId);
                await _loadFryers();
                await _loadChangements();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Friteuse renommée'),
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
            },
            child: const Text('Enregistrer'),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supprimer la friteuse'),
                  content: const Text(
                    'Êtes-vous sûr de vouloir supprimer cette friteuse ?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              try {
                await _oilChangeRepo.client
                    .from('friteuses')
                    .delete()
                    .eq('id', fryerId);
                await _loadFryers();
                await _loadChangements();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Friteuse supprimée'),
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
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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

  void _openOilChangeSheet(String machineName) {
    _machineController.text = machineName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Changement d\'huile',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    machineName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantité (en litres)',
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
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }
                        await _saveChangement();
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Enregistrer le changement'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suivi d\'huile par friteuse',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Touchez une friteuse pour enregistrer un changement d\'huile.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_fryers.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Last tile: add new friteuse
                      if (index == _fryers.length) {
                        return AppModuleTile(
                          icon: Icons.add,
                          title: 'Ajouter une friteuse',
                          subtitle: 'Créer une nouvelle friteuse',
                          color: AppTheme.statusWarn,
                          onTap: _showCreateFriteuseDialog,
                        );
                      }

                      final fryer = _fryers[index];
                      final machineName =
                          (fryer['nom'] as String?) ?? 'Friteuse ${index + 1}';
                      final fryerId = fryer['id']?.toString();
                      final lastChange = fryerId != null
                          ? _lastChangesByFryer[fryerId]
                          : null;
                      final subtitle = lastChange != null
                          ? 'Dernier changement : ${DateFormat('dd/MM/yyyy').format(lastChange)}'
                          : 'Dernier changement : -';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openOilChangeSheet(machineName),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Ligne du haut : icône + bouton 3 points alignés
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.statusWarn
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.oil_barrel,
                                        size: 24,
                                        color: AppTheme.statusWarn,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: () =>
                                          _showManageFriteuseDialog(fryer),
                                      tooltip: 'Gérer la friteuse',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Nom centré
                                Text(
                                  machineName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Sous-titre centré
                                Text(
                                  subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _fryers.length + 1,
                  ),
                ),
              ),
            if (_fryers.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Aucune friteuse trouvée pour le moment.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
