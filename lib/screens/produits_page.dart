import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/products_repository.dart';
import '../services/network_service.dart';
import '../services/cache_service.dart';
import '../exceptions/app_exceptions.dart';
import '../models/produit.dart';
import '../widgets/quick_preparation_form.dart';

class ProduitsPage extends StatefulWidget {
  const ProduitsPage({super.key});

  @override
  State<ProduitsPage> createState() => _ProduitsPageState();
}

class _ProduitsPageState extends State<ProduitsPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _productsRepo = ProductsRepository();
  final _networkService = NetworkService();
  final _nomController = TextEditingController();
  final _dlcJoursController = TextEditingController();
  final _dlcSurgelationController = TextEditingController();

  bool _utiliseDlcJours = true;
  bool _surgelagable = false;

  List<Produit> _produits = [];
  bool _isLoading = true;
  bool _isOnline = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkNetwork();
    _loadProduits();
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

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);
    try {
      // Try cache first
      final cached = CacheService().get('produits_all');
      if (cached != null) {
        final produits = (cached as List)
            .map((map) => Produit.fromMap(Map<String, dynamic>.from(map)))
            .toList();
        setState(() {
          _produits = produits;
        });
      }

      // Load from Supabase
      final produitsMaps = await _productsRepo.getAll();
      final produits = produitsMaps.map((map) => Produit.fromMap(map)).toList();
      setState(() {
        _produits = produits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Erreur: ${e is AppException ? e.message : e.toString()}')),
        );
      }
    }
  }

  Future<void> _ajouterProduit() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network required')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        int? dlcJours;
        int? dlcSurgelationJours;
        if (_utiliseDlcJours) {
          dlcJours = int.tryParse(_dlcJoursController.text);
        }
        if (_surgelagable) {
          dlcSurgelationJours = int.tryParse(_dlcSurgelationController.text);
        }

        await _productsRepo.createProduct(
          nom: _nomController.text.trim(),
          typeProduit: TypeProduit.fini.name,
          dlcJours: dlcJours,
          dateFabrication: DateTime.now(),
          surgelagable: _surgelagable,
          dlcSurgelationJours: dlcSurgelationJours,
        );

        // Réinitialiser le formulaire
        _formKey.currentState!.reset();
        _nomController.clear();
        _dlcJoursController.clear();
        _dlcSurgelationController.clear();
        setState(() {
          _utiliseDlcJours = true;
          _surgelagable = false;
        });
        _loadProduits();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produit ajouté avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'ajout du produit: $e')),
          );
        }
      }
    }
  }

  Future<void> _supprimerProduit(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce produit ?'),
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
      if (!_isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network required')),
        );
        return;
      }

      try {
        await _productsRepo.deleteProduct(id);
        if (mounted) {
          _loadProduits();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produit supprimé avec succès !'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  }

  Future<void> _imprimerEtiquette(Produit produit) async {
    // Vérifier si le produit a les détails nécessaires pour l'impression
    if (produit.lot == null || produit.poids == null) {
      // Afficher le dialogue de saisie des détails
      await _showImpressionDetailsDialog(produit);
    } else {
      // Imprimer directement
      await _printEtiquette(produit);
    }
  }

  Future<void> _showImpressionDetailsDialog(Produit produit) async {
    final lotController = TextEditingController();
    final poidsController = TextEditingController();
    final preparateurController = TextEditingController();
    DateTime selectedDateFabrication = DateTime.now();
    DateTime? selectedDluo;
    TimeOfDay selectedHeurePreparation = TimeOfDay.now();
    bool utiliseDluo = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Détails d\'impression - ${produit.nom}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: lotController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de lot *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Champ obligatoire' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: poidsController,
                  decoration: InputDecoration(
                    labelText: 'Poids (kg) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Champ obligatoire';
                    if (double.tryParse(val) == null) return 'Nombre invalide';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: preparateurController,
                  decoration: InputDecoration(
                    labelText: 'Préparateur (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDateFabrication,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      selectedDateFabrication = picked;
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date de fabrication *',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      '${selectedDateFabrication.day.toString().padLeft(2, '0')}/${selectedDateFabrication.month.toString().padLeft(2, '0')}/${selectedDateFabrication.year}',
                    ),
                  ),
                ),
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Utiliser DLUO'),
                  value: utiliseDluo,
                  onChanged: (value) {
                    utiliseDluo = value;
                    if (!value) selectedDluo = null;
                  },
                ),
                if (utiliseDluo) ...[
                  SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDluo ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        selectedDluo = picked;
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date DLUO',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        selectedDluo != null
                            ? '${selectedDluo!.day.toString().padLeft(2, '0')}/${selectedDluo!.month.toString().padLeft(2, '0')}/${selectedDluo!.year}'
                            : 'Sélectionner une date',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (lotController.text.isNotEmpty &&
                    poidsController.text.isNotEmpty) {
                  if (!_isOnline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Network required')),
                    );
                    return;
                  }
                  // Mettre à jour le produit avec les détails
                  // Note: preparateur field not yet in schema, update only dateFabrication
                  await _productsRepo.updateProduct(
                    produit.id,
                    dateFabrication: selectedDateFabrication,
                  );

                  Navigator.of(context).pop();

                  // Recharger les produits et imprimer
                  await _loadProduits();
                  final updatedProduit =
                      _produits.firstWhere((p) => p.id == produit.id);
                  await _printEtiquette(updatedProduit);
                }
              },
              child: Text('Imprimer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printEtiquette(Produit produit) async {
    final pdf = pw.Document();

    // Calculer la DLC actuelle
    final dlcActuelle = produit.dlcCalculee ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        build: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.all(15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'ÉTIQUETTE PRODUIT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 15),

              // Informations du produit
              _buildInfoRow('Produit:', produit.nom),
              _buildInfoRow('Date fabrication:',
                  DateFormat('dd/MM/yyyy').format(produit.dateFabrication)),
              if (produit.heurePreparation != null)
                _buildInfoRow('Heure préparation:',
                    DateFormat('HH:mm').format(produit.heurePreparation!)),
              _buildInfoRow(
                  'DLC:', DateFormat('dd/MM/yyyy').format(dlcActuelle)),
              if (produit.dluo != null)
                _buildInfoRow(
                    'DLUO:', DateFormat('dd/MM/yyyy').format(produit.dluo!)),
              _buildInfoRow('Lot:', produit.lot ?? ''),
              _buildInfoRow(
                  'Poids:', '${(produit.poids ?? 0.0).toStringAsFixed(2)} kg'),
              if (produit.preparateur != null)
                _buildInfoRow('Préparateur:', produit.preparateur!),

              pw.SizedBox(height: 20),

              // Code-barres
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'Code: ${produit.lot ?? ''}-${DateFormat('ddMMyyyy').format(dlcActuelle)}',
                  style: const pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickPreparation(Produit produit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: QuickPreparationForm(
          produit: produit,
          onValidate:
              (lot, poids, preparateur, dateFabrication, surgeler) async {
            if (!_isOnline) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Network required')),
              );
              return;
            }
            // Mettre à jour le produit avec les détails de préparation
            // Note: preparateur field not yet in schema, update only dateFabrication
            await _productsRepo.updateProduct(
              produit.id,
              dateFabrication: dateFabrication,
            );

            // Fermer le modal
            Navigator.of(context).pop();

            // Recharger la liste
            await _loadProduits();

            // Afficher un message de succès
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Préparation enregistrée pour ${produit.nom}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF66BB6A),
            Color(0xFF81C784),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Nouveau Produit',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: Card(
          margin: const EdgeInsets.all(16),
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header du formulaire
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.green.shade100,
                          child: Icon(Icons.inventory,
                              color: Colors.green.shade700, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajout Rapide',
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              Text(
                                'Nom + DLC uniquement',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Nom du produit (OBLIGATOIRE)
                    TextFormField(
                      controller: _nomController,
                      style: GoogleFonts.montserrat(),
                      decoration: InputDecoration(
                        labelText: 'Nom du produit *',
                        prefixIcon:
                            Icon(Icons.inventory, color: Colors.green.shade600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.green.shade50,
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Champ obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // DLC en +n jours
                    TextFormField(
                      controller: _dlcJoursController,
                      style: GoogleFonts.montserrat(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'DLC en +n jours *',
                        hintText: 'Ex: 3 pour DLC = +3 jours',
                        prefixIcon:
                            Icon(Icons.add_circle, color: Colors.blue.shade600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Champ obligatoire';
                        }
                        final jours = int.tryParse(val);
                        if (jours == null || jours < 0) {
                          return 'Nombre de jours invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Produit surgelagable ?
                    SwitchListTile(
                      title: const Text('Produit surgelagable ?'),
                      subtitle: const Text('Peut être conservé au congélateur'),
                      value: _surgelagable,
                      onChanged: (value) {
                        setState(() {
                          _surgelagable = value;
                        });
                      },
                      secondary: Icon(
                        _surgelagable ? Icons.ac_unit : Icons.ac_unit_outlined,
                        color: _surgelagable ? Colors.blue : Colors.grey,
                      ),
                    ),
                    if (_surgelagable) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dlcSurgelationController,
                        decoration: const InputDecoration(
                          labelText: 'DLC surgélation en jours',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.ac_unit),
                          helperText:
                              'Ex: 30 pour DLC = +30 jours au congélateur',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_surgelagable &&
                              (value == null || value.trim().isEmpty)) {
                            return 'La DLC de surgélation est obligatoire';
                          }
                          if (value != null &&
                              value.trim().isNotEmpty &&
                              int.tryParse(value) == null) {
                            return 'Veuillez entrer un nombre valide';
                          }
                          return null;
                        },
                      ),
                    ],

                    // Bouton d'ajout
                    ElevatedButton(
                      onPressed: _ajouterProduit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Text(
                        'Ajouter le produit',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2196F3),
            Color(0xFF42A5F5),
            Color(0xFF64B5F6),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Liste des Produits',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: Card(
          margin: const EdgeInsets.all(16),
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 60,
                dataRowHeight: 80,
                columnSpacing: 20,
                columns: [
                  DataColumn(
                    label: Text('Nom',
                        style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('DLC',
                        style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Détails',
                        style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Actions',
                        style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
                rows: _produits.map((produit) {
                  final isExpired = produit.dlcCalculee != null &&
                      produit.dlcCalculee!.isBefore(DateTime.now());
                  final hasDetails =
                      produit.lot != null && produit.poids != null;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          produit.nom,
                          style: GoogleFonts.montserrat(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExpired
                                  ? Colors.red.shade300
                                  : Colors.green.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                    produit.dlcCalculee ?? DateTime.now()),
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isExpired
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              if (produit.dlcJours != null)
                                Text(
                                  '(+${produit.dlcJours} jours)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasDetails
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasDetails
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            hasDetails ? 'Complet' : 'À compléter',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasDetails
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.fastfood,
                                  size: 24, color: Colors.orange.shade600),
                              tooltip: 'Préparation rapide',
                              onPressed: () => _showQuickPreparation(produit),
                            ),
                            IconButton(
                              icon: Icon(Icons.print,
                                  size: 24, color: Colors.blue.shade600),
                              tooltip: 'Imprimer étiquette',
                              onPressed: () => _imprimerEtiquette(produit),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  size: 24, color: Colors.red.shade600),
                              tooltip: 'Supprimer',
                              onPressed: () => _supprimerProduit(produit.id),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Gestion des Produits'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddProductDialog(),
            tooltip: 'Ajouter un produit',
          ),
        ],
      ),
      body: _produits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun produit',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez votre premier produit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProductDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un produit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _produits.length,
              itemBuilder: (context, index) {
                final produit = _produits[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child:
                          Icon(Icons.inventory, color: Colors.purple.shade600),
                    ),
                    title: Text(
                      produit.nom,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DLC: +${produit.dlcJours ?? 0} jours'),
                        if (produit.ingredients != null &&
                            produit.ingredients!.isNotEmpty)
                          Text('Ingrédients: ${produit.ingredients}'),
                        if (produit.quantite != null &&
                            produit.quantite!.isNotEmpty)
                          Text('Quantité: ${produit.quantite}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.print, color: Colors.green.shade600),
                          onPressed: () => _imprimerEtiquette(produit),
                          tooltip: 'Imprimer étiquette',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red.shade400),
                          onPressed: () => _supprimerProduit(produit.id),
                          tooltip: 'Supprimer le produit',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomController.dispose();
    _dlcJoursController.dispose();
    _dlcSurgelationController.dispose();
    super.dispose();
  }

  Future<void> _showAddProductDialog() async {
    final nomController = TextEditingController();
    final dlcJoursController = TextEditingController();
    final ingredientsController = TextEditingController();
    final quantiteController = TextEditingController();
    final origineViandeController = TextEditingController();
    final allergenesController = TextEditingController();
    bool surgelagable = false;
    final dlcSurgelationController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              const Text('Nouveau Produit'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nom du produit
                  TextField(
                    controller: nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DLC en jours
                  TextField(
                    controller: dlcJoursController,
                    decoration: const InputDecoration(
                      labelText: 'DLC en jours (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                      helperText: 'Nombre de jours après fabrication',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Produit surgelagable
                  SwitchListTile(
                    title: const Text('Produit surgelagable'),
                    subtitle: const Text('Peut être conservé au congélateur'),
                    value: surgelagable,
                    onChanged: (value) {
                      setState(() {
                        surgelagable = value;
                      });
                    },
                    secondary: Icon(
                      surgelagable ? Icons.ac_unit : Icons.ac_unit_outlined,
                      color: surgelagable ? Colors.blue : Colors.grey,
                    ),
                  ),

                  // DLC surgélation (visible seulement si surgelagable)
                  if (surgelagable) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: dlcSurgelationController,
                      decoration: const InputDecoration(
                        labelText: 'DLC surgélation en jours',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.ac_unit),
                        helperText: 'DLC spécifique pour la surgélation',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Ingrédients
                  TextField(
                    controller: ingredientsController,
                    decoration: const InputDecoration(
                      labelText: 'Ingrédients (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.list),
                      helperText: 'Liste des ingrédients principaux',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Quantité
                  TextField(
                    controller: quantiteController,
                    decoration: const InputDecoration(
                      labelText: 'Quantité par unité (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                      helperText: 'Ex: 50 pièces, 1kg, etc.',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Origine viande
                  TextField(
                    controller: origineViandeController,
                    decoration: const InputDecoration(
                      labelText: 'Origine viande (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                      helperText: 'Ex: France, UE, etc.',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Allergènes
                  TextField(
                    controller: allergenesController,
                    decoration: const InputDecoration(
                      labelText: 'Allergènes (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning),
                      helperText: 'Ex: gluten, lait, œufs, etc.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nomController.dispose();
                dlcJoursController.dispose();
                ingredientsController.dispose();
                quantiteController.dispose();
                origineViandeController.dispose();
                allergenesController.dispose();
                dlcSurgelationController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nomController.text.trim().isNotEmpty) {
                  final dlcJours =
                      int.tryParse(dlcJoursController.text.trim()) ?? 0;
                  final dlcSurgelation =
                      int.tryParse(dlcSurgelationController.text.trim());

                  Navigator.pop(context, {
                    'nom': nomController.text.trim(),
                    'dlcJours': dlcJours,
                    'surgelagable': surgelagable,
                    'dlcSurgelationJours': dlcSurgelation,
                    'ingredients': ingredientsController.text.trim().isNotEmpty
                        ? ingredientsController.text.trim()
                        : null,
                    'quantite': quantiteController.text.trim().isNotEmpty
                        ? quantiteController.text.trim()
                        : null,
                    'origineViande':
                        origineViandeController.text.trim().isNotEmpty
                            ? origineViandeController.text.trim()
                            : null,
                    'allergenes': allergenesController.text.trim().isNotEmpty
                        ? allergenesController.text.trim()
                        : null,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (!_isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network required')),
        );
        return;
      }

      try {
        await _productsRepo.createProduct(
          nom: result['nom']?.toString() ?? '',
          typeProduit: TypeProduit.fini.name,
          dlcJours: result['dlcJours'] as int?,
          dateFabrication: DateTime.now(),
          surgelagable: result['surgelagable'] as bool?,
          dlcSurgelationJours: result['dlcSurgelationJours'] as int?,
          ingredients: result['ingredients']?.toString(),
          quantite: result['quantite']?.toString(),
          origineViande: result['origineViande']?.toString(),
          allergenes: result['allergenes']?.toString(),
        );

        await _loadProduits();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produit "${result['nom']}" ajouté avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ajout du produit: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
