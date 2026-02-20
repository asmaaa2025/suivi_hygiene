import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../data/models/supplier.dart';

/// Supplier form page (create/edit)
class SupplierFormPage extends StatefulWidget {
  final String? supplierId;

  const SupplierFormPage({super.key, this.supplierId});

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  final _supplierRepo = SupplierRepository();
  bool _isLoading = false;
  bool _isLoadingData = true;
  Supplier? _supplier;
  bool _isOccasional = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) {
      _loadSupplier();
    } else {
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplier() async {
    try {
      final supplier = await _supplierRepo.getById(widget.supplierId!);
      if (supplier != null && mounted) {
        setState(() {
          _supplier = supplier;
          _nameController.text = supplier.name;
          _contactController.text = supplier.contactInfo ?? '';
          _isOccasional = supplier.isOccasional;
          _isLoadingData = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingData = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fournisseur introuvable')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.supplierId != null) {
        // Update
        await _supplierRepo.update(
          id: widget.supplierId!,
          name: _nameController.text,
          contactInfo: _contactController.text.isEmpty
              ? null
              : _contactController.text,
          isOccasional: _isOccasional,
        );
      } else {
        // Create (organization will be created automatically if needed)
        try {
          final orgRepo = OrganizationRepository();
          final orgId = await orgRepo.getOrCreateOrganization();

          debugPrint('[SupplierForm] Using organization ID: $orgId');

          await _supplierRepo.create(
            organizationId: orgId,
            name: _nameController.text,
            contactInfo: _contactController.text.isEmpty
                ? null
                : _contactController.text,
            isOccasional: _isOccasional,
          );
        } catch (e) {
          debugPrint(
            '[SupplierForm] ❌ Error creating organization or supplier: $e',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erreur: Impossible de créer le fournisseur. Vérifiez que l\'organisation existe dans la base de données.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          rethrow;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.supplierId != null
                  ? 'Fournisseur modifié'
                  : 'Fournisseur créé',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.supplierId != null
              ? 'Modifier le fournisseur'
              : 'Nouveau fournisseur',
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du fournisseur *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Informations de contact',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.contact_phone),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Fournisseur occasionnel'),
                    subtitle: const Text(
                      'Cocher si ce fournisseur est utilisé occasionnellement',
                    ),
                    value: _isOccasional,
                    onChanged: (value) {
                      setState(() {
                        _isOccasional = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
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
                            'Enregistrer',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
