import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/temperature_repository.dart';
import '../../../../data/repositories/appareil_repository.dart';
import '../../../../data/repositories/audit_log_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../data/models/appareil.dart';
import '../../../../data/models/temperature.dart';
import '../../../../data/services/storage_service.dart';
import '../../../../shared/widgets/section_card.dart';

/// Form page for temperature entry
class TemperatureFormPage extends StatefulWidget {
  final String? temperatureId;
  
  const TemperatureFormPage({super.key, this.temperatureId});

  @override
  State<TemperatureFormPage> createState() => _TemperatureFormPageState();
}

class _TemperatureFormPageState extends State<TemperatureFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _temperatureController = TextEditingController();
  final _remarqueController = TextEditingController();
  
  final _temperatureRepo = TemperatureRepository();
  final _appareilRepo = AppareilRepository();
  final _auditLogRepo = AuditLogRepository();
  final _orgRepo = OrganizationRepository();
  final _storageService = StorageService();
  
  List<Appareil> _appareils = [];
  String? _selectedAppareilId;
  DateTime _selectedDate = DateTime.now();
  String? _photoPath;
  bool _isLoading = false;
  bool _isLoadingAppareils = true;

  @override
  void initState() {
    super.initState();
    _loadAppareils();
    if (widget.temperatureId != null) {
      _loadTemperature();
    }
  }

  Future<void> _loadTemperature() async {
    try {
      final temp = await _temperatureRepo.getById(widget.temperatureId!);
      if (temp != null && mounted) {
        setState(() {
          _temperatureController.text = temp.temperature.toString();
          _remarqueController.text = temp.remarque ?? '';
          _selectedAppareilId = temp.appareilId;
          _selectedDate = temp.createdAt;
          // Note: photo cannot be loaded from URL, user would need to re-upload
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _remarqueController.dispose();
    super.dispose();
  }

  Future<void> _loadAppareils() async {
    try {
      final appareils = await _appareilRepo.getAll();
      if (mounted) {
        setState(() {
          _appareils = appareils;
          _isLoadingAppareils = false;
          if (appareils.isNotEmpty && _selectedAppareilId == null) {
            _selectedAppareilId = appareils.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAppareils = false;
        });
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAppareilId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un appareil')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final temperature = double.parse(_temperatureController.text);
      
      // Upload photo to Supabase Storage if _photoPath is not null
      String? photoUrl;
      if (_photoPath != null) {
        try {
          debugPrint('[TemperatureForm] Uploading photo to Supabase Storage...');
          final photoFile = File(_photoPath!);
          photoUrl = await _storageService.uploadPhoto(
            photoFile,
            fileName: 'temperature_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          debugPrint('[TemperatureForm] ✅ Photo uploaded successfully: $photoUrl');
        } catch (e) {
          debugPrint('[TemperatureForm] ❌ Error uploading photo: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors de l\'upload de la photo: $e'),
                backgroundColor: Colors.orange,
              ),
            );
            // Continue without photo - don't block the form submission
          }
        }
      }

      // Get appareil name for legacy column
      final selectedAppareil = _appareils.firstWhere((a) => a.id == _selectedAppareilId!);
      
      Temperature? result;
      if (widget.temperatureId != null) {
        // Update existing temperature
        result = await _temperatureRepo.update(
          id: widget.temperatureId!,
          appareilId: _selectedAppareilId,
          temperature: temperature,
          remarque: _remarqueController.text.isEmpty ? null : _remarqueController.text,
          photoUrl: photoUrl,
        );
      } else {
        // Create new temperature
        result = await _temperatureRepo.create(
          appareilId: _selectedAppareilId!,
          temperature: temperature,
          remarque: _remarqueController.text.isEmpty 
              ? null 
              : _remarqueController.text,
          photoUrl: photoUrl,
          appareilNom: selectedAppareil.nom, // Pass appareil name for legacy column
        );
      }
      
      final createdTemp = result;

      // Create audit log entry
      try {
        final orgId = await _orgRepo.getOrCreateOrganization();
        final appareil = _appareils.firstWhere((a) => a.id == _selectedAppareilId!);
        await _auditLogRepo.create(
          organizationId: orgId,
          operationType: 'temperature',
          operationId: createdTemp.id,
          action: widget.temperatureId != null ? 'update' : 'create',
          description: widget.temperatureId != null 
              ? 'Température modifiée: ${temperature}°C pour ${appareil.nom}'
              : 'Température ${temperature}°C pour ${appareil.nom}',
          metadata: {
            'appareil_id': _selectedAppareilId!,
            'appareil_nom': appareil.nom,
            'temperature': temperature,
            'remarque': _remarqueController.text.isEmpty ? null : _remarqueController.text,
          },
        );
      } catch (e) {
        debugPrint('[TemperatureForm] Error creating audit log: $e');
        // Don't fail the temperature save if audit log fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Température enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final errorMessage = e.toString().contains('PostgrestException')
            ? 'Erreur lors de l\'enregistrement. Vérifiez vos permissions.'
            : 'Erreur: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(context).matchedLocation.startsWith('/admin');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.temperatureId != null 
            ? 'Modifier la température' 
            : 'Nouveau relevé de température'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoadingAppareils
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Appareil selection
                  DropdownButtonFormField<String>(
                    value: _selectedAppareilId,
                    decoration: const InputDecoration(
                      labelText: 'Appareil *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.devices),
                    ),
                    items: _appareils.map((appareil) {
                      return DropdownMenuItem(
                        value: appareil.id,
                        child: Text(appareil.nom),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAppareilId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez sélectionner un appareil';
                      }
                      return null;
                    },
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Date
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      ),
                    ),
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
                  const SizedBox(height: 16),
                  
                  // Photo
                  if (_photoPath != null)
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Photo capturée'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showPhotoDialog(context, _photoPath!),
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_photoPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.broken_image, size: 64),
                                    );
                                  },
                                ),
                              ),
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
                      label: const Text('Prendre une photo'),
                    ),
                  const SizedBox(height: 24),
                  
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
                            'Enregistrer',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showPhotoDialog(BuildContext context, String photoPath) {
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
                child: Image.file(
                  File(photoPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.black87,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, size: 64, color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Impossible de charger l\'image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
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
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
