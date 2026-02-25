import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/models/supplier.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import 'supplier_form_page.dart';

/// Suppliers list page
class SuppliersListPage extends StatefulWidget {
  const SuppliersListPage({super.key});

  @override
  State<SuppliersListPage> createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends State<SuppliersListPage> {
  final _supplierRepo = SupplierRepository();
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String? _error;

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
      final suppliers = await _supplierRepo.getAll();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
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

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${supplier.name} ?'),
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
        await _supplierRepo.delete(supplier.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Fournisseur supprimé')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/suppliers/new'),
            tooltip: 'Nouveau fournisseur',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : _suppliers.isEmpty
          ? const EmptyState(
              title: 'Aucun fournisseur',
              message: 'Ajoutez votre premier fournisseur',
              icon: Icons.local_shipping,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _suppliers[index];
                  return SectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    supplier.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (supplier.isOccasional) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Occasionnel',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (supplier.contactInfo != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  supplier.contactInfo!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              context.push('/suppliers/${supplier.id}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSupplier(supplier),
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
