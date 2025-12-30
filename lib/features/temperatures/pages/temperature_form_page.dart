import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/temperature_repository.dart';
import '../../../../data/repositories/appareil_repository.dart';
import '../../../../data/models/appareil.dart';
import '../../../../shared/widgets/section_card.dart';

/// Form page for temperature entry
class TemperatureFormPage extends StatefulWidget {
  const TemperatureFormPage({super.key});

  @override
  State<TemperatureFormPage> createState() => _TemperatureFormPageState();
}

class _TemperatureFormPageState extends State<TemperatureFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _temperatureController = TextEditingController();
  final _remarqueController = TextEditingController();
  
  final _temperatureRepo = TemperatureRepository();
  final _appareilRepo = AppareilRepository();
  
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
      
      // TODO: Upload photo to Supabase Storage if _photoPath is not null
      String? photoUrl;
      if (_photoPath != null) {
        // For now, we'll just store the path
        // In production, upload to Supabase Storage
        photoUrl = _photoPath;
      }

      await _temperatureRepo.create(
        appareilId: _selectedAppareilId!,
        temperature: temperature,
        remarque: _remarqueController.text.isEmpty 
            ? null 
            : _remarqueController.text,
        photoUrl: photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Température enregistrée avec succès')),
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
        title: const Text('Nouveau relevé de température'),
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
                          // Note: For now, we just show that a photo was taken
                          // In production, upload to Supabase Storage and show preview
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
}
