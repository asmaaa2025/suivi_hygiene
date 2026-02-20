import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';
import '../exceptions/app_exceptions.dart';
import 'base_repository.dart';

/// Repository for temperature devices and logs
class TemperatureRepository extends BaseRepository {
  @override
  String get tableName => 'appareils';

  static const String _logsTable = 'temperatures';

  final SupabaseService _supabase = SupabaseService();
  final CacheService _cache = CacheService();
  final NetworkService _network = NetworkService();

  /// Get all devices
  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      debugPrint(
        '[appareils] [GET_DEVICES] ========================================',
      );
      debugPrint('[appareils] [GET_DEVICES] Starting fetch');
      debugPrint('[appareils] [GET_DEVICES] userId: $userId');
      debugPrint('[appareils] [GET_DEVICES] tableName: $tableName');

      // Check if user is authenticated
      if (userId.isEmpty) {
        debugPrint(
          '[appareils] [GET_DEVICES] ❌ No user ID - user not authenticated',
        );
        throw SupabaseException('User not authenticated. Please login first.');
      }

      // Try with user_id filter first
      try {
        debugPrint(
          '[appareils] [GET_DEVICES] Attempting fetch with user_id filter...',
        );
        final result = await fetchList(
          cacheKey: 'devices',
          filterByUserId: true,
        );
        debugPrint(
          '[appareils] [GET_DEVICES] ✅ Success with user_id filter: ${result.length} devices',
        );
        return result;
      } catch (e) {
        debugPrint('[appareils] [GET_DEVICES] ⚠️ Failed with user_id filter');
        _logSupabaseErrorForTable('appareils', e, 'getDevices (with user_id)');

        // Check if it's a column error
        final isColumnError =
            e is PostgrestException &&
            (e.message.toLowerCase().contains('column') ||
                e.message.toLowerCase().contains('user_id') ||
                e.code ==
                    '42703' // PostgreSQL error code for undefined column
                    );

        // Check if it's a table not found error
        final isTableError =
            e is PostgrestException &&
            (e.message.toLowerCase().contains('relation') ||
                e.message.toLowerCase().contains('does not exist') ||
                e.code ==
                    '42P01' // PostgreSQL error code for undefined table
                    );

        if (isTableError) {
          debugPrint(
            '[appareils] [GET_DEVICES] ❌ Table "appareils" does not exist in Supabase!',
          );
          debugPrint(
            '[appareils] [GET_DEVICES] Please run supabase_schema.sql to create the table.',
          );
          throw SupabaseException(
            'Table "appareils" does not exist. Please create it in Supabase first.',
          );
        }

        if (isColumnError) {
          debugPrint(
            '[appareils] [GET_DEVICES] ⚠️ Column user_id may not exist, retrying without filter...',
          );
          try {
            final result = await fetchList(
              cacheKey: 'devices',
              filterByUserId: false,
            );
            debugPrint(
              '[appareils] [GET_DEVICES] ✅ Success without user_id filter: ${result.length} devices',
            );
            return result;
          } catch (e2) {
            debugPrint(
              '[appareils] [GET_DEVICES] ❌ Also failed without user_id filter',
            );
            _logSupabaseErrorForTable(
              'appareils',
              e2,
              'getDevices (without user_id)',
            );
            rethrow;
          }
        }

        // For other errors, rethrow
        rethrow;
      }
    } catch (e) {
      debugPrint('[appareils] [GET_DEVICES] ❌ Final error: ${e.toString()}');
      _logSupabaseErrorForTable('appareils', e, 'getDevices (final)');
      if (e is NetworkException) rethrow;
      if (e is SupabaseException) rethrow;
      throw SupabaseException('Failed to fetch devices: ${e.toString()}');
    }
  }

  /// Log Supabase errors for a specific table
  void _logSupabaseErrorForTable(
    String table,
    dynamic error,
    String operation,
  ) {
    debugPrint(
      '[$table] [${operation.toUpperCase()}] ========== ERROR DETAILS ==========',
    );
    debugPrint(
      '[$table] [${operation.toUpperCase()}] Error type: ${error.runtimeType}',
    );
    debugPrint(
      '[$table] [${operation.toUpperCase()}] Error message: ${error.toString()}',
    );

    if (error is PostgrestException) {
      debugPrint(
        '[$table] [${operation.toUpperCase()}] PostgrestException details:',
      );
      debugPrint(
        '[$table] [${operation.toUpperCase()}]   - code: ${error.code}',
      );
      debugPrint(
        '[$table] [${operation.toUpperCase()}]   - message: ${error.message}',
      );
      debugPrint(
        '[$table] [${operation.toUpperCase()}]   - details: ${error.details}',
      );
      debugPrint(
        '[$table] [${operation.toUpperCase()}]   - hint: ${error.hint}',
      );
    }

    debugPrint(
      '[$table] [${operation.toUpperCase()}] ====================================',
    );
  }

  /// Get temperature logs for a device
  Future<List<Map<String, dynamic>>> getLogs(String deviceId) async {
    try {
      await _network.hasConnection();
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final userId = _supabase.currentUserId;
      debugPrint('[$_logsTable] [GET_LOGS] Starting fetch');
      debugPrint('[$_logsTable] [GET_LOGS] deviceId: $deviceId');
      debugPrint('[$_logsTable] [GET_LOGS] userId: $userId');

      final data = await _supabase.client
          .from(_logsTable)
          .select()
          .eq('appareil', deviceId)
          .eq('user_id', userId) // Filter by user_id
          .order('date', ascending: false);

      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
        data,
      );
      debugPrint(
        '[$_logsTable] [GET_LOGS] ✅ Success: Fetched ${list.length} logs for device $deviceId',
      );
      return list;
    } catch (e) {
      debugPrint('[$_logsTable] [GET_LOGS] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'getLogs');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
        'Failed to fetch temperature logs: ${e.toString()}',
      );
    }
  }

  /// Log Supabase errors with full details
  void _logSupabaseError(dynamic error, String operation) {
    debugPrint(
      '[$_logsTable] [${operation.toUpperCase()}] ========== ERROR DETAILS ==========',
    );
    debugPrint(
      '[$_logsTable] [${operation.toUpperCase()}] Error type: ${error.runtimeType}',
    );
    debugPrint(
      '[$_logsTable] [${operation.toUpperCase()}] Error message: ${error.toString()}',
    );

    if (error is PostgrestException) {
      debugPrint(
        '[$_logsTable] [${operation.toUpperCase()}] PostgrestException details:',
      );
      debugPrint(
        '[$_logsTable] [${operation.toUpperCase()}]   - code: ${error.code}',
      );
      debugPrint(
        '[$_logsTable] [${operation.toUpperCase()}]   - message: ${error.message}',
      );
      debugPrint(
        '[$_logsTable] [${operation.toUpperCase()}]   - details: ${error.details}',
      );
      debugPrint(
        '[$_logsTable] [${operation.toUpperCase()}]   - hint: ${error.hint}',
      );
    }

    debugPrint(
      '[$_logsTable] [${operation.toUpperCase()}] ====================================',
    );
  }

  /// Create device
  Future<Map<String, dynamic>> createDevice({
    required String nom,
    double? tempMin,
    double? tempMax,
  }) async {
    return await create({'nom': nom, 'temp_min': tempMin, 'temp_max': tempMax});
  }

  /// Create temperature log
  Future<Map<String, dynamic>> createLog({
    required String appareil,
    required double temperature,
    String? remarque,
    String? commentaire,
    bool conforme = true,
    String? photoPath,
  }) async {
    try {
      await _network.hasConnection();
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final userId = _supabase.currentUserId;
      final record = {
        'appareil': appareil,
        'temperature': temperature,
        'remarque': remarque,
        'commentaire': commentaire,
        'conforme': conforme,
        'photo_path': photoPath,
        'date': DateTime.now().toIso8601String(),
        'user_id': userId, // Ensure user_id is set
      };

      debugPrint('[$_logsTable] [CREATE_LOG] Starting create');
      debugPrint('[$_logsTable] [CREATE_LOG] userId: $userId');
      debugPrint('[$_logsTable] [CREATE_LOG] payload: $record');

      // Upload photo if provided
      if (photoPath != null) {
        // Photo upload logic will be handled separately
        // For now, just store the path
        debugPrint(
          '[$_logsTable] [CREATE_LOG] Photo path provided: $photoPath',
        );
      }

      final result = await _supabase.client
          .from(_logsTable)
          .insert(record)
          .select()
          .single();

      await _cache.clearTable(_logsTable);
      debugPrint(
        '[$_logsTable] [CREATE_LOG] ✅ Success: Created log ${result['id']}',
      );
      debugPrint('[$_logsTable] [CREATE_LOG] Result: $result');
      return result;
    } catch (e) {
      debugPrint('[$_logsTable] [CREATE_LOG] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'createLog');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
        'Failed to create temperature log: ${e.toString()}',
      );
    }
  }

  /// Delete temperature log
  Future<void> deleteLog(String id) async {
    try {
      await _network.hasConnection();
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final userId = _supabase.currentUserId;
      debugPrint('[$_logsTable] [DELETE_LOG] Starting delete');
      debugPrint('[$_logsTable] [DELETE_LOG] id: $id');
      debugPrint('[$_logsTable] [DELETE_LOG] userId: $userId');

      await _supabase.client
          .from(_logsTable)
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // Filter by user_id for security

      await _cache.clearTable(_logsTable);
      debugPrint('[$_logsTable] [DELETE_LOG] ✅ Success: Deleted log $id');
    } catch (e) {
      debugPrint('[$_logsTable] [DELETE_LOG] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'deleteLog');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
        'Failed to delete temperature log: ${e.toString()}',
      );
    }
  }

  /// Update device
  Future<Map<String, dynamic>> updateDevice(
    String id, {
    String? nom,
    double? tempMin,
    double? tempMax,
  }) async {
    final updates = <String, dynamic>{};
    if (nom != null) updates['nom'] = nom;
    if (tempMin != null) updates['temp_min'] = tempMin;
    if (tempMax != null) updates['temp_max'] = tempMax;

    return await update(id, updates);
  }

  /// Delete device
  Future<void> deleteDevice(String id) async {
    await delete(id);
  }
}
