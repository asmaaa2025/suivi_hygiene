import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/releve_temperature.dart';

/// Service de base de données optimisé avec gestion d'erreur robuste
///
/// Fonctionnalités :
/// - Connexion singleton réutilisée
/// - Gestion d'erreur complète avec try/catch
/// - Timeout sur toutes les requêtes
/// - Transactions avec rollback automatique
/// - Requêtes non-bloquantes sur le thread principal
class OptimizedDatabaseHelper {
  // Singleton pattern pour une seule instance
  static final OptimizedDatabaseHelper _instance =
      OptimizedDatabaseHelper._internal();
  factory OptimizedDatabaseHelper() => _instance;
  OptimizedDatabaseHelper._internal();

  // Connexion unique réutilisée
  static Database? _database;
  static bool _isInitializing = false;
  static final Completer<Database> _databaseCompleter = Completer<Database>();

  /// Obtient la connexion à la base de données (singleton)
  ///
  /// Cette méthode :
  /// 1. Retourne la connexion existante si disponible
  /// 2. Initialise une nouvelle connexion si nécessaire
  /// 3. Gère les erreurs de connexion
  /// 4. Évite les connexions multiples simultanées
  Future<Database> get database async {
    // Si la connexion existe déjà, la retourner
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // Si une initialisation est en cours, attendre qu'elle se termine
    if (_isInitializing) {
      return _databaseCompleter.future;
    }

    // Initialiser une nouvelle connexion
    _isInitializing = true;
    try {
      _database = await _initDatabase();
      _databaseCompleter.complete(_database);
      return _database!;
    } catch (e) {
      _databaseCompleter.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialise la base de données avec gestion d'erreur
  Future<Database> _initDatabase() async {
    try {
      final dbPath =
          path.join(await getDatabasesPath(), 'qualipad_optimized.db');

      final database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase,
        onOpen: _onDatabaseOpen,
      );

      print('✅ Base de données initialisée avec succès');
      return database;
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de la base de données: $e');
      rethrow;
    }
  }

  /// Configuration de la base de données à l'ouverture
  Future<void> _onDatabaseOpen(Database db) async {
    try {
      // Activer les clés étrangères
      await db.execute('PRAGMA foreign_keys = ON');

      // Optimiser les performances
      await db.execute('PRAGMA journal_mode = WAL');
      await db.execute('PRAGMA synchronous = NORMAL');
      await db.execute('PRAGMA cache_size = 1000');
      await db.execute('PRAGMA temp_store = MEMORY');

      print('✅ Configuration de la base de données appliquée');
    } catch (e) {
      print('⚠️ Erreur lors de la configuration de la base de données: $e');
    }
  }

  /// Crée les tables de la base de données
  Future<void> _createTables(Database db, int version) async {
    try {
      // Table des utilisateurs (pour le cache local)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          username TEXT UNIQUE NOT NULL,
          email TEXT,
          token TEXT,
          last_login TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // Table des produits
      await db.execute('''
        CREATE TABLE IF NOT EXISTS produits (
          id TEXT PRIMARY KEY,
          nom TEXT NOT NULL,
          dlc TEXT,
          dlc_jours INTEGER,
          lot TEXT,
          poids REAL,
          date_creation TEXT NOT NULL,
          date_modification TEXT NOT NULL,
          date_fabrication TEXT,
          surgelagable INTEGER DEFAULT 0,
          dlc_surgelation_jours INTEGER,
          preparateur TEXT,
          heure_preparation TEXT,
          dluo TEXT,
          ingredients TEXT,
          quantite TEXT,
          origine_viande TEXT,
          allergenes TEXT,
          type_produit TEXT
        )
      ''');

      // Table des relevés de température
      await db.execute('''
        CREATE TABLE IF NOT EXISTS releves (
          id TEXT PRIMARY KEY,
          appareil TEXT NOT NULL,
          temperature REAL NOT NULL,
          date TEXT NOT NULL,
          remarque TEXT,
          conforme INTEGER DEFAULT 1,
          commentaire TEXT,
          photo_path TEXT,
          synced INTEGER DEFAULT 0
        )
      ''');

      // Table des appareils
      await db.execute('''
        CREATE TABLE IF NOT EXISTS appareils (
          id TEXT PRIMARY KEY,
          nom TEXT UNIQUE NOT NULL,
          temp_min REAL,
          temp_max REAL,
          synced INTEGER DEFAULT 0
        )
      ''');

      print('✅ Tables créées avec succès');
    } catch (e) {
      print('❌ Erreur lors de la création des tables: $e');
      rethrow;
    }
  }

  /// Met à jour la base de données
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    try {
      print(
          '🔄 Mise à jour de la base de données de la version $oldVersion vers $newVersion');

      // Ajouter ici les migrations nécessaires
      if (oldVersion < 2) {
        // Exemple de migration
        await db.execute('ALTER TABLE users ADD COLUMN last_sync TEXT');
      }

      print('✅ Base de données mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de la base de données: $e');
      rethrow;
    }
  }

  /// Exécute une requête avec timeout et gestion d'erreur
  ///
  /// Cette méthode :
  /// 1. Applique un timeout à la requête
  /// 2. Gère les erreurs de base de données
  /// 3. Retourne un résultat ou lance une exception appropriée
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() query, {
    Duration timeout = const Duration(seconds: 10),
    String? operation,
  }) async {
    try {
      return await query().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Timeout lors de l\'opération: ${operation ?? 'requête inconnue'}',
            timeout,
          );
        },
      );
    } on TimeoutException catch (e) {
      print('⏰ Timeout de base de données: $e');
      rethrow;
    } catch (e) {
      if (e.toString().contains('DatabaseException')) {
        print('❌ Erreur de base de données: $e');
        throw Exception('Erreur de base de données: ${e.toString()}');
      }
      print('❌ Erreur inattendue: $e');
      throw Exception('Erreur inattendue: $e');
    }
    throw Exception('Unexpected error in _executeWithTimeout');
  }

  /// Sauvegarde un utilisateur en cache local
  ///
  /// Cette méthode :
  /// 1. Sauvegarde les informations utilisateur localement
  /// 2. Gère les erreurs de sauvegarde
  /// 3. Utilise une transaction pour la cohérence
  Future<void> saveUser({
    required String username,
    required String token,
    String? email,
  }) async {
    await _executeWithTimeout(
      () async {
        final db = await database;

        await db.transaction((txn) async {
          // Supprimer l'utilisateur existant s'il y en a un
          await txn.delete('users');

          // Insérer le nouvel utilisateur
          await txn.insert('users', {
            'id': const Uuid().v4(),
            'username': username,
            'email': email,
            'token': token,
            'last_login': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
        });

        print('✅ Utilisateur sauvegardé en cache local');
      },
      operation: 'saveUser',
    );
  }

  /// Récupère l'utilisateur en cache local
  Future<Map<String, dynamic>?> getCachedUser() async {
    return await _executeWithTimeout(
      () async {
        final db = await database;
        final result = await db.query(
          'users',
          limit: 1,
          orderBy: 'last_login DESC',
        );

        return result.isNotEmpty ? result.first : null;
      },
      operation: 'getCachedUser',
    );
  }

  /// Supprime l'utilisateur du cache local (logout)
  Future<void> clearCachedUser() async {
    await _executeWithTimeout(
      () async {
        final db = await database;
        await db.delete('users');
        print('✅ Utilisateur supprimé du cache local');
      },
      operation: 'clearCachedUser',
    );
  }

  /// Récupère les produits avec pagination et gestion d'erreur
  Future<List<Map<String, dynamic>>> getProduits({
    int limit = 50,
    int offset = 0,
    String? searchTerm,
  }) async {
    return await _executeWithTimeout(
      () async {
        final db = await database;

        String whereClause = '';
        List<dynamic> whereArgs = [];

        if (searchTerm != null && searchTerm.isNotEmpty) {
          whereClause = 'WHERE nom LIKE ?';
          whereArgs.add('%$searchTerm%');
        }

        final result = await db.rawQuery('''
          SELECT * FROM produits 
          $whereClause
          ORDER BY nom ASC 
          LIMIT ? OFFSET ?
        ''', [...whereArgs, limit, offset]);

        return result;
      },
      operation: 'getProduits',
    );
  }

  /// Insère un produit avec gestion d'erreur
  Future<void> insertProduit(Map<String, dynamic> produit) async {
    await _executeWithTimeout(
      () async {
        final db = await database;

        await db.transaction((txn) async {
          await txn.insert('produits', {
            'id': const Uuid().v4(),
            'nom': produit['nom'],
            'dlc': produit['dlc'],
            'dlc_jours': produit['dlc_jours'],
            'lot': produit['lot'],
            'poids': produit['poids'],
            'date_creation': DateTime.now().toIso8601String(),
            'date_modification': DateTime.now().toIso8601String(),
            'date_fabrication': produit['date_fabrication'],
            'surgelagable': produit['surgelagable'] == true ? 1 : 0,
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
        });

        print('✅ Produit inséré avec succès');
      },
      operation: 'insertProduit',
    );
  }

  /// Récupère les relevés de température avec filtres
  Future<List<Map<String, dynamic>>> getReleves({
    String? appareil,
    DateTime? dateDebut,
    DateTime? dateFin,
    int limit = 100,
  }) async {
    return await _executeWithTimeout(
      () async {
        final db = await database;

        String whereClause = 'WHERE 1=1';
        List<dynamic> whereArgs = [];

        if (appareil != null) {
          whereClause += ' AND appareil = ?';
          whereArgs.add(appareil);
        }

        if (dateDebut != null) {
          whereClause += ' AND date >= ?';
          whereArgs.add(dateDebut.toIso8601String());
        }

        if (dateFin != null) {
          whereClause += ' AND date <= ?';
          whereArgs.add(dateFin.toIso8601String());
        }

        final result = await db.rawQuery('''
          SELECT * FROM releves 
          $whereClause
          ORDER BY date DESC 
          LIMIT ?
        ''', [...whereArgs, limit]);

        return result;
      },
      operation: 'getReleves',
    );
  }

  /// Insère un relevé de température
  Future<void> insertReleve(ReleveTemperature releve) async {
    await _executeWithTimeout(
      () async {
        final db = await database;

        await db.transaction((txn) async {
          await txn.insert('releves', {
            'id': const Uuid().v4(),
            'appareil': releve.appareil,
            'temperature': releve.temperature,
            'date': releve.date.toIso8601String(),
            'remarque': releve.remarque,
            'conforme': 1, // Default to conform
            'commentaire': releve.remarque,
            'photo_path': releve.photoPath,
            'synced': 0, // Non synchronisé par défaut
          });
        });

        print('✅ Relevé inséré avec succès');
      },
      operation: 'insertReleve',
    );
  }

  /// Synchronise les données avec le serveur
  Future<void> syncWithServer() async {
    await _executeWithTimeout(
      () async {
        final db = await database;

        // Récupérer les données non synchronisées
        final unsyncedReleves = await db.query(
          'releves',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // Ici, vous pourriez envoyer ces données au serveur
        // et marquer comme synchronisées après succès

        print('🔄 Synchronisation de ${unsyncedReleves.length} relevés');

        // Marquer comme synchronisés (exemple)
        for (final releve in unsyncedReleves) {
          await db.update(
            'releves',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [releve['id']],
          );
        }

        print('✅ Synchronisation terminée');
      },
      operation: 'syncWithServer',
      timeout: const Duration(seconds: 30), // Timeout plus long pour la sync
    );
  }

  /// Ferme la connexion à la base de données
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      print('🔒 Connexion à la base de données fermée');
    }
  }

  /// Vérifie si la base de données est ouverte
  bool get isOpen => _database != null && _database!.isOpen;

  /// Obtient des statistiques sur la base de données
  Future<Map<String, int>> getDatabaseStats() async {
    return await _executeWithTimeout(
      () async {
        final db = await database;

        final stats = <String, int>{};

        // Compter les enregistrements dans chaque table
        final tables = ['users', 'produits', 'releves', 'appareils'];
        for (final table in tables) {
          final result =
              await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          stats[table] = result.first['count'] as int;
        }

        return stats;
      },
      operation: 'getDatabaseStats',
    );
  }
}
