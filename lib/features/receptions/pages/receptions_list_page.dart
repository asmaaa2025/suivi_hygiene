import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/reception_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/models/reception.dart';
import '../../../../data/models/produit.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import 'reception_form_page.dart';

/// Receptions history page - Shows all reception records
class ReceptionsListPage extends StatefulWidget {
  const ReceptionsListPage({super.key});

  @override
  State<ReceptionsListPage> createState() => _ReceptionsListPageState();
}

class _ReceptionsListPageState extends State<ReceptionsListPage> {
  final _receptionRepo = ReceptionRepository();
  final _produitRepo = ProduitRepository();

  List<Reception> _receptions = [];
  Map<String, Produit> _produits = {}; // Map of produitId -> Produit
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

    debugPrint('[ReceptionsList] Loading receptions data...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all receptions
      debugPrint('[ReceptionsList] Fetching receptions...');
      final receptions = await _receptionRepo.getAll(
        startDate: _startDate,
        endDate: _endDate,
      );
      debugPrint('[ReceptionsList] Found ${receptions.length} receptions');

      // Get all products to map produitId to product name
      debugPrint('[ReceptionsList] Fetching products...');
      final allProducts = await _produitRepo.getAll();
      debugPrint('[ReceptionsList] Found ${allProducts.length} products');
      final produitsMap = <String, Produit>{};
      for (final product in allProducts) {
        produitsMap[product.id] = product;
      }

      if (mounted) {
        debugPrint(
          '[ReceptionsList] Updating UI with ${receptions.length} receptions',
        );
        setState(() {
          _receptions = receptions;
          _produits = produitsMap;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[ReceptionsList] Error: $e');
      debugPrint('[ReceptionsList] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReception(
    BuildContext context,
    Reception reception,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Êtes-vous sûr de vouloir supprimer cette réception ?'),
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
        await _receptionRepo.delete(reception.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Réception supprimée')));
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

  void _editReception(BuildContext context, Reception reception) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';
    context.push('$routePrefix/receptions/${reception.id}');
  }

  void _showPhotoDialog(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.black87,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Impossible de charger l\'image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.black87,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des réceptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/app/receptions/new'),
            tooltip: 'Nouvelle réception',
          ),
        ],
      ),
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
                : _receptions.isEmpty
                ? const EmptyState(
                    title: 'Aucune réception',
                    message: 'Vous n\'avez pas encore enregistré de réception',
                    icon: Icons.inventory_2,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _receptions.length,
                      itemBuilder: (context, index) {
                        final reception = _receptions[index];
                        final produit = _produits[reception.produitId];
                        final productName = produit?.nom ?? 'Produit inconnu';
                        final supplierName =
                            reception.fournisseur ?? 'Fournisseur inconnu';

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
                                          productName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fournisseur: $supplierName',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Temperature badge
                                  if (reception.temperature != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getTemperatureColor(
                                          reception.temperature!,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.thermostat,
                                            size: 16,
                                            color: _getTemperatureColor(
                                              reception.temperature!,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${reception.temperature!.toStringAsFixed(1)}°C',
                                            style: TextStyle(
                                              color: _getTemperatureColor(
                                                reception.temperature!,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                                    ).format(reception.receivedAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              if (reception.lot != null &&
                                  reception.lot!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.inventory,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lot: ${reception.lot}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                              if (reception.dluo != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'DLUO: ${DateFormat('dd/MM/yyyy').format(reception.dluo!)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                              if (reception.remarque != null &&
                                  reception.remarque!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  reception.remarque!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontStyle: FontStyle.italic),
                                ),
                              ],
                              if (reception.photoUrl != null &&
                                  reception.photoUrl!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () => _showPhotoDialog(
                                    context,
                                    reception.photoUrl!,
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
                                        reception.photoUrl!,
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
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (reception.employeeFirstName != null &&
                                  reception.employeeLastName != null) ...[
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
                                      'Effectué par: ${reception.employeeFirstName} ${reception.employeeLastName}',
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
                                        _editReception(context, reception),
                                    tooltip: 'Modifier',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    color: AppTheme.statusCritical,
                                    onPressed: () =>
                                        _deleteReception(context, reception),
                                    tooltip: 'Supprimer',
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

  Color _getTemperatureColor(double temperature) {
    // Temperature ranges for reception
    if (temperature > 7 || temperature < -18) {
      return AppTheme.statusCritical; // Non-conforme
    }
    return AppTheme.statusOk; // Conforme
  }
}
