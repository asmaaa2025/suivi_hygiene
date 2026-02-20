/// Tableau des allergènes - Règlement INCO 2011
/// Information consommateur sur les denrées alimentaires

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../repositories/products_repository.dart';
import '../../../models/produit.dart';

class TableauAllergenesPage extends StatefulWidget {
  const TableauAllergenesPage({super.key});

  @override
  State<TableauAllergenesPage> createState() => _TableauAllergenesPageState();
}

class _TableauAllergenesPageState extends State<TableauAllergenesPage> {
  final _productsRepo = ProductsRepository();
  List<Produit> _produits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _productsRepo.getAll();
      final produits = list.map((m) => Produit.fromMap(m)).toList();
      if (mounted)
        setState(() {
          _produits = produits;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Produit> get _produitsAvecAllergenes => _produits
      .where((p) => p.allergenes != null && p.allergenes!.trim().isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
        ),
        title: const Text('Tableau allergènes'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _produitsAvecAllergenes.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _produitsAvecAllergenes.length,
                itemBuilder: (context, i) {
                  final p = _produitsAvecAllergenes[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.warning_amber, color: Colors.orange),
                      ),
                      title: Text(
                        p.nom,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        p.allergenes!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_food, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun allergène renseigné',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Renseignez les allergènes dans la fiche de chaque produit (module Produits).\nRèglement INCO - Information consommateur.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/products'),
              icon: const Icon(Icons.shopping_basket),
              label: const Text('Voir les produits'),
            ),
          ],
        ),
      ),
    );
  }
}
