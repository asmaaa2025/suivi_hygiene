import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exceptions.dart';
import '../services/network_service.dart';
import 'base_repository.dart';

/// Repository for oil changes
class OilChangeRepository extends BaseRepository {
  @override
  String get tableName => 'oil_changes';

  static const String _fryersTable = 'friteuses';
  final NetworkService _network = NetworkService();

  /// Get all fryers
  Future<List<Map<String, dynamic>>> getFryers() async {
    try {
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final currentUserId = userId;
      debugPrint('[$_fryersTable] [GET_FRYERS] Starting fetch');
      debugPrint('[$_fryersTable] [GET_FRYERS] userId: $currentUserId');

      final data = await client
          .from(_fryersTable)
          .select()
          .eq('user_id', currentUserId) // Filter by user_id
          .order('nom');

      final List<Map<String, dynamic>> list =
          List<Map<String, dynamic>>.from(data);
      debugPrint(
          '[$_fryersTable] [GET_FRYERS] ✅ Success: Fetched ${list.length} fryers');
      return list;
    } catch (e) {
      debugPrint('[$_fryersTable] [GET_FRYERS] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'getFryers');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch fryers: ${e.toString()}');
    }
  }

  /// Log Supabase errors with full details
  void _logSupabaseError(dynamic error, String operation) {
    debugPrint(
        '[$_fryersTable] [${operation.toUpperCase()}] ========== ERROR DETAILS ==========');
    debugPrint(
        '[$_fryersTable] [${operation.toUpperCase()}] Error type: ${error.runtimeType}');
    debugPrint(
        '[$_fryersTable] [${operation.toUpperCase()}] Error message: ${error.toString()}');

    final errorStr = error.toString();
    if (errorStr.contains('PostgrestException') || errorStr.contains('PGRST')) {
      debugPrint(
          '[$_fryersTable] [${operation.toUpperCase()}] Supabase error details:');
      debugPrint(
          '[$_fryersTable] [${operation.toUpperCase()}]   - error: $errorStr');
    }

    debugPrint(
        '[$_fryersTable] [${operation.toUpperCase()}] ====================================');
  }

  /// Get all oil changes
  Future<List<Map<String, dynamic>>> getAll() async {
    return await fetchList(cacheKey: 'all');
  }

  /// Get oil changes for a fryer
  Future<List<Map<String, dynamic>>> getByFryer(String fryerId) async {
    return await fetchList(
      cacheKey: 'fryer_$fryerId',
      filters: {'friteuse_id': fryerId},
    );
  }

  /// Create oil change
  Future<Map<String, dynamic>> createOilChange({
    required String friteuseId,
    required double quantite,
    String? remarque,
  }) async {
    return await super.create({
      'friteuse_id': friteuseId,
      'quantite': quantite,
      'remarque': remarque,
      'date': DateTime.now().toIso8601String(),
    });
  }
}
