import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exceptions.dart';
import '../services/network_service.dart';
import '../services/employee_session_service.dart';
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

      // Try owner_id first (preferred), fallback to user_id for legacy
      var query = client.from(_fryersTable).select();
      try {
        final data = await query.eq('owner_id', currentUserId).order('nom');
        final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
          data,
        );
        debugPrint(
          '[$_fryersTable] [GET_FRYERS] ✅ Success with owner_id: Fetched ${list.length} fryers',
        );
        return list;
      } catch (e) {
        debugPrint(
          '[$_fryersTable] [GET_FRYERS] ⚠️ Failed with owner_id, trying user_id: $e',
        );
        // Fallback to user_id for legacy support
        final data = await query.eq('user_id', currentUserId).order('nom');
        final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
          data,
        );
        debugPrint(
          '[$_fryersTable] [GET_FRYERS] ✅ Success with user_id: Fetched ${list.length} fryers',
        );
        return list;
      }
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
      '[$_fryersTable] [${operation.toUpperCase()}] ========== ERROR DETAILS ==========',
    );
    debugPrint(
      '[$_fryersTable] [${operation.toUpperCase()}] Error type: ${error.runtimeType}',
    );
    debugPrint(
      '[$_fryersTable] [${operation.toUpperCase()}] Error message: ${error.toString()}',
    );

    final errorStr = error.toString();
    if (errorStr.contains('PostgrestException') || errorStr.contains('PGRST')) {
      debugPrint(
        '[$_fryersTable] [${operation.toUpperCase()}] Supabase error details:',
      );
      debugPrint(
        '[$_fryersTable] [${operation.toUpperCase()}]   - error: $errorStr',
      );
    }

    debugPrint(
      '[$_fryersTable] [${operation.toUpperCase()}] ====================================',
    );
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
  /// Employee name is automatically retrieved from current session
  Future<Map<String, dynamic>> createOilChange({
    required String friteuseId,
    required double quantite,
    String? remarque,
  }) async {
    // Automatically get current employee from session
    final employeeSessionService = EmployeeSessionService();
    await employeeSessionService.initialize();
    final currentEmployee = employeeSessionService.currentEmployee;
    final employeeFirstName = currentEmployee?.firstName;
    final employeeLastName = currentEmployee?.lastName;

    return await super.create({
      'friteuse_id': friteuseId,
      'quantite': quantite,
      'remarque': remarque,
      'date': DateTime.now().toIso8601String(),
      'employee_first_name':
          employeeFirstName, // Automatically retrieved from session
      'employee_last_name':
          employeeLastName, // Automatically retrieved from session
    });
  }

  /// Update an oil change
  Future<Map<String, dynamic>> updateOilChange({
    required String id,
    String? friteuseId,
    double? quantite,
    String? remarque,
  }) async {
    final updates = <String, dynamic>{};
    if (friteuseId != null) updates['friteuse_id'] = friteuseId;
    if (quantite != null) updates['quantite'] = quantite;
    if (remarque != null) updates['remarque'] = remarque;

    return await super.update(id, updates);
  }

  /// Delete an oil change
  Future<void> deleteOilChange(String id) async {
    await super.delete(id);
  }
}
