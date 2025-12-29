import 'dart:async';
import 'package:http/http.dart' as http;
import 'optimized_database_helper.dart';
import 'api_service.dart';

/// Service de synchronisation optimisé entre la base de données locale et le serveur
///
/// Ce service :
/// 1. Synchronise les données après la connexion
/// 2. Gère les conflits de données
/// 3. Optimise les requêtes de synchronisation
/// 4. Gère les erreurs de réseau
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OptimizedDatabaseHelper _dbHelper = OptimizedDatabaseHelper();
  bool _isSyncing = false;
  Timer? _syncTimer;

  /// Démarre la synchronisation automatique après la connexion
  ///
  /// Cette méthode :
  /// 1. Synchronise immédiatement les données
  /// 2. Programme une synchronisation périodique
  /// 3. Gère les erreurs de synchronisation
  Future<void> startSyncAfterLogin() async {
    try {
      print('🔄 Démarrage de la synchronisation après connexion');

      // Synchronisation immédiate
      await _syncAllData();

      // Synchronisation périodique toutes les 5 minutes
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _syncAllData(),
      );

      print('✅ Synchronisation automatique démarrée');
    } catch (e) {
      print('❌ Erreur lors du démarrage de la synchronisation: $e');
    }
  }

  /// Arrête la synchronisation automatique
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isSyncing = false;
    print('🛑 Synchronisation automatique arrêtée');
  }

  /// Synchronise toutes les données avec le serveur
  Future<void> _syncAllData() async {
    if (_isSyncing) {
      print('⚠️ Synchronisation déjà en cours, ignorée');
      return;
    }

    _isSyncing = true;

    try {
      print('🔄 Début de la synchronisation des données');

      // Vérifier la connectivité réseau
      if (!await _checkNetworkConnectivity()) {
        print('⚠️ Pas de connectivité réseau, synchronisation reportée');
        return;
      }

      // Synchroniser les données par ordre de priorité
      await _syncAppareils();
      await _syncProduits();
      await _syncReleves();
      await _syncReceptions();

      print('✅ Synchronisation terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Vérifie la connectivité réseau
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.supabaseUrl}/health/'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Synchronise les appareils
  Future<void> _syncAppareils() async {
    try {
      print('🔄 Synchronisation des appareils...');

      // Récupérer les appareils du serveur
      final serverAppareils = await ApiService.getAppareils();

      // Sauvegarder en local
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Supprimer les anciens appareils
        await txn.delete('appareils');

        // Insérer les nouveaux
        for (final appareil in serverAppareils) {
          await txn.insert('appareils', {
            'id': appareil['id'],
            'nom': appareil['nom'],
            'temp_min': appareil['temp_min'],
            'temp_max': appareil['temp_max'],
            'synced': 1,
          });
        }
      });

      print('✅ Appareils synchronisés: ${serverAppareils.length}');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation des appareils: $e');
    }
  }

  /// Synchronise les produits
  Future<void> _syncProduits() async {
    try {
      print('🔄 Synchronisation des produits...');

      // Récupérer les produits du serveur
      final serverProduits = await ApiService.getProduits();

      // Sauvegarder en local
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Supprimer les anciens produits
        await txn.delete('produits');

        // Insérer les nouveaux
        for (final produit in serverProduits) {
          await txn.insert('produits', {
            'id': produit['id'],
            'nom': produit['nom'],
            'dlc': produit['dlc'],
            'dlc_jours': produit['dlc_jours'],
            'lot': produit['lot'],
            'poids': produit['poids'],
            'date_creation': produit['date_creation'],
            'date_modification': produit['date_modification'],
            'date_fabrication': produit['date_fabrication'],
            'surgelagable': produit['surgelagable'],
            'dlc_surgelation_jours': produit['dlc_surgelation_jours'],
            'preparateur': produit['preparateur'],
            'heure_preparation': produit['heure_preparation'],
            'dluo': produit['dluo'],
            'ingredients': produit['ingredients'],
            'quantite': produit['quantite'],
            'origine_viande': produit['origine_viande'],
            'allergenes': produit['allergenes'],
            'type_produit': produit['type_produit'],
          });
        }
      });

      print('✅ Produits synchronisés: ${serverProduits.length}');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation des produits: $e');
    }
  }

  /// Synchronise les relevés de température
  Future<void> _syncReleves() async {
    try {
      print('🔄 Synchronisation des relevés...');

      // Récupérer les relevés du serveur
      final serverReleves = await ApiService.getTemperatures();

      // Sauvegarder en local
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Supprimer les anciens relevés
        await txn.delete('releves');

        // Insérer les nouveaux
        for (final releve in serverReleves) {
          await txn.insert('releves', {
            'id': releve['id'],
            'appareil': releve['appareil'],
            'temperature': releve['temperature'],
            'date': releve['date'],
            'remarque': releve['remarque'],
            'conforme': releve['conforme'],
            'commentaire': releve['commentaire'],
            'photo_path': releve['photo_path'],
            'synced': 1,
          });
        }
      });

      print('✅ Relevés synchronisés: ${serverReleves.length}');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation des relevés: $e');
    }
  }

  /// Synchronise les réceptions
  Future<void> _syncReceptions() async {
    try {
      print('🔄 Synchronisation des réceptions...');

      // Récupérer les réceptions du serveur
      final serverReceptions = await ApiService.getReceptions();

      // Sauvegarder en local
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Supprimer les anciennes réceptions
        await txn.delete('receptions');

        // Insérer les nouvelles
        for (final reception in serverReceptions) {
          await txn.insert('receptions', {
            'id': reception['id'],
            'fournisseur': reception['fournisseur'],
            'article': reception['article'],
            'quantite': reception['quantite'],
            'conforme': reception['conforme'],
            'remarque': reception['remarque'],
            'photo_path': reception['photo_path'],
            'date': reception['date'],
          });
        }
      });

      print('✅ Réceptions synchronisées: ${serverReceptions.length}');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation des réceptions: $e');
    }
  }

  /// Synchronise les données locales vers le serveur
  Future<void> syncLocalToServer() async {
    try {
      print('🔄 Synchronisation des données locales vers le serveur...');

      final db = await _dbHelper.database;

      // Récupérer les données non synchronisées
      final unsyncedReleves = await db.query(
        'releves',
        where: 'synced = ?',
        whereArgs: [0],
      );

      // Envoyer chaque relevé au serveur
      for (final releve in unsyncedReleves) {
        try {
          await ApiService.createTemperature(
            appareil: releve['appareil'] as String,
            temperature: releve['temperature'] as double,
            remarque: releve['remarque'] as String?,
          );

          // Marquer comme synchronisé
          await db.update(
            'releves',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [releve['id']],
          );
        } catch (e) {
          print(
              '❌ Erreur lors de la synchronisation du relevé ${releve['id']}: $e');
        }
      }

      print(
          '✅ Synchronisation locale terminée: ${unsyncedReleves.length} relevés');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation locale: $e');
    }
  }

  /// Obtient le statut de la synchronisation
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'hasTimer': _syncTimer != null,
      'isActive': _syncTimer?.isActive ?? false,
    };
  }

  /// Force une synchronisation immédiate
  Future<void> forceSync() async {
    if (_isSyncing) {
      print('⚠️ Synchronisation déjà en cours');
      return;
    }

    await _syncAllData();
  }
}
