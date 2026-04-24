import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../repositories/products_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/supplier_product_repository.dart';
import '../../../../data/models/supplier.dart';
import '../../../../models/produit.dart';
import '../../../../utils/text_input_formatters.dart';
import '../../../../shared/utils/navigation_helpers.dart';

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
  final _dlcJoursController = TextEditingController();
  final _dlcSurgelationController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _origineViandeController = TextEditingController();
  final _allergenesController = TextEditingController();
  final _produitRepo = ProductsRepository();
  final _supplierRepo = SupplierRepository();
  final _supplierProductRepo = SupplierProductRepository();

  bool _actif = true;
  bool _isLoading = false;
  bool _isLoadingData = false;
  bool _isEditMode = false;

  // Product type selection
  TypeProduit _selectedType = TypeProduit.fini;

  // Supplier selection (only for "reçu" products)
  List<Supplier> _suppliers = [];
  String? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productId != null;
    _loadSuppliers();
    if (_isEditMode) {
      _loadProduct();
    } else {
      _dlcJoursController.text = _selectedType.dlcParDefaut.toString();
    }
  }

  int? _parseOptionalInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await _supplierRepo.getAll(includeOccasional: null);
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
        });
      }
    } catch (e) {
      debugPrint('[ProductForm] Error loading suppliers: $e');
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _dlcJoursController.dispose();
    _dlcSurgelationController.dispose();
    _ingredientsController.dispose();
    _quantiteController.dispose();
    _origineViandeController.dispose();
    _allergenesController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    if (widget.productId == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final produitData = await _produitRepo.getById(widget.productId!);
      if (!mounted) return;

      var parsedType = TypeProduit.fini;
      final typeStr = produitData['type_produit'] as String?;
      if (typeStr != null && typeStr.isNotEmpty) {
        switch (typeStr.toLowerCase()) {
          case 'reçu':
          case 'recu':
            parsedType = TypeProduit.recu;
            break;
          case 'fini':
            parsedType = TypeProduit.fini;
            break;
          case 'prepare':
          case 'préparé':
          case 'preparé':
          case 'transformé':
          case 'transforme':
            parsedType = TypeProduit.prepare;
            break;
          case 'ouverture':
          case 'ouvert':
            parsedType = TypeProduit.ouverture;
            break;
          case 'decongelation':
          case 'décongelation':
          case 'décongelé':
          case 'decongele':
            parsedType = TypeProduit.decongelation;
            break;
          default:
            parsedType = TypeProduit.fini;
        }
      }

      String? linkedSupplierId;
      if (parsedType == TypeProduit.recu) {
        linkedSupplierId = await _supplierProductRepo.getSupplierIdForProduct(
          widget.productId!,
        );
      }
      if (!mounted) return;

      setState(() {
        if (_nomController.text.isEmpty) {
          _nomController.text = produitData['nom'] ?? '';
        }
        _selectedType = parsedType;
        _selectedSupplierId = linkedSupplierId;
        if (_allergenesController.text.isEmpty) {
          _allergenesController.text = produitData['allergenes'] ?? '';
        }
        _dlcJoursController.text = produitData['dlc_jours']?.toString() ?? '';
        _dlcSurgelationController.text =
            produitData['dlc_surgelation_jours']?.toString() ?? '';
        _ingredientsController.text = produitData['ingredients'] ?? '';
        _quantiteController.text = produitData['quantite'] ?? '';
        _origineViandeController.text = produitData['origine_viande'] ?? '';
        _actif = produitData['actif'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      if (context.canPop()) {
        context.pop();
      } else {
        await NavigationHelpers.goHaccpHub(context);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == TypeProduit.recu && _selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner un fournisseur pour un produit reçu',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dlcJours = _parseOptionalInt(_dlcJoursController.text);
      final dlcSurgelation = _parseOptionalInt(_dlcSurgelationController.text);

      if (_isEditMode && widget.productId != null) {
        await _produitRepo.updateProduct(
          widget.productId!,
          nom: _nomController.text.trim(),
          typeProduit: _selectedType.name,
          dlcJours: dlcJours,
          dlcSurgelationJours: dlcSurgelation,
          ingredients: _ingredientsController.text.trim().isEmpty
              ? null
              : _ingredientsController.text.trim(),
          quantite: _quantiteController.text.trim().isEmpty
              ? null
              : _quantiteController.text.trim(),
          origineViande: _origineViandeController.text.trim().isEmpty
              ? null
              : _origineViandeController.text.trim(),
          allergenes: _allergenesController.text.trim().isEmpty
              ? null
              : _allergenesController.text.trim(),
        );
        if (_selectedType == TypeProduit.recu && _selectedSupplierId != null) {
          try {
            await _supplierProductRepo.linkProductToSupplier(
              supplierId: _selectedSupplierId!,
              productId: widget.productId!,
            );
          } catch (e) {
            debugPrint('[ProductForm] Liaison fournisseur (édition): $e');
          }
        }
      } else {
        final productData = await _produitRepo.createProduct(
          nom: _nomController.text.trim(),
          typeProduit: _selectedType.name,
          dlcJours: dlcJours,
          dateFabrication: DateTime.now(),
          surgelagable: false,
          dlcSurgelationJours: dlcSurgelation,
          ingredients: _ingredientsController.text.trim().isEmpty
              ? null
              : _ingredientsController.text.trim(),
          quantite: _quantiteController.text.trim().isEmpty
              ? null
              : _quantiteController.text.trim(),
          origineViande: _origineViandeController.text.trim().isEmpty
              ? null
              : _origineViandeController.text.trim(),
          allergenes: _allergenesController.text.trim().isEmpty
              ? null
              : _allergenesController.text.trim(),
        );

        // Link product to supplier if type is "reçu" and supplier is selected
        if (_selectedType == TypeProduit.recu && _selectedSupplierId != null) {
          try {
            debugPrint(
              '[ProductForm] Linking product ${productData['id']} to supplier $_selectedSupplierId',
            );
            await _supplierProductRepo.linkProductToSupplier(
              supplierId: _selectedSupplierId!,
              productId: productData['id'] as String,
            );
            debugPrint(
              '[ProductForm] ✅ Successfully linked product to supplier',
            );
          } catch (e) {
            debugPrint('[ProductForm] ❌ Error linking to supplier: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Produit créé mais erreur lors de la liaison au fournisseur: $e',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            // Don't fail the creation if linking fails, but show warning
          }
        } else {
          debugPrint(
            '[ProductForm] ⚠️ Product type is ${_selectedType.name}, supplier is $_selectedSupplierId - skipping link',
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Produit modifié' : 'Produit créé'),
          backgroundColor: AppTheme.statusOk,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        // Produit enregistré : aller à la liste (pas au menu)
        context.go('/products');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (context.canPop()) {
              context.pop();
            } else {
              await NavigationHelpers.goHaccpHub(context);
            }
          },
        ),
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

                  // Type de produit : menu déroulant (liste scrollable, compact)
                  DropdownButtonFormField<TypeProduit>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type de produit *',
                      prefixIcon: Icon(Icons.layers),
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    menuMaxHeight: 320,
                    items: TypeProduit.values.map((type) {
                      final label = type == TypeProduit.recu
                          ? 'Produit reçu'
                          : type == TypeProduit.fini
                          ? 'Produit fini'
                          : type == TypeProduit.prepare
                          ? 'Produit préparé'
                          : type == TypeProduit.ouverture
                          ? 'Ouverture'
                          : 'Décongélation';
                      return DropdownMenuItem<TypeProduit>(
                        value: type,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (type) {
                      if (type == null) return;
                      setState(() {
                        _selectedType = type;
                        _dlcJoursController.text =
                            type.dlcParDefaut.toString();
                        if (type != TypeProduit.recu) {
                          _selectedSupplierId = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedType == TypeProduit.recu
                        ? 'Produit reçu d\'un fournisseur'
                        : _selectedType == TypeProduit.fini
                        ? 'Produit vendu directement aux clients'
                        : _selectedType == TypeProduit.prepare
                        ? 'Produit intermédiaire (farce, etc.) pour créer d\'autres produits'
                        : _selectedType == TypeProduit.ouverture
                        ? 'Produit ouvert (bouteille de lait, conserve, etc.)'
                        : 'Produit décongelé pour utilisation',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _selectedType.dlcDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Supplier selection (only for "reçu" products)
                  if (_selectedType == TypeProduit.recu) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'Fournisseur *',
                        prefixIcon: Icon(Icons.local_shipping),
                        helperText:
                            'Obligatoire pour un produit issu d\'un fournisseur',
                      ),
                      items: _suppliers.map((supplier) {
                        return DropdownMenuItem(
                          value: supplier.id,
                          child: Text(supplier.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplierId = value;
                        });
                      },
                      validator: (value) {
                        if (_selectedType == TypeProduit.recu &&
                            (value == null || value.isEmpty)) {
                          return 'Sélectionnez un fournisseur';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _dlcJoursController,
                    decoration: const InputDecoration(
                      labelText: 'DLC en jours (optionnel)',
                      prefixIcon: Icon(Icons.calendar_today),
                      helperText: 'Nombre de jours après fabrication',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [IntegerInputFormatter(maxValue: 365)],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dlcSurgelationController,
                    decoration: const InputDecoration(
                      labelText: 'DLC de surgélation (optionnel)',
                      prefixIcon: Icon(Icons.ac_unit),
                      helperText: 'Nombre de jours après surgélation',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [IntegerInputFormatter(maxValue: 365)],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ingredientsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ingrédients (optionnel)',
                      prefixIcon: Icon(Icons.restaurant),
                      helperText: 'Liste des ingrédients principaux',
                    ),
                    inputFormatters: [
                      DescriptionInputFormatter(maxLength: 200),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantiteController,
                    decoration: const InputDecoration(
                      labelText: 'Quantité par unité (optionnel)',
                      prefixIcon: Icon(Icons.numbers),
                      helperText: 'Ex: 50 pièces, 1 kg, etc.',
                    ),
                    inputFormatters: [ZplSafeTextInputFormatter()],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _origineViandeController,
                    decoration: const InputDecoration(
                      labelText: 'Origine viande (optionnel)',
                      prefixIcon: Icon(Icons.flag),
                      helperText: 'Ex: France, UE, etc.',
                    ),
                    inputFormatters: [ZplSafeTextInputFormatter()],
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
                      'Les produits inactifs ne seront pas disponibles dans les listes',
                    ),
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
