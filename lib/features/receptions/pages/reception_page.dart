import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../repositories/receptions_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../services/cache_service.dart';
import '../../../../exceptions/app_exceptions.dart';

class ReceptionPage extends StatefulWidget {
  const ReceptionPage({super.key});

  @override
  State<ReceptionPage> createState() => _ReceptionPageState();
}

class _ReceptionPageState extends State<ReceptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _receptionsRepo = ReceptionsRepository();
  final _networkService = NetworkService();
  final _produitController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _remarqueController = TextEditingController();
  final _newFournisseurController = TextEditingController();
  String? _fournisseur;
  String _statut = 'Conforme';
  List<String> _fournisseurs = [];
  List<Map<String, dynamic>> _receptions = [];
  bool _isOnline = true;
  bool _isLoading = false;

  // Variables pour la gestion des photos
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadFournisseurs();
    _loadReceptions();
    _networkService.connectivityStream.listen((_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    final isOnline = await _networkService.hasConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _loadFournisseurs() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await _receptionsRepo.getSuppliers();
      if (mounted) {
        setState(() {
          _fournisseurs = suppliers.map((s) => s['nom'] as String).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReceptions() async {
    setState(() => _isLoading = true);
    try {
      // Try cache first
      final cached = CacheService().get('receptions_all');
      if (cached != null) {
        setState(() {
          _receptions = List<Map<String, dynamic>>.from(cached);
        });
      }

      // Load from Supabase
      final receptions = await _receptionsRepo.getAll();
      if (mounted) {
        setState(() {
          _receptions = receptions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveReception() async {
    if (_formKey.currentState!.validate()) {
      if (_fournisseur == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veuillez sélectionner un fournisseur'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final quantite = double.tryParse(_quantiteController.text);
      if (quantite == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veuillez entrer une quantité valide'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Sauvegarder la photo si elle existe
      String? photoPath;
      if (_photoPath != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final receptionsDir = Directory('${appDir.path}/receptions');
          if (!await receptionsDir.exists()) {
            await receptionsDir.create(recursive: true);
          }
          final fileName =
              'reception_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedFile = await File(
            _photoPath!,
          ).copy('${receptionsDir.path}/$fileName');
          photoPath = savedFile.path;
        } catch (e) {
          // On continue même si la photo ne peut pas être sauvegardée
          photoPath = null;
        }
      }

      if (!_isOnline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network required')));
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _receptionsRepo.createReceptionRecord(
          fournisseur: _fournisseur!,
          produit: _produitController.text,
          quantite: quantite,
          statut: _statut,
          remarque: _remarqueController.text.isEmpty
              ? null
              : _remarqueController.text,
          photoPath: photoPath,
        );

        _produitController.clear();
        _quantiteController.clear();
        _remarqueController.clear();
        setState(() {
          _fournisseur = null;
          _statut = 'Conforme';
          _photoPath = null;
        });
        await _loadReceptions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Réception enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addFournisseur() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau fournisseur'),
        content: TextField(
          controller: _newFournisseurController,
          decoration: InputDecoration(
            labelText: 'Nom du fournisseur',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_newFournisseurController.text.trim().isNotEmpty) {
                Navigator.pop(context, _newFournisseurController.text.trim());
              }
            },
            child: Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        if (!_isOnline) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Network required')));
          return;
        }

        await _receptionsRepo.createSupplier(result);
        await _loadFournisseurs();
        setState(() {
          _fournisseur =
              result; // Sélectionner automatiquement le nouveau fournisseur
        });
        _newFournisseurController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fournisseur "$result" ajouté et sélectionné'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: ${e is AppException ? e.message : e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        print('❌ Erreur lors de l\'ajout du fournisseur: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ajout du fournisseur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFournisseur(String nom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirmation',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Supprimer le fournisseur "$nom" ?\n\nCette action supprimera également toutes les réceptions associées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Supprimer',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!_isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network required')));
      return;
    }

    try {
      // Find supplier ID
      final suppliers = await _receptionsRepo.getSuppliers();
      final supplier = suppliers.firstWhere(
        (s) => s['nom'] == nom,
        orElse: () => <String, dynamic>{},
      );
      if (supplier.isNotEmpty) {
        await _receptionsRepo.client
            .from('fournisseurs')
            .delete()
            .eq('id', supplier['id']);
      }
      await _loadFournisseurs();
      await _loadReceptions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fournisseur "$nom" supprimé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Méthodes pour la gestion des photos
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        final File imageFile = File(photo.path);
        setState(() {
          _selectedImage = imageFile;
          _photoPath = photo.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la prise de photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        setState(() {
          _selectedImage = imageFile;
          _photoPath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
      _photoPath = null;
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoDialog(String photoPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Photo de réception',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(photoPath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.error,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Fermer',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteReception(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirmation',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text('Supprimer cette réception ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Supprimer',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!_isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network required')));
      return;
    }

    try {
      await _receptionsRepo.delete(id);
      await _loadReceptions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réception supprimée'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToCsv() async {
    if (_receptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aucune réception à exporter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Créer les en-têtes du CSV
      List<List<dynamic>> csvData = [
        [
          'Date',
          'Fournisseur',
          'Produit',
          'Quantité',
          'Statut',
          'Remarque',
          'Photo',
        ],
      ];

      // Ajouter les données
      for (var reception in _receptions) {
        final date = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(DateTime.parse(reception['date']));
        final statut = reception['conforme'] == 1 ? 'Conforme' : 'Non OK';
        final photo =
            reception['photo_path'] != null &&
                reception['photo_path'].toString().isNotEmpty
            ? 'Oui'
            : 'Non';

        csvData.add([
          date,
          reception['fournisseur'],
          reception['article'],
          reception['quantite'],
          statut,
          reception['remarque'] ?? '',
          photo,
        ]);
      }

      // Convertir en CSV
      String csv = const ListToCsvConverter(
        fieldDelimiter: ';',
      ).convert(csvData);

      // Créer le dossier d'export s'il n'existe pas
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Créer le fichier CSV
      final fileName =
          'receptions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${exportDir.path}/$fileName');
      await file.writeAsString(csv, encoding: utf8);

      // Afficher un message de succès avec le chemin du fichier
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export CSV réussi !',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              ),
              Text(
                'Fichier sauvegardé : $fileName',
                style: GoogleFonts.montserrat(fontSize: 12),
              ),
              Text(
                'Dossier : ${exportDir.path}',
                style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Partager',
            textColor: Colors.white,
            onPressed: () async {
              try {
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Export des réceptions',
                  text: 'Voici l\'export des réceptions au format CSV',
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors du partage: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF81C784), Color(0xFFC8E6C9)],
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Réception',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header du formulaire
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.green.shade100,
                                child: Icon(
                                  Icons.local_shipping,
                                  color: Colors.green.shade700,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Nouvelle réception',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Fournisseur
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: _fournisseur,
                                      items: _fournisseurs.map((f) {
                                        return DropdownMenuItem<String>(
                                          value: f,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  f,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red.shade400,
                                                  size: 16,
                                                ),
                                                onPressed: () =>
                                                    _deleteFournisseur(f),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 24,
                                                      minHeight: 24,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) =>
                                          setState(() => _fournisseur = val!),
                                      decoration: InputDecoration(
                                        labelText: 'Fournisseur',
                                        prefixIcon: Icon(
                                          Icons.business,
                                          color: Colors.green.shade600,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.green.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 12,
                                            ),
                                      ),
                                      menuMaxHeight: 200,
                                      isExpanded: true,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _addFournisseur,
                                      icon: const Icon(Icons.add),
                                      label: Text(
                                        'Ajouter un fournisseur',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Produit
                          TextFormField(
                            controller: _produitController,
                            style: GoogleFonts.montserrat(),
                            decoration: InputDecoration(
                              labelText: 'Produit',
                              prefixIcon: Icon(
                                Icons.inventory,
                                color: Colors.green.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.green.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un produit';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Quantité et Statut
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _quantiteController,
                                  style: GoogleFonts.montserrat(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Quantité',
                                    prefixIcon: Icon(
                                      Icons.scale,
                                      color: Colors.green.shade600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.green.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Obligatoire';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _statut,
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: 'Conforme',
                                      child: Text(
                                        'Conforme',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'Non conforme',
                                      child: Text(
                                        'Non OK',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _statut = val!),
                                  decoration: InputDecoration(
                                    labelText: 'Statut',
                                    prefixIcon: Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.green.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  menuMaxHeight: 200,
                                  isExpanded: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Remarque
                          TextFormField(
                            controller: _remarqueController,
                            style: GoogleFonts.montserrat(),
                            decoration: InputDecoration(
                              labelText: 'Remarque (optionnel)',
                              prefixIcon: Icon(
                                Icons.note,
                                color: Colors.green.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.green.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                            maxLines: 3,
                            minLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Photo
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.green.shade50,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Photo',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_selectedImage != null) ...[
                                  Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _showPhotoOptions,
                                          icon: const Icon(Icons.edit),
                                          label: Text(
                                            'Modifier',
                                            style: GoogleFonts.montserrat(),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _removePhoto,
                                          icon: const Icon(Icons.delete),
                                          label: Text(
                                            'Supprimer',
                                            style: GoogleFonts.montserrat(),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  ElevatedButton.icon(
                                    onPressed: _showPhotoOptions,
                                    icon: const Icon(Icons.add_a_photo),
                                    label: Text(
                                      'Ajouter une photo',
                                      style: GoogleFonts.montserrat(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bouton d'enregistrement
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _saveReception();
                                }
                              },
                              icon: const Icon(Icons.save),
                              label: Text(
                                'Enregistrer',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Card(
                margin: const EdgeInsets.all(16),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Header du tableau
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Historique des réceptions',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _exportToCsv,
                            icon: Icon(
                              Icons.download,
                              color: Colors.green.shade600,
                            ),
                            tooltip: 'Export CSV',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _receptions.length,
                        itemBuilder: (context, index) {
                          final r = _receptions[index];
                          final date = DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(DateTime.parse(r['date']));
                          final photoPath = r['photo_path'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
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
                                              r['article'] as String? ?? '',
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Fournisseur: ${r['fournisseur']}',
                                              style: GoogleFonts.montserrat(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${r['quantite']}',
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: r['conforme'] == 1
                                                  ? Colors.green.shade100
                                                  : Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              r['conforme'] == 1
                                                  ? 'Conforme'
                                                  : 'Non OK',
                                              style: GoogleFonts.montserrat(
                                                color: r['conforme'] == 1
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red.shade400,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _deleteReception(r['id']),
                                        tooltip: 'Supprimer',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    date,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (r['remarque'] != null &&
                                      (r['remarque'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.note,
                                            size: 16,
                                            color: Colors.green.shade600,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              r['remarque'] as String,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (photoPath != null &&
                                      photoPath.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 80,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade300,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: GestureDetector(
                                          onTap: () =>
                                              _showPhotoDialog(photoPath),
                                          child: Image.file(
                                            File(photoPath),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Formulaire
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Header du formulaire
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.green.shade100,
                                child: Icon(
                                  Icons.local_shipping,
                                  color: Colors.green.shade700,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Nouvelle réception',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Fournisseur
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: _fournisseur,
                                      items: _fournisseurs.map((f) {
                                        return DropdownMenuItem<String>(
                                          value: f,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  f,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red.shade400,
                                                  size: 16,
                                                ),
                                                onPressed: () =>
                                                    _deleteFournisseur(f),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 24,
                                                      minHeight: 24,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) =>
                                          setState(() => _fournisseur = val!),
                                      decoration: InputDecoration(
                                        labelText: 'Fournisseur',
                                        prefixIcon: Icon(
                                          Icons.business,
                                          color: Colors.green.shade600,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.green.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 12,
                                            ),
                                      ),
                                      menuMaxHeight: 200,
                                      isExpanded: true,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _addFournisseur,
                                      icon: const Icon(Icons.add),
                                      label: Text(
                                        'Ajouter un fournisseur',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Produit
                          TextFormField(
                            controller: _produitController,
                            style: GoogleFonts.montserrat(),
                            decoration: InputDecoration(
                              labelText: 'Produit',
                              prefixIcon: Icon(
                                Icons.inventory,
                                color: Colors.green.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.green.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un produit';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Quantité et Statut
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _quantiteController,
                                  style: GoogleFonts.montserrat(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Quantité',
                                    prefixIcon: Icon(
                                      Icons.scale,
                                      color: Colors.green.shade600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.green.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Obligatoire';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _statut,
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: 'Conforme',
                                      child: Text(
                                        'Conforme',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'Non conforme',
                                      child: Text(
                                        'Non OK',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _statut = val!),
                                  decoration: InputDecoration(
                                    labelText: 'Statut',
                                    prefixIcon: Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.green.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  menuMaxHeight: 200,
                                  isExpanded: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Remarque
                          TextFormField(
                            controller: _remarqueController,
                            style: GoogleFonts.montserrat(),
                            decoration: InputDecoration(
                              labelText: 'Remarque (optionnel)',
                              prefixIcon: Icon(
                                Icons.note,
                                color: Colors.green.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.green.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                            maxLines: 3,
                            minLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Photo
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.green.shade50,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Photo',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_selectedImage != null) ...[
                                  Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _showPhotoOptions,
                                          icon: const Icon(Icons.edit),
                                          label: Text(
                                            'Modifier',
                                            style: GoogleFonts.montserrat(),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _removePhoto,
                                          icon: const Icon(Icons.delete),
                                          label: Text(
                                            'Supprimer',
                                            style: GoogleFonts.montserrat(),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  ElevatedButton.icon(
                                    onPressed: _showPhotoOptions,
                                    icon: const Icon(Icons.add_a_photo),
                                    label: Text(
                                      'Ajouter une photo',
                                      style: GoogleFonts.montserrat(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Bouton d'enregistrement
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _saveReception();
                                }
                              },
                              icon: const Icon(Icons.save),
                              label: Text(
                                'Enregistrer',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Historique
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Historique des réceptions',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _exportToCsv,
                              icon: Icon(
                                Icons.download,
                                color: Colors.green.shade600,
                              ),
                              tooltip: 'Export CSV',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _receptions.length,
                          itemBuilder: (context, index) {
                            final r = _receptions[index];
                            final date = DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(DateTime.parse(r['date']));
                            final photoPath = r['photo_path'] as String?;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  '${r['fournisseur']} - ${r['article']} (${r['quantite']})',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      'Date: $date',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Statut: ${r['conforme'] == 1 ? 'Conforme' : 'Non OK'}',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    if (r['remarque']?.isNotEmpty == true) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Remarque: ${r['remarque']}',
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ],
                                    if (photoPath != null &&
                                        photoPath.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.photo,
                                            color: Colors.green.shade600,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          TextButton(
                                            onPressed: () =>
                                                _showPhotoDialog(photoPath),
                                            child: Text(
                                              'Voir la photo',
                                              style: GoogleFonts.poppins(
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red.shade400,
                                  ),
                                  onPressed: () => _deleteReception(r['id']),
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: r['conforme'] == 1
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.local_shipping,
                                    color: r['conforme'] == 1
                                        ? Colors.green.shade600
                                        : Colors.red.shade600,
                                    size: 24,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
