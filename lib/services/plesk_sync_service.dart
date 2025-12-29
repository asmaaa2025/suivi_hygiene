import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database_helper.dart';
import 'api_service.dart';

class PleskSyncService {
  static final PleskSyncService _instance = PleskSyncService._internal();
  factory PleskSyncService() => _instance;
  PleskSyncService._internal();

  Timer? _syncTimer;
  final List<Map<String, dynamic>> _pendingSyncs = [];
  bool _isSyncing = false;

  // Configuration Plesk
  static const String pleskBaseUrl =
      'http://192.168.1.69:8001/api'; // IP réelle de votre Mac
  static const String pleskLoginUrl = '$pleskBaseUrl/auth/login/';
  static const String pleskTemperaturesUrl = '$pleskBaseUrl/temperatures/';
  static const String pleskAppareilsUrl = '$pleskBaseUrl/appareils/';
  static const String pleskReceptionsUrl = '$pleskBaseUrl/receptions/';
  static const String pleskProduitsUrl = '$pleskBaseUrl/produits/';
  static const String pleskFournisseursUrl = '$pleskBaseUrl/fournisseurs/';

  /// Démarre la synchronisation automatique
  Future<void> startAutoSync() async {
    print('🔄 Démarrage de la synchronisation automatique avec Plesk...');

    // Arrêter tout timer existant
    _syncTimer?.cancel();

    // Synchronisation immédiate
    await _syncAllData();

    // Synchronisation périodique toutes les 15 secondes
    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _syncAllData(),
    );

    print('✅ Synchronisation automatique configurée (toutes les 15 secondes)');
  }

  /// Arrête la synchronisation automatique
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('⏹️ Synchronisation automatique arrêtée');
  }

  /// Synchronise toutes les données
  Future<void> _syncAllData() async {
    if (_isSyncing) return;

    _isSyncing = true;
    print('🔄 Début de la synchronisation avec Plesk...');

    try {
      // 1. Vérifier la connexion à Plesk
      final isConnected = await _checkPleskConnection();
      if (!isConnected) {
        print('❌ Impossible de se connecter à Plesk');
        return;
      }

      // 2. Synchroniser les températures
      await _syncTemperatures();

      // 3. Synchroniser les appareils
      await _syncAppareils();

      // 4. Synchroniser les réceptions
      await _syncReceptions();

      // 5. Synchroniser les données en attente
      await _syncPendingData();

      print('✅ Synchronisation avec Plesk terminée');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Vérifie la connexion à Plesk
  Future<bool> _checkPleskConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$pleskBaseUrl/hello/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur de connexion Plesk: $e');
      return false;
    }
  }

  /// Synchronise les températures
  Future<void> _syncTemperatures() async {
    try {
      // Récupérer les températures locales non synchronisées
      final localTemperatures = await DatabaseHelper.instance.getReleves();

      for (final temp in localTemperatures) {
        // Vérifier si déjà synchronisé
        final isSynced = await _isTemperatureSynced(temp['id'] as String);
        if (isSynced) continue;

        // Synchroniser avec Plesk
        await _syncTemperatureToPlesk(temp);
      }
    } catch (e) {
      print('❌ Erreur synchronisation températures: $e');
    }
  }

  /// Synchronise les appareils
  Future<void> _syncAppareils() async {
    try {
      // Récupérer les appareils locaux
      final localAppareils = await DatabaseHelper.instance.getAppareils();

      for (final appareil in localAppareils) {
        // Vérifier si déjà synchronisé
        final isSynced = await _isAppareilSynced(appareil['id']);
        if (isSynced) continue;

        // Synchroniser avec Plesk
        await _syncAppareilToPlesk(appareil);
      }
    } catch (e) {
      print('❌ Erreur synchronisation appareils: $e');
    }
  }

  /// Récupère ou crée un appareil dans Django et retourne son ID
  Future<int?> _getOrCreateAppareil(String nomAppareil, String token) async {
    try {
      // 1. Récupérer tous les appareils et chercher par nom
      final getResponse = await http.get(
        Uri.parse(pleskAppareilsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode == 200) {
        final appareils = json.decode(getResponse.body) as List;
        // Chercher l'appareil par nom
        for (final appareil in appareils) {
          if (appareil['nom'] == nomAppareil) {
            return appareil['id'] as int;
          }
        }
      }

      // 2. Si l'appareil n'existe pas, le créer
      print('📝 Création de l\'appareil: $nomAppareil');
      final createResponse = await http
          .post(
            Uri.parse(pleskAppareilsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'nom': nomAppareil,
              'type_appareil': 'autre', // Par défaut
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (createResponse.statusCode == 201) {
        final appareil = json.decode(createResponse.body);
        print('✅ Appareil créé: $nomAppareil (ID: ${appareil['id']})');
        return appareil['id'] as int;
      }

      print(
          '❌ Impossible de créer l\'appareil: ${createResponse.statusCode} - ${createResponse.body}');
      return null;
    } catch (e) {
      print('❌ Erreur getOrCreateAppareil: $e');
      return null;
    }
  }

  /// Synchronise une température vers Plesk
  Future<void> _syncTemperatureToPlesk(dynamic temperature) async {
    try {
      final token = await _getPleskToken();
      if (token == null) {
        print('❌ Token Plesk non disponible');
        return;
      }

      // 1. Récupérer ou créer l'appareil et obtenir son ID
      final appareilId =
          await _getOrCreateAppareil(temperature.appareil, token);
      if (appareilId == null) {
        print(
            '❌ Impossible de récupérer/créer l\'appareil: ${temperature.appareil}');
        return;
      }

      // 2. Créer la température avec l'ID de l'appareil
      final response = await http
          .post(
            Uri.parse(pleskTemperaturesUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'appareil': appareilId, // ID de l'appareil, pas le nom
              'temperature': temperature.temperature.toStringAsFixed(
                  2), // Formater avec 2 décimales max (max_digits=5, decimal_places=2)
              'remarque': temperature.remarque ?? '',
              // Note: 'date' n'est pas nécessaire, Django le gère automatiquement avec auto_now_add
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            '✅ Température synchronisée vers Plesk: ${temperature.appareil} - ${temperature.temperature}°C');
        await _markTemperatureAsSynced(temperature.id);
      } else {
        print(
            '❌ Erreur synchronisation température: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur sync température: $e');
    }
  }

  /// Synchronise un appareil vers Plesk
  Future<void> _syncAppareilToPlesk(Map<String, dynamic> appareil) async {
    try {
      final token = await _getPleskToken();
      if (token == null) return;

      final nomAppareil = appareil['nom'];

      // 1. Vérifier si l'appareil existe déjà dans Django
      final getResponse = await http.get(
        Uri.parse(pleskAppareilsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode == 200) {
        final appareils = json.decode(getResponse.body) as List;
        // Chercher l'appareil par nom
        for (final app in appareils) {
          if (app['nom'] == nomAppareil) {
            print(
                'ℹ️ Appareil déjà présent dans Plesk: $nomAppareil (ID: ${app['id']})');
            await _markAppareilAsSynced(appareil['id']);
            return; // L'appareil existe déjà, pas besoin de le créer
          }
        }
      }

      // 2. Si l'appareil n'existe pas, le créer
      print('📝 Création de l\'appareil: $nomAppareil');

      // Valider le type d'appareil (doit être un des choix Django)
      final validTypes = ['frigo', 'congela', 'friteuse', 'autre'];
      final typeAppareil =
          appareil['type_appareil']?.toString().toLowerCase() ?? 'autre';
      final validatedType =
          validTypes.contains(typeAppareil) ? typeAppareil : 'autre';

      // Construire le payload avec seulement les champs non-null
      final payload = <String, dynamic>{
        'nom': nomAppareil,
        'type_appareil': validatedType,
      };

      // Ajouter les champs optionnels seulement s'ils existent
      if (appareil['seuil_min'] != null) {
        final seuilMin = appareil['seuil_min'];
        if (seuilMin is num) {
          payload['seuil_min'] = seuilMin.toStringAsFixed(2);
        } else {
          payload['seuil_min'] = seuilMin.toString();
        }
      }
      if (appareil['seuil_max'] != null) {
        final seuilMax = appareil['seuil_max'];
        if (seuilMax is num) {
          payload['seuil_max'] = seuilMax.toStringAsFixed(2);
        } else {
          payload['seuil_max'] = seuilMax.toString();
        }
      }
      if (appareil['description'] != null &&
          appareil['description'].toString().isNotEmpty) {
        payload['description'] = appareil['description'];
      }

      final createResponse = await http
          .post(
            Uri.parse(pleskAppareilsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (createResponse.statusCode == 201 ||
          createResponse.statusCode == 200) {
        print('✅ Appareil créé/synchronisé vers Plesk: $nomAppareil');
        await _markAppareilAsSynced(appareil['id']);
      } else {
        print(
            '❌ Erreur synchronisation appareil: ${createResponse.statusCode} - ${createResponse.body}');
        // Si l'erreur est "already exists", marquer quand même comme synchronisé
        if (createResponse.body.contains('already exists')) {
          print('ℹ️ Appareil déjà présent, marqué comme synchronisé');
          await _markAppareilAsSynced(appareil['id']);
        }
      }
    } catch (e) {
      print('❌ Erreur sync appareil: $e');
    }
  }

  /// Récupère le token d'authentification Plesk
  Future<String?> _getPleskToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('plesk_token');

      if (token != null) {
        // Vérifier si le token est encore valide
        final isValid = await _validateToken(token);
        if (isValid) return token;
      }

      // Se connecter à Plesk
      // Load credentials from environment variables
      final username =
          const String.fromEnvironment('PLESK_USERNAME', defaultValue: '');
      final password =
          const String.fromEnvironment('PLESK_PASSWORD', defaultValue: '');

      if (username.isEmpty || password.isEmpty) {
        throw Exception(
            'Plesk credentials not configured. Set PLESK_USERNAME and PLESK_PASSWORD environment variables.');
      }

      final response = await http
          .post(
            Uri.parse(pleskLoginUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['access'];
        await prefs.setString('plesk_token', newToken);
        return newToken;
      }

      return null;
    } catch (e) {
      print('❌ Erreur authentification Plesk: $e');
      return null;
    }
  }

  /// Valide un token
  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$pleskBaseUrl/auth/verify/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Récupère ou crée un fournisseur dans Django et retourne son ID
  Future<int?> _getOrCreateFournisseur(
      String nomFournisseur, String token) async {
    try {
      // 1. Récupérer tous les fournisseurs et chercher par nom
      final getResponse = await http.get(
        Uri.parse(pleskFournisseursUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode == 200) {
        final fournisseurs = json.decode(getResponse.body) as List;
        // Chercher le fournisseur par nom
        for (final fournisseur in fournisseurs) {
          if (fournisseur['nom'] == nomFournisseur) {
            return fournisseur['id'] as int;
          }
        }
      }

      // 2. Si le fournisseur n'existe pas, le créer
      print('📝 Création du fournisseur: $nomFournisseur');
      final createResponse = await http
          .post(
            Uri.parse(pleskFournisseursUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'nom': nomFournisseur,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (createResponse.statusCode == 201) {
        final fournisseur = json.decode(createResponse.body);
        print('✅ Fournisseur créé: $nomFournisseur (ID: ${fournisseur['id']})');
        return fournisseur['id'] as int;
      }

      print(
          '❌ Impossible de créer le fournisseur: ${createResponse.statusCode} - ${createResponse.body}');
      return null;
    } catch (e) {
      print('❌ Erreur getOrCreateFournisseur: $e');
      return null;
    }
  }

  /// Récupère ou crée un produit dans Django et retourne son ID
  Future<int?> _getOrCreateProduit(
      String nomProduit, int fournisseurId, String token) async {
    try {
      // 1. Récupérer tous les produits et chercher par nom et fournisseur
      final getResponse = await http.get(
        Uri.parse(pleskProduitsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode == 200) {
        final produits = json.decode(getResponse.body) as List;
        // Chercher le produit par nom et fournisseur
        for (final produit in produits) {
          if (produit['nom'] == nomProduit &&
              produit['fournisseur'] == fournisseurId) {
            print('ℹ️ Produit trouvé: $nomProduit (ID: ${produit['id']})');
            return produit['id'] as int;
          }
        }
      }

      // 2. Si le produit n'existe pas, le créer
      print('📝 Création du produit: $nomProduit');
      final createResponse = await http
          .post(
            Uri.parse(pleskProduitsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'nom': nomProduit,
              'fournisseur': fournisseurId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (createResponse.statusCode == 201) {
        final produit = json.decode(createResponse.body);
        print('✅ Produit créé: $nomProduit (ID: ${produit['id']})');
        return produit['id'] as int;
      }

      print(
          '❌ Impossible de créer le produit: ${createResponse.statusCode} - ${createResponse.body}');
      return null;
    } catch (e) {
      print('❌ Erreur getOrCreateProduit: $e');
      return null;
    }
  }

  /// Synchronise les réceptions
  Future<void> _syncReceptions() async {
    try {
      // Récupérer les réceptions locales non synchronisées
      final localReceptions = await DatabaseHelper.instance.getReceptions();
      print('📦 Réceptions locales trouvées: ${localReceptions.length}');

      if (localReceptions.isEmpty) {
        print('ℹ️ Aucune réception locale à synchroniser');
        return;
      }

      for (final reception in localReceptions) {
        print(
            '🔄 Traitement réception: ${reception['article']} - ${reception['fournisseur']}');

        // Vérifier si déjà synchronisé
        final isSynced = await _isReceptionSynced(reception['id']);
        if (isSynced) {
          print('ℹ️ Réception déjà synchronisée: ${reception['id']}');
          continue;
        }

        // Synchroniser avec Plesk
        await _syncReceptionToPlesk(reception);
      }
    } catch (e) {
      print('❌ Erreur synchronisation réceptions: $e');
    }
  }

  /// Synchronise une réception vers Plesk
  Future<void> _syncReceptionToPlesk(Map<String, dynamic> reception) async {
    try {
      print('🔄 Début synchronisation réception: ${reception['id']}');

      final token = await _getPleskToken();
      if (token == null) {
        print('❌ Token Plesk non disponible');
        return;
      }
      print('✅ Token Plesk obtenu');

      final fournisseurNom = reception['fournisseur'] as String? ?? '';
      final produitNom = reception['article'] as String? ??
          reception['produit'] as String? ??
          '';

      print('📝 Fournisseur: $fournisseurNom, Produit: $produitNom');

      if (fournisseurNom.isEmpty || produitNom.isEmpty) {
        print('❌ Réception invalide: fournisseur ou produit manquant');
        print('   Données réception: $reception');
        return;
      }

      // 1. Récupérer ou créer le fournisseur
      print('🔄 Récupération/création fournisseur: $fournisseurNom');
      final fournisseurId =
          await _getOrCreateFournisseur(fournisseurNom, token);
      if (fournisseurId == null) {
        print(
            '❌ Impossible de récupérer/créer le fournisseur: $fournisseurNom');
        return;
      }
      print('✅ Fournisseur ID: $fournisseurId');

      // 2. Récupérer ou créer le produit
      print('🔄 Récupération/création produit: $produitNom');
      final produitId =
          await _getOrCreateProduit(produitNom, fournisseurId, token);
      if (produitId == null) {
        print('❌ Impossible de récupérer/créer le produit: $produitNom');
        return;
      }
      print('✅ Produit ID: $produitId');

      // 3. Créer la réception
      final quantite =
          double.tryParse(reception['quantite']?.toString() ?? '0') ?? 0.0;
      final conforme =
          reception['conforme'] == 1 || reception['conforme'] == true;

      print(
          '🔄 Création réception: Produit=$produitId, Quantité=$quantite, Conforme=$conforme');

      final response = await http
          .post(
            Uri.parse(pleskReceptionsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'produit': produitId,
              'quantite': quantite.toStringAsFixed(2),
              'conforme': conforme,
              'remarque': reception['remarque']?.toString() ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 Réponse serveur: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Réception synchronisée vers Plesk: $produitNom - $quantite');
        await _markReceptionAsSynced(reception['id']);
      } else {
        print(
            '❌ Erreur synchronisation réception: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ Erreur sync réception: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  /// Vérifie si une réception est synchronisée
  Future<bool> _isReceptionSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reception_synced_$id') ?? false;
  }

  /// Marque une réception comme synchronisée
  Future<void> _markReceptionAsSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reception_synced_$id', true);
  }

  /// Synchronise les données en attente
  Future<void> _syncPendingData() async {
    while (_pendingSyncs.isNotEmpty) {
      final item = _pendingSyncs.removeAt(0);
      // Logique de synchronisation des données en attente
      print('🔄 Synchronisation donnée en attente: ${item['type']}');

      // Traiter les différents types de données en attente
      if (item['type'] == 'reception') {
        await _syncReceptionToPlesk(item['data']);
      } else if (item['type'] == 'temperature') {
        // Déjà géré par _syncTemperatures
        print('ℹ️ Température déjà synchronisée par _syncTemperatures');
      }
    }
  }

  /// Vérifie si une température est synchronisée
  Future<bool> _isTemperatureSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('temp_synced_$id') ?? false;
  }

  /// Marque une température comme synchronisée
  Future<void> _markTemperatureAsSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('temp_synced_$id', true);
  }

  /// Vérifie si un appareil est synchronisé
  Future<bool> _isAppareilSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('appareil_synced_$id') ?? false;
  }

  /// Marque un appareil comme synchronisé
  Future<void> _markAppareilAsSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appareil_synced_$id', true);
  }

  /// Force une synchronisation immédiate
  Future<void> forceSync() async {
    print('🔄 Synchronisation forcée avec Plesk...');
    await _syncAllData();
  }

  /// Ajoute une donnée à la file de synchronisation
  void addToSyncQueue(String type, Map<String, dynamic> data) {
    _pendingSyncs.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print('📝 Donnée ajoutée à la file de synchronisation: $type');
  }
}
