import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../../repositories/products_repository.dart';
import '../../../../repositories/labels_repository.dart';
import '../../../../models/produit.dart';
import '../../../../services/text_sanitizer_service.dart';
import '../../../../services/bluetooth_service.dart';
import '../../../../services/logo_service.dart';
import '../../../../services/network_service.dart';
import '../../../../services/cache_service.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../../../../utils/text_input_formatters.dart';
import 'package:intl/intl.dart';

class EtiquettePage extends StatefulWidget {
  const EtiquettePage({super.key});

  @override
  State<EtiquettePage> createState() => _EtiquettePageState();
}

class _EtiquettePageState extends State<EtiquettePage> {
  final BluetoothService _bluetoothService = BluetoothService();
  final TextSanitizerService _textSanitizer = TextSanitizerService();
  final LogoService _logoService = LogoService();
  final _productsRepo = ProductsRepository();
  final _labelsRepo = LabelsRepository();
  final _networkService = NetworkService();

  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  bool isPrinting = false;

  List<Produit> produits = [];
  Produit? selectedProduit;
  bool showPreparationForm = false;
  bool _isOnline = true;
  bool _isLoading = false;

  // Contrôleurs pour le formulaire de préparation
  final _lotController = TextEditingController();
  final _poidsController = TextEditingController();
  final _preparateurController = TextEditingController();
  final _dluoController = TextEditingController();
  final _nombreEtiquettesController = TextEditingController(text: '1');
  final _fabricantController = TextEditingController();

  // Contrôleurs pour l'ajout de produit
  final _newProduitController = TextEditingController();
  final _dlcJoursController = TextEditingController();
  final _dlcSurgelationController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _origineViandeController = TextEditingController();
  final _allergenesController = TextEditingController();

  DateTime _selectedDateFabrication = DateTime.now();
  TimeOfDay _selectedHeurePreparation = TimeOfDay.now();
  DateTime _selectedDateSurgelation = DateTime.now();
  bool _dlcJourMeme = false;
  bool _utiliseDluo = false;
  bool _isSurgel = false;
  bool _logoAvailable = false;
  bool _showLogo = true;
  final TypeProduit _selectedTypeProduit = TypeProduit.fini;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _initializeData();
    initBluetooth();
    checkLogoAvailability();
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

  Future<void> _initializeData() async {
    try {
      await loadProduits();
    } catch (e) {
      debugPrint('❌ [Étiquettes] Erreur initialisation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur initialisation: ${e is AppException ? e.message : e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _lotController.dispose();
    _poidsController.dispose();
    _preparateurController.dispose();
    _dluoController.dispose();
    _nombreEtiquettesController.dispose();
    _fabricantController.dispose();
    _newProduitController.dispose();
    _dlcJoursController.dispose();
    _dlcSurgelationController.dispose();
    _ingredientsController.dispose();
    _quantiteController.dispose();
    _origineViandeController.dispose();
    _allergenesController.dispose();
    super.dispose();
  }

  Future<void> loadProduits() async {
    setState(() => _isLoading = true);
    try {
      // Try cache first
      final cached = CacheService().get('produits_all');
      if (cached != null) {
        final produitsList = (cached as List)
            .map((map) => Produit.fromMap(Map<String, dynamic>.from(map)))
            .toList();
        setState(() {
          produits = produitsList;
        });
      }

      // Load from Supabase
      final produitsMaps = await _productsRepo.getAll();
      final produitsList =
          produitsMaps.map((map) => Produit.fromMap(map)).toList();
      if (mounted) {
        setState(() {
          produits = produitsList;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur: ${e is AppException ? e.message : e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> initBluetooth() async {
    try {
      final devicesList = await _bluetoothService.scanDevices();
      setState(() {
        devices = devicesList;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur Bluetooth: $e')),
      );
    }
  }

  Future<void> checkLogoAvailability() async {
    final hasLogo = await _logoService.hasLogo();
    setState(() {
      _logoAvailable = hasLogo;
    });
  }

  Future<String> generateZplEtiquette({
    required Produit produit,
    required String lot,
    required double poids,
    required DateTime fabrication,
    required DateTime dlc,
    String? preparateur,
    bool isSurgel = false,
    DateTime? dateSurgelation,
    bool showLogo = true,
    String? fabricant,
  }) async {
    final df = DateFormat('dd/MM/yyyy');
    final logoCommand = showLogo ? await _logoService.getLogoCommand() : '';

    final ingredients =
        _textSanitizer.sanitizeForZpl(produit.ingredients ?? '');
    final quantite = _textSanitizer.sanitizeForZpl(produit.quantite ?? '');
    final origineViande =
        _textSanitizer.sanitizeForZpl(produit.origineViande ?? '');
    final allergenes = _textSanitizer.sanitizeForZpl(produit.allergenes ?? '');

    final title = _textSanitizer.sanitizeForZpl(produit.nom).toUpperCase();
    final titleLength = title.length;

    int titleFontSize;
    if (titleLength <= 20) {
      titleFontSize = 35;
    } else if (titleLength <= 30) {
      titleFontSize = 30;
    } else if (titleLength <= 40) {
      titleFontSize = 26;
    } else {
      titleFontSize = 22;
    }

    final typeProduitText = _getTypeProduitText(produit.typeProduit);
    final typeProduitX = (600 - (typeProduitText.length * 8)) ~/ 2;
    final typeProduitXPosition = typeProduitX > 20 ? typeProduitX : 20;

    int currentPos = 85;
    int fieldCount = 0;
    final List<String> contentLines = [];

    // Calculer d'abord le nombre de champs pour estimer la hauteur
    void countFields() {
      if (ingredients.trim().isNotEmpty) {
        // Compter les ingrédients selon leur longueur
        if (ingredients.length > 75) {
          fieldCount += 2; // Deux lignes pour les ingrédients longs
        } else {
          fieldCount += 1; // Une ligne pour les ingrédients courts
        }
      }
      if (quantite.trim().isNotEmpty) fieldCount++;
      fieldCount++; // Conservation (toujours présent)
      fieldCount++; // Date fabrication (toujours présent)
      fieldCount++; // DLC (toujours présent)
      if (isSurgel) {
        fieldCount++; // Mode d'emploi surgelé (2 lignes)
      } else {
        fieldCount++; // Mode d'emploi frais
      }
      if (produit.typeProduit == TypeProduit.fini) {
        if (fabricant != null && fabricant.trim().isNotEmpty) {
          fieldCount += 1; // Fabricant
        }
        fieldCount += 2; // Adresse, SIRET
      }
      fieldCount++; // Lot (toujours présent)
      if (origineViande.trim().isNotEmpty) fieldCount++;
      if (allergenes.trim().isNotEmpty) fieldCount++;
    }

    countFields();

    // Hauteur dynamique de l'étiquette
    final estimatedHeight = 300 + (fieldCount * 20);

    // Taille de police adaptative selon la hauteur
    int baseFontSize;
    if (estimatedHeight <= 400) {
      baseFontSize = 20;
    } else if (estimatedHeight <= 500) {
      baseFontSize = 18;
    } else if (estimatedHeight <= 600) {
      baseFontSize = 16;
    } else {
      baseFontSize = 14;
    }

    // Calculer l'espacement adaptatif selon la taille de police
    int getSpacing() {
      if (estimatedHeight <= 400) {
        return 150; // Police 20
      } else if (estimatedHeight <= 500) {
        return 140; // Police 18
      } else if (estimatedHeight <= 600) {
        return 130; // Police 16
      } else {
        return 120; // Police 14
      }
    }

    int getDateSpacing() {
      // Plus d'espace pour les dates avec des labels longs
      if (estimatedHeight <= 400) {
        return 170; // Police 20
      } else if (estimatedHeight <= 500) {
        return 160; // Police 18
      } else if (estimatedHeight <= 600) {
        return 150; // Police 16
      } else {
        return 140; // Police 14
      }
    }

    void addField(String label, String value) {
      if (value.trim().isEmpty) return;
      contentLines.add('^FO20,$currentPos^FD$label:^FS');
      contentLines.add('^FO${getSpacing()},$currentPos^FD$value^FS');
      currentPos += 20;
    }

    void addIngredients(String ingredients) {
      if (ingredients.trim().isEmpty) return;

      contentLines.add('^FO20,$currentPos^FDIngredients:^FS');

      // Si les ingrédients sont trop longs, les diviser sur plusieurs lignes
      if (ingredients.length > 75) {
        // Diviser par virgules et espaces
        final parts = ingredients.split(RegExp(r',\s*'));

        if (parts.length <= 2) {
          // Si seulement 2 parties, diviser au milieu du texte
          final midPoint = (ingredients.length / 2).round();
          final firstLine = ingredients.substring(0, midPoint);
          final secondLine = ingredients.substring(midPoint);

          contentLines.add('^FO${getSpacing()},$currentPos^FD$firstLine^FS');
          currentPos += 20;
          contentLines.add('^FO${getSpacing()},$currentPos^FD$secondLine^FS');
          currentPos += 20;
          fieldCount += 2;
        } else {
          // Si plusieurs parties, essayer de les répartir équitablement
          final midPoint = (parts.length / 2).ceil();
          final firstLine = parts.take(midPoint).join(', ');
          final secondLine = parts.skip(midPoint).join(', ');

          contentLines.add('^FO${getSpacing()},$currentPos^FD$firstLine^FS');
          currentPos += 20;
          contentLines.add('^FO${getSpacing()},$currentPos^FD$secondLine^FS');
          currentPos += 20;
          fieldCount += 2;
        }
      } else {
        contentLines.add('^FO${getSpacing()},$currentPos^FD$ingredients^FS');
        currentPos += 20;
        fieldCount += 1;
      }
    }

    addIngredients(ingredients);
    addField("Qte", quantite);
    addField(
        "Conservation", _getConservationText(produit.typeProduit, isSurgel));

    // Utiliser un espacement spécial pour la date
    contentLines
        .add('^FO20,$currentPos^FD${_getDateLabel(produit.typeProduit)}:^FS');
    contentLines.add(
        '^FO${getDateSpacing()},$currentPos^FD${df.format(fabrication)}^FS');
    currentPos += 20;

    addField("DLC", df.format(dlc));

    if (isSurgel) {
      fieldCount++;
      contentLines.add('^FO20,$currentPos^FDMode d\'emploi:^FS');
      contentLines
          .add('^FO150,$currentPos^FDA decongeler et conserver a +4 degres^FS');
      currentPos += 20;
      contentLines.add('^FO150,$currentPos^FDa consommer sous 3 jours^FS');
      currentPos += 20;
    } else {
      addField("Mode d'emploi", "Conserver a +4 degres");
    }

    if (produit.typeProduit == TypeProduit.fini) {
      if (fabricant != null && fabricant.trim().isNotEmpty) {
        addField("Fabricant", fabricant);
      }
      addField("Adresse", "7 rue Henri Pescarolo");
      addField("SIRET", "93279581800016");
    }

    addField("Lot", _textSanitizer.sanitizeForZpl(lot));

    // Ajouter un espace avant l'origine viande et les allergènes
    currentPos += 10;

    addField("Origine viande", origineViande);
    addField("Allergenes", allergenes);

    // Réécriture des lignes avec taille de police
    final formattedContent = contentLines.map((line) {
      return line.contains('^FD') ? '^CF0,$baseFontSize\n$line' : line;
    }).join('\n');

    return '''
^XA
^PW600
^LL$estimatedHeight
$logoCommand
^CF0,$titleFontSize
^FO${(600 - (title.length * titleFontSize * 0.5).round()) ~/ 2},20^FD$title^FS
^CF0,18
^FO$typeProduitXPosition,55^FD$typeProduitText^FS
$formattedContent
^XZ
''';
  }

  /// Formate les ingrédients sur une ou deux lignes selon la longueur
  String _formatIngredients(String ingredients) {
    if (ingredients.isEmpty) {
      return ''; // Retourner une chaîne vide au lieu d'une ligne vide
    }

    // Si le texte fait plus de 40 caractères, le diviser sur deux lignes
    if (ingredients.length > 40) {
      // Diviser le texte en deux parties
      final words = ingredients.split(', ');
      final midPoint = (words.length / 2).ceil();

      final firstLine = words.take(midPoint).join(', ');
      final secondLine = words.skip(midPoint).join(', ');

      return '''
^FO30,85^FD$firstLine^FS
^FO30,105^FD$secondLine^FS''';
    } else {
      // Texte court, une seule ligne
      return '^FO30,85^FD$ingredients^FS';
    }
  }

  /// Calcule la position de départ pour les éléments après les ingrédients
  int _getStartPositionAfterIngredients(String ingredients) {
    if (ingredients.isEmpty) {
      return 85; // Position de base quand pas d'ingrédients
    }

    // Si le texte fait plus de 40 caractères, il y a deux lignes
    if (ingredients.length > 40) {
      return 130; // Position après deux lignes d'ingrédients
    } else {
      return 110; // Position après une ligne d'ingrédients
    }
  }

  /// Retourne le texte du type de produit pour l'étiquette
  String _getTypeProduitText(TypeProduit typeProduit) {
    switch (typeProduit) {
      case TypeProduit.recu:
        return 'PRODUIT RECU';
      case TypeProduit.fini:
        return 'PRODUIT FINI';
      case TypeProduit.prepare:
        return 'PRODUIT PREPARE';
      case TypeProduit.ouverture:
        return 'PRODUIT OUVERT';
      case TypeProduit.decongelation:
        return 'PRODUIT DECONGELE';
    }
  }

  /// Retourne le label de date approprié selon le type de produit
  String _getDateLabel(TypeProduit typeProduit) {
    switch (typeProduit) {
      case TypeProduit.recu:
        return 'Date reception';
      case TypeProduit.fini:
        return 'Date fabrication';
      case TypeProduit.prepare:
        return 'Date preparation';
      case TypeProduit.ouverture:
        return 'Date ouverture';
      case TypeProduit.decongelation:
        return 'Date decongel';
    }
  }

  String _getConservationText(TypeProduit typeProduit, bool isSurgel) {
    if (isSurgel) {
      return '-18 degres';
    }

    switch (typeProduit) {
      case TypeProduit.recu:
        return '+4 degres';
      case TypeProduit.fini:
        return '+4 degres';
      case TypeProduit.prepare:
        return '+4 degres';
      case TypeProduit.ouverture:
        return '+4 degres';
      case TypeProduit.decongelation:
        return '+4 degres';
    }
  }

  Future<void> printEtiquette(Produit produit) async {
    // Vérifier le nombre d'étiquettes
    final nombreEtiquettes =
        int.tryParse(_nombreEtiquettesController.text.trim()) ?? 1;
    if (nombreEtiquettes < 1 || nombreEtiquettes > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nombre d\'étiquettes doit être entre 1 et 100'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Demander le nom du fabricant pour les produits finis
    String? fabricant;
    if (produit.typeProduit == TypeProduit.fini) {
      final fabricantController = TextEditingController(text: "KDOUKH DELICE");
      final fabricantResult = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Nom du fabricant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Voulez-vous utiliser "KDOUKH DELICE" ou changer le nom du fabricant ?',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fabricantController,
                  decoration: InputDecoration(
                    labelText: 'Nom du fabricant',
                    border: OutlineInputBorder(),
                    hintText: 'KDOUKH DELICE',
                  ),
                  inputFormatters: [ZplSafeTextInputFormatter()],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, "KDOUKH DELICE"),
                child: Text(
                  'Utiliser KDOUKH DELICE',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final nom = fabricantController.text.trim();
                  if (nom.isNotEmpty) {
                    Navigator.pop(context, nom);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Le nom du fabricant ne peut pas être vide'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text('Confirmer'),
              ),
            ],
          );
        },
      );

      if (fabricantResult == null) {
        return; // L'utilisateur a annulé
      }
      fabricant = fabricantResult;
    }

    setState(() => isPrinting = true);

    try {
      // Calculer la DLC selon le type de produit
      DateTime dlc;
      if (_isSurgel) {
        // Pour les produits surgelés, DLC = date de surgélation + DLC du produit
        final dlcJours = produit.dlcSurgelationJours ??
            produit.dlcJours ??
            produit.typeProduit.dlcParDefaut;
        dlc = _selectedDateSurgelation.add(Duration(days: dlcJours));
      } else {
        // Pour les produits frais, utiliser la DLC spécifique ou la DLC par défaut du type
        final dlcJours = produit.dlcJours ?? produit.typeProduit.dlcParDefaut;
        dlc = _selectedDateFabrication.add(Duration(days: dlcJours));
      }

      final lot = _lotController.text.trim().isNotEmpty
          ? _lotController.text.trim()
          : '';

      // Générer le ZPL
      final zpl = await generateZplEtiquette(
        produit: produit,
        lot: lot,
        poids: double.tryParse(_poidsController.text.trim()) ?? 0.0,
        fabrication: _selectedDateFabrication,
        dlc: dlc,
        preparateur: _preparateurController.text.trim(),
        isSurgel: _isSurgel,
        dateSurgelation: _selectedDateSurgelation,
        showLogo: _showLogo,
        fabricant: fabricant ??
            "KDOUKH DELICE", // Utiliser le nom choisi ou par défaut
      );

      // Imprimer avec le service robuste
      final success = await _bluetoothService
          .printMultipleLabels(zpl, nombreEtiquettes, context: context);

      if (success) {
        if (!_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Network required to save print history')),
          );
          return;
        }

        // Save print history
        try {
          final dlcStr = DateFormat('dd/MM/yyyy').format(dlc);
          await _labelsRepo.createPrintHistory(
            productId: produit.id,
            productName: produit.nom,
            lot: lot,
            weight: _poidsController.text.trim(),
            preparedBy: _preparateurController.text.trim(),
            manufacturedAt: _selectedDateFabrication.toIso8601String(),
            dlc: dlcStr,
            dluo: _utiliseDluo && _dluoController.text.isNotEmpty
                ? _dluoController.text.trim()
                : null,
            zpl: zpl,
            status: 'success',
          );
        } catch (e) {
          debugPrint('⚠️ [Étiquettes] Erreur sauvegarde historique: $e');
        }

        // Mettre à jour le produit avec les détails d'impression
        try {
          // Note: ProductsRepository.updateProduct doesn't support preparateur/heurePreparation/dluo yet
          // These fields would need to be added to the schema or stored separately
          await _productsRepo.updateProduct(
            produit.id,
            lot: lot,
            poids: double.tryParse(_poidsController.text.trim()) ?? 0.0,
            dateFabrication: _selectedDateFabrication,
          );
        } catch (e) {
          debugPrint('⚠️ [Étiquettes] Erreur mise à jour produit: $e');
        }

        // Réinitialiser le formulaire
        _resetForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'impression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isPrinting = false);
    }
  }

  void _resetForm() {
    _lotController.clear();
    _poidsController.clear();
    _preparateurController.clear();
    _dluoController.clear();
    _nombreEtiquettesController.text = '1';
    _fabricantController.clear();
    _selectedDateFabrication = DateTime.now();
    _selectedHeurePreparation = TimeOfDay.now();
    _selectedDateSurgelation = DateTime.now();
    _dlcJourMeme = false;
    _utiliseDluo = false;
    _isSurgel = false;
    _showLogo = true;
    selectedProduit = null;
    setState(() {
      showPreparationForm = false;
    });
  }

  Future<void> _addProduit() async {
    TypeProduit localSelectedType = _selectedTypeProduit;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Nouveau produit'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _newProduitController,
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
                            _dlcJoursController.text =
                                type.dlcParDefaut.toString();
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                      DescriptionInputFormatter(maxLength: 200)
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
                      DescriptionInputFormatter(maxLength: 100)
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
                if (_newProduitController.text.trim().isNotEmpty) {
                  final dlcJours =
                      int.tryParse(_dlcJoursController.text.trim()) ?? 0;
                  final dlcSurgelation =
                      int.tryParse(_dlcSurgelationController.text.trim()) ?? 0;
                  Navigator.pop(context, {
                    'nom': _newProduitController.text.trim(),
                    'typeProduit': localSelectedType,
                    'dlcJours': dlcJours,
                    'dlcSurgelationJours': dlcSurgelation,
                    'ingredients': _ingredientsController.text.trim().isNotEmpty
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
        final typeProduit = result['typeProduit'] as TypeProduit? ?? TypeProduit.fini;
        await _productsRepo.createProduct(
          nom: result['nom']?.toString() ?? '',
          typeProduit: typeProduit.name,
          dlcJours: result['dlcJours'] as int?,
          dateFabrication: DateTime.now(),
          surgelagable: false,
          dlcSurgelationJours: result['dlcSurgelationJours'] as int?,
          ingredients: result['ingredients']?.toString(),
          quantite: result['quantite']?.toString(),
          origineViande: result['origineViande']?.toString(),
          allergenes: result['allergenes']?.toString(),
        );

        await loadProduits();

        final newProduit = produits.firstWhere((p) => p.nom == result['nom']);
        setState(() {
          selectedProduit = newProduit;
          showPreparationForm = true;
        });

        _newProduitController.clear();
        _dlcJoursController.clear();
        _dlcSurgelationController.clear();
        _ingredientsController.clear();
        _quantiteController.clear();
        _origineViandeController.clear();
        _allergenesController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit "${result['nom']}" ajouté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout du produit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showProduitsList() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gestion des produits'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                'Liste des produits (${produits.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: produits.isEmpty
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
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: produits.length,
                        itemBuilder: (context, index) {
                          final produit = produits[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(
                                produit.nom,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'DLC: +${produit.dlcJours ?? 0} jours',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit,
                                        color: Colors.blue.shade400),
                                    onPressed: () => _editProduit(produit),
                                    tooltip: 'Modifier le produit',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete,
                                        color: Colors.red.shade400),
                                    onPressed: () => _deleteProduit(produit),
                                    tooltip: 'Supprimer le produit',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduit(Produit produit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmation'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer le produit "${produit.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!_isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network required')),
        );
        return;
      }

      try {
        await _productsRepo.deleteProduct(produit.id);

        await loadProduits();

        if (selectedProduit?.id == produit.id) {
          setState(() {
            selectedProduit = null;
            showPreparationForm = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit "${produit.nom}" supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur: ${e is AppException ? e.message : e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editProduit(Produit produit) async {
    // Pré-remplir les contrôleurs avec les données du produit
    _newProduitController.text = produit.nom;
    _dlcJoursController.text = produit.dlcJours?.toString() ?? '';
    _dlcSurgelationController.text =
        produit.dlcSurgelationJours?.toString() ?? '';
    _ingredientsController.text = produit.ingredients ?? '';
    _quantiteController.text = produit.quantite ?? '';
    _origineViandeController.text = produit.origineViande ?? '';
    _allergenesController.text = produit.allergenes ?? '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier le produit'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newProduitController,
                  decoration: InputDecoration(
                    labelText: 'Nom du produit *',
                    border: OutlineInputBorder(),
                    helperText: 'Caractères spéciaux automatiquement corrigés',
                  ),
                  inputFormatters: [ProductNameInputFormatter()],
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
                  inputFormatters: [DescriptionInputFormatter(maxLength: 200)],
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
                  inputFormatters: [DescriptionInputFormatter(maxLength: 100)],
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
              if (_newProduitController.text.trim().isNotEmpty) {
                final dlcJours =
                    int.tryParse(_dlcJoursController.text.trim()) ?? 0;
                final dlcSurgelation =
                    int.tryParse(_dlcSurgelationController.text.trim()) ?? 0;
                Navigator.pop(context, {
                  'nom': _newProduitController.text.trim(),
                  'dlcJours': dlcJours,
                  'dlcSurgelationJours': dlcSurgelation,
                  'ingredients': _ingredientsController.text.trim().isNotEmpty
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
            child: Text('Modifier'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Créer un nouveau produit avec les données modifiées
        final updatedProduit = produit.copyWith(
          nom: result['nom'],
          dlcJours: result['dlcJours'],
          dlcSurgelationJours: result['dlcSurgelationJours'],
          ingredients: result['ingredients'],
          quantite: result['quantite'],
          origineViande: result['origineViande'],
          allergenes: result['allergenes'],
        );

        if (!_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network required')),
          );
          return;
        }

        // Mettre à jour dans la base de données
        try {
          await _productsRepo.updateProduct(
            produit.id,
            nom: result['nom']?.toString(),
            dlcJours: result['dlcJours'] as int?,
            dlcSurgelationJours: result['dlcSurgelationJours'] as int?,
            ingredients: result['ingredients']?.toString(),
            quantite: result['quantite']?.toString(),
            origineViande: result['origineViande']?.toString(),
            allergenes: result['allergenes']?.toString(),
          );

          await loadProduits();

          // Mettre à jour le produit sélectionné si c'est celui qui a été modifié
          if (selectedProduit?.id == produit.id) {
            final updatedProduitFromList =
                produits.firstWhere((p) => p.id == produit.id);
            setState(() {
              selectedProduit = updatedProduitFromList;
            });
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Erreur: ${e is AppException ? e.message : e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Réinitialiser les contrôleurs
        _newProduitController.clear();
        _dlcJoursController.clear();
        _dlcSurgelationController.clear();
        _ingredientsController.clear();
        _quantiteController.clear();
        _origineViandeController.clear();
        _allergenesController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit "${result['nom']}" modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la modification du produit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Impression Étiquettes Zebra'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Bluetooth
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Imprimante Bluetooth',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BluetoothDevice>(
                      value: selectedDevice,
                      decoration: const InputDecoration(
                        labelText: 'Sélectionner une imprimante',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                      items: devices.map((device) {
                        return DropdownMenuItem<BluetoothDevice>(
                          value: device,
                          child: Text(
                            device.name ?? 'Appareil inconnu',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (device) async {
                        setState(() {
                          selectedDevice = device;
                        });

                        if (device != null) {
                          final success = await _bluetoothService
                              .connectToDevice(device, context: context);
                          if (success) {
                            setState(() {
                              selectedDevice = device;
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section Produit
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sélection du Produit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: DropdownButtonFormField<Produit>(
                        value: selectedProduit,
                        decoration: const InputDecoration(
                          labelText: 'Sélectionner un produit *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory, size: 28),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 30, horizontal: 20),
                        ),
                        isExpanded: true,
                        menuMaxHeight: 400,
                        selectedItemBuilder: (context) {
                          return produits.map((produit) {
                            final dlcInfo = (produit.dlcJours ?? 0) > 0
                                ? ' (DLC: +${produit.dlcJours}j)'
                                : '';
                            return Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${produit.nom}$dlcInfo',
                                style: const TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList();
                        },
                        items: produits.map((produit) {
                          final dlcInfo = (produit.dlcJours ?? 0) > 0
                              ? ' (DLC: +${produit.dlcJours}j)'
                              : '';
                          return DropdownMenuItem<Produit>(
                            value: produit,
                            child: Text(
                              '${produit.nom}$dlcInfo',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (produit) {
                          setState(() {
                            selectedProduit = produit;
                            showPreparationForm = produit != null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showProduitsList,
                        icon: const Icon(Icons.list),
                        label: Text('Gérer les produits',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section Préparation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.print, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Préparation et Impression',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              showPreparationForm = !showPreparationForm;
                            });
                          },
                          icon: Icon(showPreparationForm
                              ? Icons.expand_less
                              : Icons.expand_more),
                          label: Text(
                              showPreparationForm ? 'Masquer' : 'Afficher'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (showPreparationForm) ...[
                      const SizedBox(height: 16),

                      // Indicateur de logo
                      Card(
                        color: _logoAvailable
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                _logoAvailable
                                    ? Icons.image
                                    : Icons.image_not_supported,
                                color: _logoAvailable
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Logo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _logoAvailable
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                    Text(
                                      _logoAvailable
                                          ? 'Logo intégré - sera inclus dans l\'étiquette'
                                          : 'Logo non disponible',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _logoAvailable
                                            ? Colors.green.shade600
                                            : Colors.orange.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_logoAvailable) ...[
                                const SizedBox(width: 8),
                                Switch(
                                  value: _showLogo,
                                  onChanged: (value) {
                                    setState(() {
                                      _showLogo = value;
                                    });
                                  },
                                  activeColor: Colors.green,
                                ),
                                Text(
                                  _showLogo ? 'Oui' : 'Non',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _showLogo
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: TextFormField(
                                controller: _lotController,
                                decoration: const InputDecoration(
                                  labelText: 'Numéro de lot *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.qr_code, size: 28),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 25, horizontal: 20),
                                ),
                                inputFormatters: [LotNumberInputFormatter()],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Obligatoire';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: TextFormField(
                                controller: _poidsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Poids (kg)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.scale, size: 28),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 25, horizontal: 20),
                                ),
                                inputFormatters: [WeightInputFormatter()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(selectedProduit != null
                            ? _getDateLabel(selectedProduit!.typeProduit)
                            : 'Date de fabrication'),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy')
                              .format(_selectedDateFabrication),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDateFabrication,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 30)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDateFabrication = date;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('Produit surgelé ?'),
                        subtitle: Text(
                          selectedProduit?.dlcSurgelationJours != null
                              ? 'DLC: +${selectedProduit!.dlcSurgelationJours} jours'
                              : selectedProduit?.dlcJours != null
                                  ? 'DLC: +${selectedProduit!.dlcJours} jours'
                                  : 'DLC: +3 jours après décongélation',
                        ),
                        value: _isSurgel,
                        onChanged: (value) {
                          setState(() {
                            _isSurgel = value;
                            if (value &&
                                _selectedDateSurgelation == DateTime.now()) {
                              _selectedDateSurgelation =
                                  _selectedDateFabrication;
                            }
                          });
                        },
                        secondary: Icon(
                          _isSurgel ? Icons.ac_unit : Icons.ac_unit_outlined,
                          color: _isSurgel ? Colors.blue : Colors.grey,
                        ),
                      ),

                      if (_isSurgel) ...[
                        const SizedBox(height: 16),
                        ListTile(
                          leading:
                              const Icon(Icons.ac_unit, color: Colors.blue),
                          title: const Text('Date de surgélation'),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy')
                                .format(_selectedDateSurgelation),
                          ),
                          trailing: const Icon(Icons.edit),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDateSurgelation,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDateSurgelation = date;
                              });
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 80,
                        child: TextFormField(
                          controller: _preparateurController,
                          decoration: const InputDecoration(
                            labelText: 'Préparateur (optionnel)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, size: 28),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 25, horizontal: 20),
                          ),
                          inputFormatters: [ZplSafeTextInputFormatter()],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: TextFormField(
                                controller: _nombreEtiquettesController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre d\'étiquettes',
                                  border: OutlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.confirmation_number, size: 28),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 25, horizontal: 20),
                                ),
                                inputFormatters: [
                                  IntegerInputFormatter(maxValue: 100)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        onPressed: selectedProduit != null && !isPrinting
                            ? () {
                                printEtiquette(selectedProduit!);
                              }
                            : null,
                        icon: isPrinting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print),
                        label: Text(isPrinting
                            ? 'Impression...'
                            : 'Imprimer l\'étiquette'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
