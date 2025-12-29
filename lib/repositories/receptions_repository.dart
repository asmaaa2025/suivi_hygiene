import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exceptions.dart';
import '../services/network_service.dart';
import '../services/cache_service.dart';
import 'base_repository.dart';

/// Repository for receptions and suppliers
class ReceptionsRepository extends BaseRepository {
  @override
  String get tableName => 'receptions';

  static const String _suppliersTable = 'fournisseurs';

  final NetworkService _network = NetworkService();
  final CacheService _cache = CacheService();

  /// Get all receptions
  Future<List<Map<String, dynamic>>> getAll() async {
    return await fetchList(cacheKey: 'all');
  }

  /// Get all suppliers
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final currentUserId = userId;
      debugPrint('[$_suppliersTable] [GET_SUPPLIERS] Starting fetch');
      debugPrint('[$_suppliersTable] [GET_SUPPLIERS] userId: $currentUserId');

      final data = await client
          .from(_suppliersTable)
          .select()
          .eq('user_id', currentUserId) // Filter by user_id
          .order('nom');

      final List<Map<String, dynamic>> list =
          List<Map<String, dynamic>>.from(data);
      debugPrint(
          '[$_suppliersTable] [GET_SUPPLIERS] ✅ Success: Fetched ${list.length} suppliers');
      return list;
    } catch (e) {
      debugPrint('[$_suppliersTable] [GET_SUPPLIERS] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'getSuppliers');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch suppliers: ${e.toString()}');
    }
  }

  /// Log Supabase errors with full details
  void _logSupabaseError(dynamic error, String operation) {
    debugPrint(
        '[$_suppliersTable] [${operation.toUpperCase()}] ========== ERROR DETAILS ==========');
    debugPrint(
        '[$_suppliersTable] [${operation.toUpperCase()}] Error type: ${error.runtimeType}');
    debugPrint(
        '[$_suppliersTable] [${operation.toUpperCase()}] Error message: ${error.toString()}');

    if (error is PostgrestException) {
      debugPrint(
          '[$_suppliersTable] [${operation.toUpperCase()}] PostgrestException details:');
      debugPrint(
          '[$_suppliersTable] [${operation.toUpperCase()}]   - code: ${error.code}');
      debugPrint(
          '[$_suppliersTable] [${operation.toUpperCase()}]   - message: ${error.message}');
      debugPrint(
          '[$_suppliersTable] [${operation.toUpperCase()}]   - details: ${error.details}');
      debugPrint(
          '[$_suppliersTable] [${operation.toUpperCase()}]   - hint: ${error.hint}');
    }

    debugPrint(
        '[$_suppliersTable] [${operation.toUpperCase()}] ====================================');
  }

  /// Create supplier
  Future<Map<String, dynamic>> createSupplier(String nom) async {
    try {
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final currentUserId = userId;
      final payload = {
        'nom': nom,
        'user_id': currentUserId,
      };

      debugPrint('[$_suppliersTable] [CREATE_SUPPLIER] Starting create');
      debugPrint('[$_suppliersTable] [CREATE_SUPPLIER] userId: $currentUserId');
      debugPrint('[$_suppliersTable] [CREATE_SUPPLIER] payload: $payload');

      final result =
          await client.from(_suppliersTable).insert(payload).select().single();

      await _cache.clearTable('suppliers');
      debugPrint(
          '[$_suppliersTable] [CREATE_SUPPLIER] ✅ Success: Created supplier ${result['id']}');
      debugPrint('[$_suppliersTable] [CREATE_SUPPLIER] Result: $result');
      return result;
    } catch (e) {
      debugPrint(
          '[$_suppliersTable] [CREATE_SUPPLIER] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'createSupplier');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to create supplier: ${e.toString()}');
    }
  }

  /// Create reception
  Future<Map<String, dynamic>> createReceptionRecord({
    required String fournisseur,
    required String produit,
    required double quantite,
    String? statut,
    String? remarque,
    String? photoPath,
  }) async {
    return await super.create({
      'fournisseur': fournisseur,
      'produit': produit,
      'article': produit, // For compatibility
      'quantite': quantite.toString(),
      'statut': statut ?? 'Conforme',
      'conforme': statut == 'Conforme' ? 1 : 0,
      'remarque': remarque,
      'photo_path': photoPath,
      'date': DateTime.now().toIso8601String(),
    });
  }
}
