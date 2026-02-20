import 'dart:async';
import 'api_service.dart';
import 'optimized_database_helper.dart';
import 'sync_service.dart';

/// Service de connexion optimisé avec gestion SQLite locale
///
/// Ce service :
/// 1. Gère la connexion HTTP vers l'API
/// 2. Sauvegarde les données utilisateur en local
/// 3. Synchronise les données après connexion
/// 4. Gère les erreurs de base de données
class OptimizedLoginService {
  static final OptimizedLoginService _instance =
      OptimizedLoginService._internal();
  factory OptimizedLoginService() => _instance;
  OptimizedLoginService._internal();

  final OptimizedDatabaseHelper _dbHelper = OptimizedDatabaseHelper();
  final SyncService _syncService = SyncService();

  /// Effectue une connexion complète avec gestion SQLite
  ///
  /// Cette méthode :
  /// 1. Valide les identifiants via l'API
  /// 2. Sauvegarde l'utilisateur en local
  /// 3. Synchronise les données
  /// 4. Gère tous les cas d'erreur
  Future<Map<String, dynamic>> loginWithLocalCache({
    required String username,
    required String password,
  }) async {
    try {
      print('🔐 Début de la connexion optimisée pour: $username');

      // 1. Connexion via l'API avec timeout
      final apiResult = await ApiService.login(
        username,
        password,
      ).timeout(const Duration(seconds: 15));

      if (!apiResult['success']) {
        return {'success': false, 'error': apiResult['error'], 'user': null};
      }

      // 2. Sauvegarder l'utilisateur en local avec gestion d'erreur
      try {
        await _dbHelper.saveUser(username: username, token: apiResult['token']);
        print('✅ Utilisateur sauvegardé en local');
      } catch (e) {
        print('⚠️ Erreur lors de la sauvegarde locale: $e');
        // Continuer même si la sauvegarde locale échoue
      }

      // 3. Démarrer la synchronisation en arrière-plan
      _syncService.startSyncAfterLogin();

      // 4. Récupérer les données utilisateur depuis le cache local
      final cachedUser = await _dbHelper.getCachedUser();

      return {
        'success': true,
        'error': null,
        'user': cachedUser,
        'token': apiResult['token'],
      };
    } on TimeoutException catch (e) {
      print('⏰ Timeout lors de la connexion: $e');
      return {
        'success': false,
        'error': 'Connexion timeout. Vérifiez votre réseau.',
        'user': null,
      };
    } catch (e) {
      print('❌ Erreur lors de la connexion: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'user': null,
      };
    }
  }

  /// Vérifie si un utilisateur est connecté (depuis le cache local)
  Future<bool> isUserLoggedIn() async {
    try {
      final cachedUser = await _dbHelper.getCachedUser();
      return cachedUser != null;
    } catch (e) {
      print('❌ Erreur lors de la vérification de connexion: $e');
      return false;
    }
  }

  /// Récupère l'utilisateur connecté depuis le cache local
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      return await _dbHelper.getCachedUser();
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }

  /// Déconnecte l'utilisateur et nettoie le cache local
  Future<void> logout() async {
    try {
      print('🚪 Déconnexion de l\'utilisateur');

      // 1. Arrêter la synchronisation
      _syncService.stopSync();

      // 2. Déconnecter de l'API
      await ApiService.logout();

      // 3. Nettoyer le cache local
      await _dbHelper.clearCachedUser();

      print('✅ Déconnexion terminée');
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
    }
  }

  /// Synchronise les données locales vers le serveur
  Future<void> syncLocalData() async {
    try {
      await _syncService.syncLocalToServer();
    } catch (e) {
      print('❌ Erreur lors de la synchronisation: $e');
    }
  }

  /// Force une synchronisation complète
  Future<void> forceSync() async {
    try {
      await _syncService.forceSync();
    } catch (e) {
      print('❌ Erreur lors de la synchronisation forcée: $e');
    }
  }

  /// Obtient les statistiques de la base de données locale
  Future<Map<String, int>> getLocalDatabaseStats() async {
    try {
      return await _dbHelper.getDatabaseStats();
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques: $e');
      return {};
    }
  }

  /// Vérifie la connectivité réseau
  Future<bool> checkNetworkConnectivity() async {
    try {
      final response = await ApiService.checkHealth();
      return response;
    } catch (e) {
      return false;
    }
  }

  /// Obtient le statut de la synchronisation
  Map<String, dynamic> getSyncStatus() {
    return _syncService.getSyncStatus();
  }
}
