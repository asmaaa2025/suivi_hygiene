import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../database_helper.dart'; // Removed - Supabase-first now

class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  bool _isSyncing = false;
  final List<Map<String, dynamic>> _pendingSync = [];

  /// Synchronise automatiquement une donnée après insertion
  static Future<void> syncAfterInsert(
      String table, Map<String, dynamic> data) async {
    final service = AutoSyncService();
    await service._syncData(table, data);
  }

  /// Synchronise une donnée spécifique
  Future<void> _syncData(String table, Map<String, dynamic> data) async {
    if (_isSyncing) {
      // Si une synchronisation est en cours, ajouter à la queue
      _pendingSync.add({'table': table, 'data': data});
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 [Sync] Synchronisation automatique de $table...');

    try {
      switch (table) {
        case 'temperatures':
          await _syncTemperature(data);
          break;
        case 'produits':
          await _syncProduit(data);
          break;
        case 'nettoyages':
          await _syncNettoyage(data);
          break;
        case 'receptions':
          await _syncReception(data);
          break;
        case 'oil_changes':
          await _syncOilChange(data);
          break;
        default:
          debugPrint(
              '⚠️ [Sync] Table $table non supportée pour la synchronisation Supabase');
      }

      debugPrint('✅ [Sync] Synchronisation de $table réussie');
    } catch (e) {
      debugPrint('❌ [Sync] Erreur de synchronisation de $table: $e');
      // Ajouter à la queue pour retry plus tard (non-bloquant)
      _pendingSync.add({'table': table, 'data': data});
    } finally {
      _isSyncing = false;
      // Traiter la queue s'il y a des éléments en attente
      if (_pendingSync.isNotEmpty) {
        final next = _pendingSync.removeAt(0);
        _syncData(next['table'], next['data']);
      }
    }
  }

  /// Synchronise une température vers Supabase
  Future<void> _syncTemperature(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint(
            '⚠️ [Sync] Utilisateur non connecté Supabase, synchronisation annulée');
        return;
      }

      // Map SQLite data to Supabase format
      final supabaseData = {
        'appareil': data['appareil'] ?? '',
        'temperature': data['temperature'],
        'remarque': data['remarque'],
        'photo_url': data['photo_path'], // Map photo_path to photo_url
      };

      await supabase.from('temperatures').insert(supabaseData);
      debugPrint(
          '✅ [Sync] Température synchronisée Supabase: ${data['appareil']} - ${data['temperature']}°C');
    } catch (e) {
      debugPrint('❌ [Sync] Erreur synchronisation température Supabase: $e');
      // Don't throw - allow UI to continue
    }
  }

  /// Synchronise un produit vers Supabase
  Future<void> _syncProduit(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint(
            '⚠️ [Sync] Utilisateur non connecté Supabase, synchronisation annulée');
        return;
      }

      // Map SQLite data to Supabase format
      final supabaseData = {
        'nom': data['nom'],
        'categorie': data['categorie'],
      };

      await supabase.from('produits').insert(supabaseData);
      debugPrint('✅ [Sync] Produit synchronisé Supabase: ${data['nom']}');
    } catch (e) {
      debugPrint('❌ [Sync] Erreur synchronisation produit Supabase: $e');
      // Don't throw - allow UI to continue
    }
  }

  /// Synchronise un changement d'huile vers Supabase
  Future<void> _syncOilChange(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint(
            '⚠️ [Sync] Utilisateur non connecté Supabase, synchronisation annulée');
        return;
      }

      // Map SQLite data to Supabase format
      final supabaseData = {
        'date_changement': data['date'] ?? DateTime.now().toIso8601String(),
        'type_huile': data['type_huile'] ?? 'Huile de friture',
        'quantite': data['quantite'],
        'responsable': data['responsable'],
        'remarque': data['remarque'],
        'friteuse_id': data['friteuse_id'],
      };

      await supabase.from('oil_changes').insert(supabaseData);
      debugPrint('✅ [Sync] Changement d\'huile synchronisé Supabase');
    } catch (e) {
      debugPrint(
          '❌ [Sync] Erreur synchronisation changement d\'huile Supabase: $e');
      // Don't throw - allow UI to continue
    }
  }

  /// Synchronise un nettoyage vers Supabase
  Future<void> _syncNettoyage(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint(
            '⚠️ [Sync] Utilisateur non connecté Supabase, synchronisation annulée');
        return;
      }

      // Map SQLite data to Supabase format
      final supabaseData = {
        'date_realisation': data['date'],
        'responsable': 'User', // TODO: Get from auth
        'conforme': data['statut'] == 'Terminé',
        'remarque': data['remarque'],
        'tache_id': data['id'], // Use id as tache_id for now
      };

      await supabase.from('suivi_nettoyage').insert(supabaseData);
      debugPrint('✅ [Sync] Nettoyage synchronisé Supabase: ${data['action']}');
    } catch (e) {
      debugPrint('❌ [Sync] Erreur synchronisation nettoyage Supabase: $e');
      // Don't throw - allow UI to continue
    }
  }

  /// Synchronise une réception vers Supabase
  Future<void> _syncReception(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint(
            '⚠️ [Sync] Utilisateur non connecté Supabase, synchronisation annulée');
        return;
      }

      // Map SQLite data to Supabase format
      final supabaseData = {
        'fournisseur': data['fournisseur'],
        'received_at': data['date'] ?? DateTime.now().toIso8601String(),
        'notes': data['remarque'],
        // Note: produit_id would need to be resolved from produit name
      };

      await supabase.from('receptions').insert(supabaseData);
      debugPrint(
          '✅ [Sync] Réception synchronisée Supabase: ${data['produit']}');
    } catch (e) {
      debugPrint('❌ [Sync] Erreur synchronisation réception Supabase: $e');
      // Don't throw - allow UI to continue
    }
  }

  /// Force la synchronisation de toutes les données en attente
  Future<void> syncAllPending() async {
    if (_pendingSync.isEmpty) {
      print('ℹ️ Aucune donnée en attente de synchronisation');
      return;
    }

    print('🔄 Synchronisation de ${_pendingSync.length} données en attente...');

    while (_pendingSync.isNotEmpty) {
      final item = _pendingSync.removeAt(0);
      await _syncData(item['table'], item['data']);
    }

    print('✅ Toutes les données en attente ont été synchronisées');
  }

  /// Obtient le statut de la synchronisation
  Map<String, dynamic> getStatus() {
    return {
      'isSyncing': _isSyncing,
      'pendingCount': _pendingSync.length,
      'pendingItems': _pendingSync.map((item) => item['table']).toList(),
    };
  }
}
