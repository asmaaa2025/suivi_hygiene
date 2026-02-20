import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../repositories/products_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../../../../models/produit.dart';
import '../../../../utils/text_input_formatters.dart';

class GestionProduitsPage extends StatefulWidget {
  const GestionProduitsPage({super.key});

  @override
  State<GestionProduitsPage> createState() => _GestionProduitsPageState();
}

class _GestionProduitsPageState extends State<GestionProduitsPage> {
  final _productsRepo = ProductsRepository();
  final _networkService = NetworkService();
  List<Produit> produits = [];
  bool isLoading = true;
  bool _isOnline = true;
  String searchQuery = '';
  TypeProduit selectedTypeProduit = TypeProduit.fini;

  // Contrôleurs pour l'ajout/modification de produit
  final _nomController = TextEditingController();
  final _dlcJoursController = TextEditingController();
  final _dlcSurgelationController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _origineViandeController = TextEditingController();
  final _allergenesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    loadProduits();
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

  Future<void> loadProduits() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load from Supabase directly (no cache)
      final produitsMaps = await _productsRepo.getAll();
      final produitsList = produitsMaps
          .map((map) => Produit.fromMap(map))
          .toList();
      setState(() {
        produits = produitsList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  List<Produit> get filteredProduits {
    if (searchQuery.isEmpty) return produits;
    return produits
        .where(
          (produit) =>
              produit.nom.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (produit.ingredients?.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ??
                  false) ||
              (produit.allergenes?.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  Future<void> _ajouterProduit() async {
    // Variable locale pour gérer la sélection dans le dialogue
    TypeProduit localSelectedType = selectedTypeProduit;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Nouveau produit'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nomController,
                      decoration: InputDecoration(
                        labelText: 'Nom du produit *',
                        border: OutlineInputBorder(),
                        helperText:
                            'Caractères spéciaux automatiquement corrigés',
                      ),
                      inputFormatters: [ProductNameInputFormatter()],
                    ),
                    const SizedBox(height: 16),

                    // Sélecteur de type de produit
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
                      localSelectedType == TypeProduit.recu
                          ? 'Produit reçu d\'un fournisseur'
                          : localSelectedType == TypeProduit.fini
                          ? 'Produit vendu directement aux clients'
                          : localSelectedType == TypeProduit.prepare
                          ? 'Produit intermédiaire (farce, etc.) pour créer d\'autres produits'
                          : localSelectedType == TypeProduit.ouverture
                          ? 'Produit ouvert (bouteille de lait, conserve, etc.)'
                          : 'Produit décongelé pour utilisation',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      children: TypeProduit.values.map((type) {
                        final isSelected = localSelectedType == type;
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
                            setDialogState(() {
                              localSelectedType = type;
                              // Remplir automatiquement la DLC selon le type
                              _dlcJoursController.text = type.dlcParDefaut
                                  .toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          splashColor: color.shade200.withOpacity(0.3),
                          highlightColor: color.shade100.withOpacity(0.2),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? color.shade100 : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? color.shade600
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dlcJoursController,
                      decoration: InputDecoration(
                        labelText: 'DLC en jours (optionnel)',
                        border: OutlineInputBorder(),
                        helperText: 'Nombre de jours après fabrication',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [IntegerInputFormatter(maxValue: 365)],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dlcSurgelationController,
                      decoration: InputDecoration(
                        labelText: 'DLC de surgélation (optionnel)',
                        border: OutlineInputBorder(),
                        helperText: 'Nombre de jours après surgélation',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [IntegerInputFormatter(maxValue: 365)],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ingredientsController,
                      decoration: InputDecoration(
                        labelText: 'Ingrédients (optionnel)',
                        border: OutlineInputBorder(),
                        helperText: 'Liste des ingrédients principaux',
                      ),
                      maxLines: 2,
                      inputFormatters: [
                        DescriptionInputFormatter(maxLength: 200),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantiteController,
                      decoration: InputDecoration(
                        labelText: 'Quantité par unité (optionnel)',
                        border: OutlineInputBorder(),
                        helperText: 'Ex: 50 pièces, 1kg, etc.',
                      ),
                      inputFormatters: [ZplSafeTextInputFormatter()],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _origineViandeController,
                      decoration: InputDecoration(
                        labelText: 'Origine viande (optionnel)',
                        border: OutlineInputBorder(),
                        helperText: 'Ex: France, UE, etc.',
                      ),
                      inputFormatters: [ZplSafeTextInputFormatter()],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _allergenesController,
                      decoration: InputDecoration(
                        labelText: 'Allergènes (optionnel)',
                        border: OutlineInputBorder(),
                        helperText: 'Ex: gluten, lait, œufs, etc.',
                      ),
                      inputFormatters: [
                        DescriptionInputFormatter(maxLength: 100),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nomController.text.trim().isNotEmpty) {
                    final dlcJours =
                        int.tryParse(_dlcJoursController.text.trim()) ?? 0;
                    final dlcSurgelation =
                        int.tryParse(_dlcSurgelationController.text.trim()) ??
                        0;
                    Navigator.pop(context, {
                      'nom': _nomController.text.trim(),
                      'typeProduit': localSelectedType,
                      'dlcJours': dlcJours,
                      'dlcSurgelationJours': dlcSurgelation,
                      'ingredients':
                          _ingredientsController.text.trim().isNotEmpty
                          ? _ingredientsController.text.trim()
                          : null,
                      'quantite': _quantiteController.text.trim().isNotEmpty
                          ? _quantiteController.text.trim()
                          : null,
                      'origineViande':
                          _origineViandeController.text.trim().isNotEmpty
                          ? _origineViandeController.text.trim()
                          : null,
                      'allergenes': _allergenesController.text.trim().isNotEmpty
                          ? _allergenesController.text.trim()
                          : null,
                    });
                  }
                },
                child: Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      if (!_isOnline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network required')));
        return;
      }

      try {
        await _productsRepo.createProduct(
          nom: result['nom']?.toString() ?? '',
          typeProduit: result['typeProduit']?.toString(),
          dlcJours: result['dlcJours'] as int?,
          dlcSurgelationJours: result['dlcSurgelationJours'] as int?,
          ingredients: result['ingredients']?.toString(),
          quantite: result['quantite']?.toString(),
          origineViande: result['origineViande']?.toString(),
          allergenes: result['allergenes']?.toString(),
        );

        await loadProduits();

        _nomController.clear();
        _dlcJoursController.clear();
        _dlcSurgelationController.clear();
        _ingredientsController.clear();
        _quantiteController.clear();
        _origineViandeController.clear();
        _allergenesController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Produit "${result['nom']}" ajouté avec succès',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Erreur lors de l\'ajout du produit: $e',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextInputFormatter? formatter,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: formatter != null ? [formatter] : null,
      style: GoogleFonts.montserrat(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        helperText: helperText,
        helperStyle: GoogleFonts.poppins(fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.purple.shade600, size: 28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.purple.shade300, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.purple.shade300, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.purple.shade600, width: 3),
        ),
        filled: true,
        fillColor: Colors.purple.shade50,
        contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
    );
  }

  Future<void> _modifierProduit(Produit produit) async {
    // Pré-remplir les contrôleurs avec les données du produit
    _nomController.text = produit.nom;
    TypeProduit localSelectedType = produit.typeProduit;
    _dlcJoursController.text = produit.dlcJours?.toString() ?? '';
    _dlcSurgelationController.text =
        produit.dlcSurgelationJours?.toString() ?? '';
    _ingredientsController.text = produit.ingredients ?? '';
    _quantiteController.text = produit.quantite ?? '';
    _origineViandeController.text = produit.origineViande ?? '';
    _allergenesController.text = produit.allergenes ?? '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Colors.blue.shade600,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Modifier le produit',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 600, // Augmenté de 500 à 600
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormField(
                      controller: _nomController,
                      label: 'Nom du produit *',
                      helperText:
                          'Caractères spéciaux automatiquement corrigés',
                      icon: Icons.inventory,
                      formatter: ProductNameInputFormatter(),
                    ),
                    SizedBox(height: 24), // Augmenté de 16 à 24
                    // Sélecteur de type de produit
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type de produit *',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          localSelectedType == TypeProduit.recu
                              ? 'Produit reçu d\'un fournisseur'
                              : localSelectedType == TypeProduit.fini
                              ? 'Produit vendu directement aux clients'
                              : localSelectedType == TypeProduit.prepare
                              ? 'Produit intermédiaire (farce, etc.) pour créer d\'autres produits'
                              : localSelectedType == TypeProduit.ouverture
                              ? 'Produit ouvert (bouteille de lait, conserve, etc.)'
                              : 'Produit décongelé pour utilisation',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.5,
                          children: TypeProduit.values.map((type) {
                            final isSelected = localSelectedType == type;
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
                                setDialogState(() {
                                  localSelectedType = type;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              splashColor: color.shade200.withOpacity(0.3),
                              highlightColor: color.shade100.withOpacity(0.2),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.shade100
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? color.shade600
                                        : Colors.grey.shade300,
                                    width: isSelected ? 3 : 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.shade200.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                  : type ==
                                                        TypeProduit.ouverture
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
                      ],
                    ),
                    SizedBox(height: 24), // Augmenté de 16 à 24
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            controller: _dlcJoursController,
                            label: 'DLC en jours',
                            helperText:
                                'Modifiable - DLC recommandée : ${localSelectedType.dlcDescription}',
                            icon: Icons.schedule,
                            keyboardType: TextInputType.number,
                            formatter: IntegerInputFormatter(maxValue: 365),
                          ),
                        ),
                        SizedBox(width: 16), // Augmenté de 12 à 16
                        Expanded(
                          child: _buildFormField(
                            controller: _dlcSurgelationController,
                            label: 'DLC surgélation',
                            helperText: 'Jours après surgélation (optionnel)',
                            icon: Icons.ac_unit,
                            keyboardType: TextInputType.number,
                            formatter: IntegerInputFormatter(maxValue: 365),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24), // Augmenté de 16 à 24
                    _buildFormField(
                      controller: _ingredientsController,
                      label: 'Ingrédients',
                      helperText: 'Liste des ingrédients principaux',
                      icon: Icons.list,
                      maxLines: 4, // Augmenté de 3 à 4
                      formatter: DescriptionInputFormatter(maxLength: 200),
                    ),
                    SizedBox(height: 24), // Augmenté de 16 à 24
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            controller: _quantiteController,
                            label: 'Quantité par unité',
                            helperText: 'Ex: 50 pièces, 1kg',
                            icon: Icons.scale,
                            formatter: ZplSafeTextInputFormatter(),
                          ),
                        ),
                        SizedBox(width: 16), // Augmenté de 12 à 16
                        Expanded(
                          child: _buildFormField(
                            controller: _origineViandeController,
                            label: 'Origine viande',
                            helperText: 'Ex: France, UE',
                            icon: Icons.location_on,
                            formatter: ZplSafeTextInputFormatter(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24), // Augmenté de 16 à 24
                    _buildFormField(
                      controller: _allergenesController,
                      label: 'Allergènes',
                      helperText: 'Ex: gluten, lait, œufs',
                      icon: Icons.warning,
                      formatter: DescriptionInputFormatter(maxLength: 100),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nomController.text.trim().isNotEmpty) {
                    final dlcJours =
                        int.tryParse(_dlcJoursController.text.trim()) ?? 0;
                    final dlcSurgelation =
                        int.tryParse(_dlcSurgelationController.text.trim()) ??
                        0;
                    Navigator.pop(context, {
                      'nom': _nomController.text.trim(),
                      'typeProduit': localSelectedType,
                      'dlcJours': dlcJours,
                      'dlcSurgelationJours': dlcSurgelation,
                      'ingredients':
                          _ingredientsController.text.trim().isNotEmpty
                          ? _ingredientsController.text.trim()
                          : null,
                      'quantite': _quantiteController.text.trim().isNotEmpty
                          ? _quantiteController.text.trim()
                          : null,
                      'origineViande':
                          _origineViandeController.text.trim().isNotEmpty
                          ? _origineViandeController.text.trim()
                          : null,
                      'allergenes': _allergenesController.text.trim().isNotEmpty
                          ? _allergenesController.text.trim()
                          : null,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Modifier',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      if (!_isOnline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network required')));
        return;
      }

      try {
        await _productsRepo.updateProduct(
          produit.id,
          nom: result['nom']?.toString(),
          typeProduit: result['typeProduit']?.toString(),
          dlcJours: result['dlcJours'] as int?,
          dlcSurgelationJours: result['dlcSurgelationJours'] as int?,
          ingredients: result['ingredients']?.toString(),
          quantite: result['quantite']?.toString(),
          origineViande: result['origineViande']?.toString(),
          allergenes: result['allergenes']?.toString(),
        );

        await loadProduits();

        // Réinitialiser les contrôleurs
        _nomController.clear();
        _dlcJoursController.clear();
        _dlcSurgelationController.clear();
        _ingredientsController.clear();
        _quantiteController.clear();
        _origineViandeController.clear();
        _allergenesController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Produit "${result['nom']}" modifié avec succès',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Erreur lors de la modification du produit: $e',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _supprimerProduit(Produit produit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete, color: Colors.red.shade600),
            ),
            SizedBox(width: 12),
            Text(
              'Confirmation',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le produit "${produit.nom}" ?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Supprimer',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!_isOnline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network required')));
        return;
      }

      try {
        await _productsRepo.deleteProduct(produit.id);

        await loadProduits();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Produit "${produit.nom}" supprimé avec succès',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Erreur lors de la suppression: $e',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Gestion des Produits',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: loadProduits,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple.shade600),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des produits...',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // En-tête avec statistiques et recherche
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade600, Colors.purple.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Statistiques
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.inventory,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Produits enregistrés',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                Text(
                                  '${produits.length} produit${produits.length > 1 ? 's' : ''}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _ajouterProduit,
                            icon: Icon(Icons.add),
                            label: Text(
                              'Ajouter',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.purple.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Barre de recherche
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                          },
                          style: GoogleFonts.montserrat(),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un produit...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.purple.shade600,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des produits
                Expanded(
                  child: filteredProduits.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  searchQuery.isNotEmpty
                                      ? Icons.search_off
                                      : Icons.inventory_2_outlined,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'Aucun produit trouvé'
                                    : 'Aucun produit',
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'Essayez avec d\'autres termes de recherche'
                                    : 'Ajoutez votre premier produit',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              SizedBox(height: 24),
                              if (!searchQuery.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: _ajouterProduit,
                                  icon: Icon(Icons.add),
                                  label: Text('Ajouter un produit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade600,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredProduits.length,
                          itemBuilder: (context, index) {
                            final produit = filteredProduits[index];
                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                leading: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.shade100,
                                        Colors.purple.shade200,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.inventory,
                                    color: Colors.purple.shade600,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  produit.nom,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8),

                                    // Badge du type de produit
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            produit.typeProduit ==
                                                TypeProduit.recu
                                            ? Colors.purple.shade100
                                            : produit.typeProduit ==
                                                  TypeProduit.fini
                                            ? Colors.green.shade100
                                            : produit.typeProduit ==
                                                  TypeProduit.prepare
                                            ? Colors.orange.shade100
                                            : produit.typeProduit ==
                                                  TypeProduit.ouverture
                                            ? Colors.red.shade100
                                            : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            produit.typeProduit ==
                                                    TypeProduit.recu
                                                ? Icons.local_shipping
                                                : produit.typeProduit ==
                                                      TypeProduit.fini
                                                ? Icons.shopping_cart
                                                : produit.typeProduit ==
                                                      TypeProduit.prepare
                                                ? Icons.build
                                                : produit.typeProduit ==
                                                      TypeProduit.ouverture
                                                ? Icons.open_in_new
                                                : Icons.ac_unit,
                                            color:
                                                produit.typeProduit ==
                                                    TypeProduit.recu
                                                ? Colors.purple.shade700
                                                : produit.typeProduit ==
                                                      TypeProduit.fini
                                                ? Colors.green.shade700
                                                : produit.typeProduit ==
                                                      TypeProduit.prepare
                                                ? Colors.orange.shade700
                                                : produit.typeProduit ==
                                                      TypeProduit.ouverture
                                                ? Colors.red.shade700
                                                : Colors.blue.shade700,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            produit.typeProduit ==
                                                    TypeProduit.recu
                                                ? 'Produit reçu'
                                                : produit.typeProduit ==
                                                      TypeProduit.fini
                                                ? 'Produit fini'
                                                : produit.typeProduit ==
                                                      TypeProduit.prepare
                                                ? 'Produit préparé'
                                                : produit.typeProduit ==
                                                      TypeProduit.ouverture
                                                ? 'Ouverture'
                                                : 'Décongélation',
                                            style: TextStyle(
                                              color:
                                                  produit.typeProduit ==
                                                      TypeProduit.recu
                                                  ? Colors.purple.shade700
                                                  : produit.typeProduit ==
                                                        TypeProduit.fini
                                                  ? Colors.green.shade700
                                                  : produit.typeProduit ==
                                                        TypeProduit.prepare
                                                  ? Colors.orange.shade700
                                                  : produit.typeProduit ==
                                                        TypeProduit.ouverture
                                                  ? Colors.red.shade700
                                                  : Colors.blue.shade700,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (produit.dlcJours != null &&
                                        produit.dlcJours! > 0)
                                      Container(
                                        margin: EdgeInsets.only(top: 4),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'DLC: +${produit.dlcJours} jours',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (produit.dlcSurgelationJours != null &&
                                        produit.dlcSurgelationJours! > 0)
                                      Container(
                                        margin: EdgeInsets.only(top: 4),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'DLC surgélation: +${produit.dlcSurgelationJours} jours',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (produit.ingredients != null &&
                                        produit.ingredients!.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Ingrédients: ${produit.ingredients}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (produit.quantite != null &&
                                        produit.quantite!.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Quantité: ${produit.quantite}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (produit.origineViande != null &&
                                        produit.origineViande!.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Origine viande: ${produit.origineViande}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (produit.allergenes != null &&
                                        produit.allergenes!.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.only(top: 8),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Allergènes: ${produit.allergenes}',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue.shade600,
                                        ),
                                        onPressed: () =>
                                            _modifierProduit(produit),
                                        tooltip: 'Modifier',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red.shade600,
                                        ),
                                        onPressed: () =>
                                            _supprimerProduit(produit),
                                        tooltip: 'Supprimer',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterProduit,
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text(
          'Ajouter',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        elevation: 8,
      ),
    );
  }
}
