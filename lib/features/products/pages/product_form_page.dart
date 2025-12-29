import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../repositories/products_repository.dart';

/// Form page for creating/editing a product
class ProductFormPage extends StatefulWidget {
  final String? productId;

  const ProductFormPage({super.key, this.productId});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _categorieController = TextEditingController();
  final _allergenesController = TextEditingController();
  final _produitRepo = ProductsRepository();

  bool _actif = true;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productId != null;
    if (_isEditMode) {
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _categorieController.dispose();
    _allergenesController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    if (widget.productId == null) return;

    setState(() => _isLoading = true);

    try {
      final produitData = await _produitRepo.getById(widget.productId!);
      setState(() {
        _nomController.text = produitData['nom'] ?? '';
        _categorieController.text = produitData['type_produit'] ?? '';
        _allergenesController.text = produitData['allergenes'] ?? '';
        _actif = produitData['actif'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        context.pop();
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditMode && widget.productId != null) {
        await _produitRepo.update(
          id: widget.productId!,
          nom: _nomController.text.trim(),
          categorie: _categorieController.text.trim().isEmpty
              ? null
              : _categorieController.text.trim(),
          allergenes: _allergenesController.text.trim().isEmpty
              ? null
              : _allergenesController.text.trim(),
          actif: _actif,
        );
      } else {
        await _produitRepo.create(
          nom: _nomController.text.trim(),
          categorie: _categorieController.text.trim().isEmpty
              ? null
              : _categorieController.text.trim(),
          allergenes: _allergenesController.text.trim().isEmpty
              ? null
              : _allergenesController.text.trim(),
          actif: _actif,
        );
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Produit modifié' : 'Produit créé'),
            backgroundColor: AppTheme.statusOk,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier produit' : 'Nouveau produit'),
      ),
      body: _isLoading && _isEditMode
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit *',
                      prefixIcon: Icon(Icons.shopping_basket),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categorieController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie (optionnel)',
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allergenesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Allergènes (optionnel)',
                      prefixIcon: Icon(Icons.warning),
                      helperText: 'Ex: Gluten, Lait, Œufs',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Produit actif'),
                    subtitle: const Text(
                        'Les produits inactifs ne seront pas disponibles dans les listes'),
                    value: _actif,
                    onChanged: (value) => setState(() => _actif = value),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditMode ? 'Modifier' : 'Créer'),
                  ),
                ],
              ),
            ),
    );
  }
}
