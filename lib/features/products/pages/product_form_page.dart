import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../repositories/products_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/supplier_product_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../data/models/supplier.dart';
import '../../../../models/produit.dart';

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
    }
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
    _categorieController.dispose();
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

      setState(() {
        if (_nomController.text.isEmpty) {
          _nomController.text = produitData['nom'] ?? '';
        }
        // Parse type_produit to TypeProduit enum
        final typeStr = produitData['type_produit'] as String?;
        if (typeStr != null && typeStr.isNotEmpty) {
          // Map database string to TypeProduit enum
          switch (typeStr.toLowerCase()) {
            case 'reçu':
            case 'recu':
              _selectedType = TypeProduit.recu;
              break;
            case 'fini':
              _selectedType = TypeProduit.fini;
              break;
            case 'prepare':
            case 'préparé':
            case 'preparé':
            case 'transformé':
            case 'transforme':
              _selectedType = TypeProduit.prepare;
              break;
            case 'ouverture':
            case 'ouvert':
              _selectedType = TypeProduit.ouverture;
              break;
            case 'decongelation':
            case 'décongelation':
            case 'décongelé':
            case 'decongele':
              _selectedType = TypeProduit.decongelation;
              break;
            default:
              _selectedType = TypeProduit.fini;
          }
        }
        if (_allergenesController.text.isEmpty) {
          _allergenesController.text = produitData['allergenes'] ?? '';
        }
        _actif = produitData['actif'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditMode && widget.productId != null) {
        await _produitRepo.updateProduct(
          widget.productId!,
          nom: _nomController.text.trim(),
          typeProduit: _selectedType.name,
          allergenes: _allergenesController.text.trim().isEmpty
              ? null
              : _allergenesController.text.trim(),
        );
      } else {
        final productData = await _produitRepo.createProduct(
          nom: _nomController.text.trim(),
          typeProduit: _selectedType.name,
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Produit modifié' : 'Produit créé'),
            backgroundColor: AppTheme.statusOk,
          ),
        );
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

                  // Sélecteur de type de produit avec cartes
                  Text(
                    'Type de produit *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
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
                  SizedBox(height: 16),
                  SizedBox(
                    height: (TypeProduit.values.length / 2).ceil() * 90.0,
                    child: GridView.count(
                      shrinkWrap: false,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      children: TypeProduit.values.map((type) {
                        final isSelected = _selectedType == type;
                        final color = type == TypeProduit.recu
                            ? Colors.purple
                            : type == TypeProduit.fini
                            ? Colors.green
                            : type == TypeProduit.prepare
                            ? Colors.orange
                            : type == TypeProduit.ouverture
                            ? Colors.red
                            : Colors.blue;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedType = type;
                              // Clear supplier if not "reçu"
                              if (type != TypeProduit.recu) {
                                _selectedSupplierId = null;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          splashColor: color.shade200.withOpacity(0.3),
                          highlightColor: color.shade100.withOpacity(0.2),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? color.shade100 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? color.shade600
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.shade200.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.shade200
                                          : color.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      type == TypeProduit.recu
                                          ? Icons.local_shipping
                                          : type == TypeProduit.fini
                                          ? Icons.shopping_cart
                                          : type == TypeProduit.prepare
                                          ? Icons.build
                                          : type == TypeProduit.ouverture
                                          ? Icons.open_in_new
                                          : Icons.ac_unit,
                                      color: color.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          type == TypeProduit.recu
                                              ? 'Produit reçu'
                                              : type == TypeProduit.fini
                                              ? 'Produit fini'
                                              : type == TypeProduit.prepare
                                              ? 'Produit préparé'
                                              : type == TypeProduit.ouverture
                                              ? 'Ouverture'
                                              : 'Décongélation',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? color.shade800
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          type.dlcDescription,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected
                                                ? color.shade600
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: color.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Supplier selection (only for "reçu" products)
                  if (_selectedType == TypeProduit.recu)
                    DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'Fournisseur (optionnel)',
                        prefixIcon: Icon(Icons.local_shipping),
                        helperText:
                            'Sélectionnez un fournisseur ou laissez vide',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Aucun'),
                        ),
                        ..._suppliers.map((supplier) {
                          return DropdownMenuItem(
                            value: supplier.id,
                            child: Text(supplier.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplierId = value;
                        });
                      },
                    ),
                  if (_selectedType == TypeProduit.recu)
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
