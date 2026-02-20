import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Service API unifié pour Supabase
///
/// Architecture :
/// - Auth : login/signUp via Supabase Auth (session gérée automatiquement)
/// - CRUD : toutes les opérations via Supabase Postgres
/// - Storage : photos via Supabase Storage
///
/// IMPORTANT :
/// - Toutes les opérations incluent user_id pour RLS
/// - La session est gérée automatiquement par Supabase Flutter SDK
class ApiService {
  // ============================================
  // Configuration Supabase
  // ============================================
  // Use SupabaseConfig for URL and keys (loaded from environment)
  static String get supabaseUrl => SupabaseConfig.supabaseUrl;
  static String get supabaseAnonKey => SupabaseConfig.supabaseAnonKey;
  static const String temperatureBucket = 'temperatures';

  static SupabaseClient? _supabase;

  // ============================================
  // Initialisation
  // ============================================

  /// Initialise le service (appelé au démarrage de l'app)
  /// Note: Supabase.initialize() doit être appelé dans main() avant runApp()
  static Future<void> initialize() async {
    if (_supabase == null) {
      try {
        _supabase = Supabase.instance.client;
        debugPrint('[ApiService] ✅ Client Supabase attaché');
      } catch (e) {
        debugPrint('[ApiService] ⚠️ Supabase non initialisé: $e');
        throw Exception(
          'Supabase must be initialized in main() before calling ApiService.initialize()',
        );
      }
    }
  }

  /// Retourne le client Supabase
  static SupabaseClient get client {
    _supabase ??= Supabase.instance.client;
    return _supabase!;
  }

  /// Retourne l'ID de l'utilisateur connecté
  static String? get currentUserId => client.auth.currentUser?.id;

  /// Vérifie si l'utilisateur est connecté (utilise la session Supabase)
  static bool get isLoggedIn {
    final session = client.auth.currentSession;
    return session != null;
  }

  // ============================================
  // Auth : Login / SignUp / Logout
  // ============================================

  /// Connexion avec email/password
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await _ensureInitialized();

    try {
      debugPrint('[Auth] Tentative de connexion: $email');

      // Vérifier la connectivité
      if (!await _checkNetwork()) {
        return _error('Pas de connexion internet', 'NETWORK_ERROR');
      }

      final response = await _supabase!.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null || response.user == null) {
        return _error('Identifiants incorrects', 'AUTH_ERROR');
      }

      // La session est automatiquement sauvegardée par Supabase Flutter SDK
      debugPrint('[Auth] ✅ Connexion réussie - Session gérée automatiquement');

      return _success({
        'token': response.session!.accessToken,
        'user_id': response.user!.id,
      });
    } on AuthException catch (e) {
      debugPrint('[Auth] ❌ Erreur: ${e.message}');
      return _error(e.message, 'AUTH_ERROR');
    } catch (e) {
      debugPrint('[Auth] ❌ Erreur inattendue: $e');
      return _error('Erreur: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Inscription avec email/password
  static Future<Map<String, dynamic>> signUp(
    String email,
    String password,
  ) async {
    await _ensureInitialized();

    try {
      debugPrint('[Auth] Tentative d\'inscription: $email');

      if (!await _checkNetwork()) {
        return _error('Pas de connexion internet', 'NETWORK_ERROR');
      }

      final response = await _supabase!.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return _error('Impossible de créer le compte', 'AUTH_ERROR');
      }

      debugPrint('[Auth] ✅ Inscription réussie: ${response.user!.email}');

      // La session est automatiquement sauvegardée par Supabase Flutter SDK
      debugPrint(
        '[Auth] ✅ Inscription réussie - Session gérée automatiquement',
      );

      return _success({
        'message': 'Compte créé avec succès',
        'token': response.session?.accessToken,
        'user_id': response.user!.id,
      });
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.contains('already registered')) msg = 'Email déjà utilisé';
      if (msg.contains('Password')) {
        msg = 'Mot de passe trop court (min 6 caractères)';
      }
      return _error(msg, 'AUTH_ERROR');
    } catch (e) {
      return _error('Erreur: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Déconnexion
  static Future<void> logout() async {
    await _ensureInitialized();
    await client.auth.signOut();
    // La session est automatiquement supprimée par Supabase Flutter SDK
    debugPrint('[Auth] ✅ Déconnexion effectuée');
  }

  // ============================================
  // CRUD : Appareils
  // ============================================

  /// Liste tous les appareils de l'utilisateur
  static Future<List<Map<String, dynamic>>> getAppareils() async {
    return await _fetchAll('appareils');
  }

  /// Crée un appareil
  static Future<Map<String, dynamic>?> createAppareil({
    required String nom,
    double? tempMin,
    double? tempMax,
  }) async {
    return await _insert('appareils', {
      'nom': nom,
      'temp_min': tempMin,
      'temp_max': tempMax,
    });
  }

  /// Supprime un appareil
  static Future<bool> deleteAppareil(String id) async {
    return await _delete('appareils', id);
  }

  // ============================================
  // CRUD : Températures
  // ============================================

  /// Liste les températures (optionnel: filtrer par appareil)
  static Future<List<Map<String, dynamic>>> getTemperatures({
    String? appareil,
  }) async {
    final filters = appareil != null ? {'appareil': appareil} : null;
    return await _fetchAll('temperatures', filters: filters, orderBy: 'date');
  }

  /// Crée un relevé de température
  static Future<Map<String, dynamic>?> createTemperature({
    required String appareil,
    required double temperature,
    String? remarque,
    File? photo,
  }) async {
    String? photoUrl;

    // Upload photo si fournie
    if (photo != null) {
      photoUrl = await _uploadPhoto(photo, temperatureBucket);
    }

    return await _insert('temperatures', {
      'appareil': appareil,
      'temperature': temperature,
      'remarque': remarque,
      'photo_path': photoUrl,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// Supprime un relevé de température
  static Future<bool> deleteTemperature(String id) async {
    return await _delete('temperatures', id);
  }

  // ============================================
  // CRUD : Nettoyages
  // ============================================

  /// Liste tous les nettoyages
  static Future<List<Map<String, dynamic>>> getNettoyages() async {
    return await _fetchAll('nettoyages', orderBy: 'date');
  }

  /// Crée un nettoyage
  static Future<Map<String, dynamic>?> createNettoyage({
    required String action,
    String? remarque,
    String? statut,
  }) async {
    return await _insert('nettoyages', {
      'action': action,
      'remarque': remarque,
      'statut': statut ?? 'fait',
      'date': DateTime.now().toIso8601String(),
    });
  }

  // ============================================
  // CRUD : Produits
  // ============================================

  /// Liste tous les produits
  static Future<List<Map<String, dynamic>>> getProduits() async {
    return await _fetchAll('produits');
  }

  /// Crée un produit
  static Future<Map<String, dynamic>?> createProduit({
    required String nom,
    String? typeProduit,
    String? dlc,
    int? dlcJours,
  }) async {
    return await _insert('produits', {
      'nom': nom,
      'type_produit': typeProduit,
      'dlc': dlc,
      'dlc_jours': dlcJours,
      'date_creation': DateTime.now().toIso8601String(),
    });
  }

  // ============================================
  // CRUD : Fournisseurs
  // ============================================

  /// Liste tous les fournisseurs
  static Future<List<Map<String, dynamic>>> getFournisseurs() async {
    return await _fetchAll('fournisseurs');
  }

  /// Crée un fournisseur
  static Future<Map<String, dynamic>?> createFournisseur({
    required String nom,
  }) async {
    return await _insert('fournisseurs', {'nom': nom});
  }

  // ============================================
  // CRUD : Réceptions
  // ============================================

  /// Liste toutes les réceptions
  static Future<List<Map<String, dynamic>>> getReceptions() async {
    return await _fetchAll('receptions', orderBy: 'date');
  }

  /// Crée une réception
  static Future<Map<String, dynamic>?> createReception({
    required String fournisseur,
    required String produit,
    required String quantite,
    String? statut,
    String? remarque,
  }) async {
    return await _insert('receptions', {
      'fournisseur': fournisseur,
      'produit': produit,
      'quantite': quantite,
      'statut': statut ?? 'Conforme',
      'remarque': remarque,
      'date': DateTime.now().toIso8601String(),
    });
  }

  // ============================================
  // CRUD : Friteuses & Huile
  // ============================================

  /// Liste toutes les friteuses
  static Future<List<Map<String, dynamic>>> getFriteuses() async {
    return await _fetchAll('friteuses');
  }

  /// Liste tous les changements d'huile
  static Future<List<Map<String, dynamic>>> getOilChanges() async {
    return await _fetchAll('oil_changes', orderBy: 'date');
  }

  /// Crée un changement d'huile
  static Future<Map<String, dynamic>?> createOilChange({
    required String friteuseId,
    required double quantite,
    String? remarque,
  }) async {
    return await _insert('oil_changes', {
      'friteuse_id': friteuseId,
      'quantite': quantite,
      'remarque': remarque,
      'date': DateTime.now().toIso8601String(),
    });
  }

  // ============================================
  // Utilitaires : Health Check
  // ============================================

  /// Vérifie que la connexion Supabase fonctionne
  static Future<bool> checkHealth() async {
    await _ensureInitialized();
    try {
      await _supabase!.from('appareils').select('id').limit(1);
      debugPrint('[Health] ✅ Connexion Supabase OK');
      return true;
    } catch (e) {
      debugPrint('[Health] ❌ Erreur: $e');
      return false;
    }
  }

  // ============================================
  // Méthodes privées : CRUD générique
  // ============================================

  /// Récupère tous les enregistrements d'une table (filtrés par user_id)
  static Future<List<Map<String, dynamic>>> _fetchAll(
    String table, {
    Map<String, dynamic>? filters,
    String? orderBy,
  }) async {
    await _ensureInitialized();
    final userId = currentUserId;

    if (userId == null) {
      debugPrint('[$table] ❌ Utilisateur non connecté');
      return [];
    }

    try {
      debugPrint('[$table] [FETCH] userId=$userId');

      var query = _supabase!.from(table).select().eq('user_id', userId);

      if (filters != null) {
        filters.forEach((key, value) {
          query = query.eq(key, value);
        });
      }

      final data = await query.order(orderBy ?? 'created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);

      debugPrint('[$table] [FETCH] ✅ ${list.length} enregistrements');
      return list;
    } on PostgrestException catch (e) {
      debugPrint('[$table] [FETCH] ❌ ${e.code}: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[$table] [FETCH] ❌ $e');
      return [];
    }
  }

  /// Insère un enregistrement (avec user_id automatique)
  static Future<Map<String, dynamic>?> _insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    await _ensureInitialized();
    final userId = currentUserId;

    if (userId == null) {
      debugPrint('[$table] ❌ Utilisateur non connecté');
      return null;
    }

    try {
      // Ajoute user_id automatiquement
      final payload = {...data, 'user_id': userId};

      debugPrint('[$table] [INSERT] userId=$userId');
      debugPrint('[$table] [INSERT] payload=$payload');

      final result = await _supabase!
          .from(table)
          .insert(payload)
          .select()
          .single();

      debugPrint('[$table] [INSERT] ✅ id=${result['id']}');
      return result;
    } on PostgrestException catch (e) {
      debugPrint('[$table] [INSERT] ❌ ${e.code}: ${e.message}');
      debugPrint('[$table] [INSERT] details: ${e.details}');
      debugPrint('[$table] [INSERT] hint: ${e.hint}');
      return null;
    } catch (e) {
      debugPrint('[$table] [INSERT] ❌ $e');
      return null;
    }
  }

  /// Supprime un enregistrement (vérifie user_id)
  static Future<bool> _delete(String table, String id) async {
    await _ensureInitialized();
    final userId = currentUserId;

    if (userId == null) {
      debugPrint('[$table] ❌ Utilisateur non connecté');
      return false;
    }

    try {
      debugPrint('[$table] [DELETE] id=$id userId=$userId');

      await _supabase!.from(table).delete().eq('id', id).eq('user_id', userId);

      debugPrint('[$table] [DELETE] ✅');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('[$table] [DELETE] ❌ ${e.code}: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[$table] [DELETE] ❌ $e');
      return false;
    }
  }

  // ============================================
  // Méthodes privées : Utilitaires
  // ============================================

  static Future<void> _ensureInitialized() async {
    if (_supabase == null) await initialize();
  }

  // _saveToken supprimé : Supabase Flutter SDK gère automatiquement la session

  static Future<bool> _checkNetwork() async {
    try {
      await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> _uploadPhoto(File photo, String bucket) async {
    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          '$currentUserId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase!.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return _supabase!.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      debugPrint('[Storage] ❌ Upload échoué: $e');
      return null;
    }
  }

  static Map<String, dynamic> _success(Map<String, dynamic> data) {
    return {'success': true, 'error': null, ...data};
  }

  static Map<String, dynamic> _error(String message, String type) {
    return {'success': false, 'error': message, 'errorType': type};
  }
}
