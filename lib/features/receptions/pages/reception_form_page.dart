import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/reception_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/non_conformity_repository.dart';
import '../../../../data/repositories/audit_log_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../data/repositories/supplier_product_repository.dart';
import '../../../../data/models/supplier.dart';
import '../../../../data/models/produit.dart';
import '../../../../data/models/non_conformity.dart';
import '../../../../shared/widgets/section_card.dart';

/// Enhanced reception form with fixed 10:00 time, non-conformity check
class ReceptionFormPage extends StatefulWidget {
  const ReceptionFormPage({super.key});

  @override
  State<ReceptionFormPage> createState() => _ReceptionFormPageState();
}

class _ReceptionFormPageState extends State<ReceptionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _lotController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _remarqueController = TextEditingController();
  final _supplierNameController = TextEditingController(); // For quick-add
  
  final _receptionRepo = ReceptionRepository();
  final _supplierRepo = SupplierRepository();
  final _produitRepo = ProduitRepository();
  final _nonConformityRepo = NonConformityRepository();
  final _auditLogRepo = AuditLogRepository();
  final _supplierProductRepo = SupplierProductRepository();
  
  List<Supplier> _suppliers = [];
  List<Produit> _products = [];
  String? _selectedSupplierId;
  String? _selectedProductId;
  DateTime? _selectedDluo;
  TimeOfDay _receptionTime = const TimeOfDay(hour: 10, minute: 0); // Default 10:00
  double? _temperature;
  String? _photoPath;
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  // Conformity checklist
  bool _temperatureChecked = false;
  bool _packagingChecked = false;
  bool _labelChecked = false;
  bool _dluoChecked = false;
  bool _allConformityChecked = false;
  
  // Non-conformity state
  bool _showNonConformity = false;
  bool _temperatureNonCompliant = false;
  bool _packagingOpened = false;
  bool _packagingWet = false;
  bool _labelMissing = false;
  final _declarationController = TextEditingController();
  List<String> _nonConformityPhotos = [];
  bool _showQuickAddSupplier = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _lotController.dispose();
    _temperatureController.dispose();
    _remarqueController.dispose();
    _supplierNameController.dispose();
    _declarationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _supplierRepo.getAll(includeOccasional: null),
        _produitRepo.getAll(),
      ]);

      if (mounted) {
        setState(() {
          _suppliers = results[0] as List<Supplier>;
          _products = results[1] as List<Produit>;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _quickAddSupplier() async {
    final name = _supplierNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un nom de fournisseur')),
      );
      return;
    }

    try {
      // Get or create organization automatically
      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final supplier = await _supplierRepo.create(
        organizationId: orgId,
        name: name,
        isOccasional: true,
      );

      if (mounted) {
        // Reload suppliers from database to ensure consistency
        await _loadData();
        setState(() {
          _selectedSupplierId = supplier.id;
          _showQuickAddSupplier = false;
          _supplierNameController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fournisseur ajouté et sélectionné')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          _photoPath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la capture: $e')),
        );
      }
    }
  }

  Future<void> _pickNonConformityImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          _nonConformityPhotos.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la capture: $e')),
        );
      }
    }
  }

  Future<void> _selectDluo() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDluo ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDluo = picked;
      });
    }
  }

  Future<void> _selectReceptionTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _receptionTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _receptionTime = picked;
      });
    }
  }

  void _updateConformityStatus() {
    setState(() {
      _allConformityChecked = _temperatureChecked && 
                              _packagingChecked && 
                              _labelChecked && 
                              _dluoChecked;
    });
  }

  Future<void> _loadSupplierProducts(String supplierId) async {
    try {
      // Get products linked to this supplier (only "reçu" type products)
      final supplierProducts = await _supplierProductRepo.getProductsBySupplier(supplierId);
      
      // Filter to only show "reçu" type products
      final recuProducts = supplierProducts.where((p) => 
        p.typeProduit?.toLowerCase() == 'reçu' || 
        p.typeProduit?.toLowerCase() == 'recu'
      ).toList();
      
      if (mounted) {
        setState(() {
          // Update products list to show only supplier's "reçu" products
          _products = recuProducts;
          _selectedProductId = null; // Reset selection
          
          // If only one product, auto-select it
          if (recuProducts.length == 1) {
            _selectedProductId = recuProducts.first.id;
            _prefillProductFields(recuProducts.first, supplierId);
          }
        });
      }
    } catch (e) {
      debugPrint('[ReceptionForm] Error loading supplier products: $e');
    }
  }

  Future<void> _prefillProductFields(Produit product, String supplierId) async {
    try {
      // Get supplier-product details (default lot, DLUO days)
      final details = await _supplierProductRepo.getSupplierProductDetails(
        supplierId: supplierId,
        productId: product.id,
      );
      
      if (mounted && details != null) {
        setState(() {
          // Pre-fill lot number if available
          if (details['default_lot_number'] != null && _lotController.text.isEmpty) {
            _lotController.text = details['default_lot_number'] as String;
          }
          
          // Pre-fill DLUO if available (calculate from default_dluo_days)
          if (details['default_dluo_days'] != null && _selectedDluo == null) {
            final dluoDays = details['default_dluo_days'] as int;
            _selectedDluo = DateTime.now().add(Duration(days: dluoDays));
          }
        });
      }
    } catch (e) {
      debugPrint('[ReceptionForm] Error pre-filling fields: $e');
    }
  }

  void _checkNonConformity() {
    final temp = double.tryParse(_temperatureController.text);
    final hasRefusal = 
        (temp != null && (temp > 7 || temp < -18)) || // Temperature criteria
        _packagingOpened ||
        _packagingWet ||
        _labelMissing;
    
    setState(() {
      _showNonConformity = hasRefusal;
      if (temp != null) {
        _temperatureNonCompliant = temp > 7 || temp < -18;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un fournisseur')),
      );
      return;
    }
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }
    
    // Check if all conformity items are checked
    if (!_allConformityChecked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checklist incomplète'),
          content: const Text(
            'Tous les critères de conformité ne sont pas validés. '
            'Voulez-vous continuer quand même ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final temperature = double.parse(_temperatureController.text);
      
      // TODO: Upload photo to Supabase Storage if _photoPath is not null
      String? photoUrl;
      if (_photoPath != null) {
        photoUrl = _photoPath; // In production, upload to Supabase Storage
      }

      // Create reception with custom time
      // Mark as non-conformant if checklist is incomplete
      final isNonConformant = !_allConformityChecked;
      
      final reception = await _receptionRepo.create(
        produitId: _selectedProductId!,
        supplierId: _selectedSupplierId!,
        lot: _lotController.text.isEmpty ? null : _lotController.text,
        dluo: _selectedDluo,
        temperature: temperature,
        remarque: _remarqueController.text.isEmpty 
            ? null 
            : _remarqueController.text,
        photoUrl: photoUrl,
        receptionHour: _receptionTime.hour,
        receptionMinute: _receptionTime.minute,
        isNonConformant: isNonConformant,
      );

      // Create non-conformity if needed
      String? nonConformityId;
      if (_showNonConformity && 
          (_temperatureNonCompliant || _packagingOpened || 
           _packagingWet || _labelMissing)) {
        final nonConformity = await _nonConformityRepo.create(
          receptionId: reception.id,
          temperatureNonCompliant: _temperatureNonCompliant,
          packagingOpened: _packagingOpened,
          packagingWet: _packagingWet,
          labelMissing: _labelMissing,
          declarationText: _declarationController.text.isEmpty
              ? null
              : _declarationController.text,
          photoUrls: _nonConformityPhotos,
        );
        nonConformityId = nonConformity.id;
        
        // Update reception with non-conformity link
        await _receptionRepo.update(
          id: reception.id,
          remarque: _remarqueController.text,
        );
      }

      // Create audit log entry
      try {
        final orgRepo = OrganizationRepository();
        final orgId = await orgRepo.getOrCreateOrganization();
        
        await _auditLogRepo.create(
          organizationId: orgId,
          operationType: 'reception',
          operationId: reception.id,
          action: 'create',
          description: 'Réception de ${_products.firstWhere((p) => p.id == _selectedProductId).nom}',
          metadata: {
            'supplier_id': _selectedSupplierId,
            'product_id': _selectedProductId,
            'temperature': temperature,
            'has_non_conformity': nonConformityId != null,
            'is_non_conformant': isNonConformant, // Flag for incomplete checklist
            'checklist_complete': _allConformityChecked,
          },
        );
      } catch (e) {
        debugPrint('[ReceptionForm] Error creating audit log: $e');
        // Don't fail the reception if audit log fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nonConformityId != null
                  ? 'Réception enregistrée avec non-conformité'
                  : 'Réception enregistrée avec succès',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle réception'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Fixed reception time info
                  // Reception time selector
                  InkWell(
                    onTap: _selectReceptionTime,
                    child: SectionCard(
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: AppTheme.statusInfo),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Heure de réception',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '${_receptionTime.hour.toString().padLeft(2, '0')}:${_receptionTime.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.statusInfo,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit, color: AppTheme.primaryBlue, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conformity checklist
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.checklist, color: AppTheme.statusOk),
                            const SizedBox(width: 8),
                            Text(
                              'Checklist de conformité',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          title: const Text('Température conforme'),
                          subtitle: const Text('Température entre -18°C et +7°C'),
                          value: _temperatureChecked,
                          onChanged: (value) {
                            setState(() {
                              _temperatureChecked = value ?? false;
                              _updateConformityStatus();
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Emballage conforme'),
                          subtitle: const Text('Emballage intact, non ouvert, non mouillé'),
                          value: _packagingChecked,
                          onChanged: (value) {
                            setState(() {
                              _packagingChecked = value ?? false;
                              _updateConformityStatus();
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Étiquette présente'),
                          subtitle: const Text('Étiquette lisible et complète'),
                          value: _labelChecked,
                          onChanged: (value) {
                            setState(() {
                              _labelChecked = value ?? false;
                              _updateConformityStatus();
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('DLUO vérifiée'),
                          subtitle: const Text('Date limite d\'utilisation optimale vérifiée'),
                          value: _dluoChecked,
                          onChanged: (value) {
                            setState(() {
                              _dluoChecked = value ?? false;
                              _updateConformityStatus();
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),
                        if (_allConformityChecked)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.statusOk.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.statusOk),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.statusOk),
                                const SizedBox(width: 8),
                                Text(
                                  'Tous les critères de conformité sont validés',
                                  style: TextStyle(
                                    color: AppTheme.statusOk,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Supplier selection
                  DropdownButtonFormField<String>(
                    value: _selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Fournisseur *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping),
                    ),
                    items: _suppliers.map((supplier) {
                      return DropdownMenuItem(
                        value: supplier.id,
                        child: Row(
                          children: [
                            Text(supplier.name),
                            if (supplier.isOccasional) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(Occasionnel)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setState(() {
                        _selectedSupplierId = value;
                        _selectedProductId = null; // Reset product when supplier changes
                      });
                      
                      // Load products for this supplier and pre-fill fields
                      if (value != null) {
                        await _loadSupplierProducts(value);
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez sélectionner un fournisseur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Quick add supplier button
                  if (!_showQuickAddSupplier)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showQuickAddSupplier = true;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un fournisseur occasionnel'),
                    )
                  else
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _supplierNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom du fournisseur',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showQuickAddSupplier = false;
                                    _supplierNameController.clear();
                                  });
                                },
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: _quickAddSupplier,
                                child: const Text('Ajouter'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Product selection
                  DropdownButtonFormField<String>(
                    value: _selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Produit *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_basket),
                    ),
                    items: _products.map((product) {
                      return DropdownMenuItem(
                        value: product.id,
                        child: Text(product.nom),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProductId = value;
                      });
                      
                      // Pre-fill fields when product is selected
                      if (value != null && _selectedSupplierId != null) {
                        final product = _products.firstWhere((p) => p.id == value);
                        _prefillProductFields(product, _selectedSupplierId!);
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez sélectionner un produit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Lot number
                  TextFormField(
                    controller: _lotController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de lot',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DLUO
                  InkWell(
                    onTap: _selectDluo,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'DLUO (Date limite d\'utilisation optimale)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _selectedDluo != null
                            ? '${_selectedDluo!.day}/${_selectedDluo!.month}/${_selectedDluo!.year}'
                            : 'Sélectionner une date',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Temperature
                  TextFormField(
                    controller: _temperatureController,
                    decoration: const InputDecoration(
                      labelText: 'Température (°C) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.thermostat),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir une température';
                      }
                      final temp = double.tryParse(value);
                      if (temp == null) {
                        return 'Veuillez saisir un nombre valide';
                      }
                      return null;
                    },
                    onChanged: (_) => _checkNonConformity(),
                  ),
                  const SizedBox(height: 16),

                  // Photo of label
                  if (_photoPath != null)
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Photo de l\'étiquette'),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.image, size: 100),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _photoPath = null;
                              });
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Supprimer la photo'),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Prendre une photo de l\'étiquette'),
                    ),
                  const SizedBox(height: 16),

                  // Remarque
                  TextFormField(
                    controller: _remarqueController,
                    decoration: const InputDecoration(
                      labelText: 'Remarque',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Non-conformity section (shown if criteria met)
                  if (_showNonConformity) ...[
                    SectionCard(
                      color: AppTheme.statusCriticalBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: AppTheme.statusCritical),
                              const SizedBox(width: 8),
                              Text(
                                'Non-conformité détectée',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.statusCritical,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Critères de refus:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            title: const Text('Température non conforme (>7°C ou <-18°C)'),
                            value: _temperatureNonCompliant,
                            onChanged: (value) {
                              setState(() {
                                _temperatureNonCompliant = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title: const Text('Emballage ouvert'),
                            value: _packagingOpened,
                            onChanged: (value) {
                              setState(() {
                                _packagingOpened = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title: const Text('Emballage mouillé'),
                            value: _packagingWet,
                            onChanged: (value) {
                              setState(() {
                                _packagingWet = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title: const Text('Étiquette manquante'),
                            value: _labelMissing,
                            onChanged: (value) {
                              setState(() {
                                _labelMissing = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _declarationController,
                            decoration: const InputDecoration(
                              labelText: 'Déclaration de non-conformité',
                              border: OutlineInputBorder(),
                              hintText: 'Décrivez la non-conformité...',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          if (_nonConformityPhotos.isNotEmpty) ...[
                            Text(
                              'Photos de non-conformité:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _nonConformityPhotos.map((path) {
                                return Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.image),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _nonConformityPhotos.remove(path);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: _pickNonConformityImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Ajouter une photo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Enregistrer la réception',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
