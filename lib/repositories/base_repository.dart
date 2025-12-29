import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as gotrue
    show AuthException;
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';
import '../exceptions/app_exceptions.dart';

/// Base repository with common patterns
abstract class BaseRepository {
  final SupabaseService _supabase = SupabaseService();
  final CacheService _cache = CacheService();
  final NetworkService _network = NetworkService();

  /// Table name in Supabase
  String get tableName;

  /// Cache key prefix
  String get cachePrefix => tableName;

  /// Get Supabase client
  SupabaseClient get client => _supabase.client;

  /// Get current user ID
  String get userId => _supabase.currentUserId;

  /// Check network and throw if offline
  Future<void> _ensureNetwork() async {
    final hasConnection = await _network.hasConnection();
    if (!hasConnection) {
      throw NetworkException('Network required. Please check your connection.');
    }
  }

  /// Fetch list with cache support
  Future<List<Map<String, dynamic>>> fetchList({
    String? cacheKey,
    Duration cacheTTL = const Duration(minutes: 10),
    Map<String, dynamic>? filters,
    bool filterByUserId = true, // Filter by user_id by default
  }) async {
    try {
      await _ensureNetwork();

      debugPrint('[$tableName] [FETCH_LIST] Starting fetch');
      debugPrint('[$tableName] [FETCH_LIST] userId: $userId');
      debugPrint('[$tableName] [FETCH_LIST] filters: $filters');

      var query = client.from(tableName).select();

      // Always filter by user_id for security (unless explicitly disabled)
      if (filterByUserId) {
        query = query.eq('user_id', userId);
        debugPrint('[$tableName] [FETCH_LIST] Filtering by user_id: $userId');
      }

      // Apply additional filters
      if (filters != null) {
        filters.forEach((key, value) {
          query = query.eq(key, value);
          debugPrint('[$tableName] [FETCH_LIST] Applied filter: $key = $value');
        });
      }

      final data = await query;
      final List<Map<String, dynamic>> list =
          List<Map<String, dynamic>>.from(data);

      // Cache the result
      if (cacheKey != null) {
        await _cache.set('${cachePrefix}_$cacheKey', list, ttl: cacheTTL);
      }

      debugPrint(
          '[$tableName] [FETCH_LIST] ✅ Success: Fetched ${list.length} records');
      return list;
    } catch (e) {
      debugPrint('[$tableName] [FETCH_LIST] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'fetchList');

      // Try cache on error
      if (cacheKey != null) {
        final cached = _cache.get('${cachePrefix}_$cacheKey');
        if (cached != null) {
          debugPrint(
              '[$tableName] [FETCH_LIST] Using cached data (${cached.length} records)');
          return List<Map<String, dynamic>>.from(cached);
        }
      }

      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch $tableName: ${e.toString()}');
    }
  }

  /// Fetch by ID
  Future<Map<String, dynamic>?> fetchById(String id,
      {bool filterByUserId = true}) async {
    try {
      await _ensureNetwork();

      debugPrint('[$tableName] [FETCH_BY_ID] Starting fetch');
      debugPrint('[$tableName] [FETCH_BY_ID] id: $id');
      debugPrint('[$tableName] [FETCH_BY_ID] userId: $userId');

      var query = client.from(tableName).select().eq('id', id);

      // Filter by user_id for security
      if (filterByUserId) {
        query = query.eq('user_id', userId);
        debugPrint('[$tableName] [FETCH_BY_ID] Filtering by user_id: $userId');
      }

      final data = await query.maybeSingle();

      if (data != null) {
        debugPrint('[$tableName] [FETCH_BY_ID] ✅ Success: Fetched record $id');
      } else {
        debugPrint('[$tableName] [FETCH_BY_ID] ⚠️ Record not found: $id');
      }

      return data;
    } catch (e) {
      debugPrint('[$tableName] [FETCH_BY_ID] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'fetchById');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
          'Failed to fetch $tableName record: ${e.toString()}');
    }
  }

  /// Create record
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    try {
      await _ensureNetwork();

      // Ensure user_id is set (override if already present)
      final record = {
        ...data,
        'user_id': userId,
      };

      debugPrint('[$tableName] [CREATE] Starting create');
      debugPrint('[$tableName] [CREATE] userId: $userId');
      debugPrint('[$tableName] [CREATE] payload: $record');

      final result =
          await client.from(tableName).insert(record).select().single();

      // Clear cache
      await _cache.clearTable(tableName);

      debugPrint(
          '[$tableName] [CREATE] ✅ Success: Created record ${result['id']}');
      debugPrint('[$tableName] [CREATE] Result: $result');
      return result;
    } catch (e) {
      debugPrint('[$tableName] [CREATE] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'create');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
          'Failed to create $tableName record: ${e.toString()}');
    }
  }

  /// Update record
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data,
      {bool filterByUserId = true}) async {
    try {
      await _ensureNetwork();

      debugPrint('[$tableName] [UPDATE] Starting update');
      debugPrint('[$tableName] [UPDATE] id: $id');
      debugPrint('[$tableName] [UPDATE] userId: $userId');
      debugPrint('[$tableName] [UPDATE] payload: $data');

      var query = client.from(tableName).update(data).eq('id', id);

      // Filter by user_id for security
      if (filterByUserId) {
        query = query.eq('user_id', userId);
        debugPrint('[$tableName] [UPDATE] Filtering by user_id: $userId');
      }

      final result = await query.select().single();

      // Clear cache
      await _cache.clearTable(tableName);

      debugPrint('[$tableName] [UPDATE] ✅ Success: Updated record $id');
      debugPrint('[$tableName] [UPDATE] Result: $result');
      return result;
    } catch (e) {
      debugPrint('[$tableName] [UPDATE] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'update');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
          'Failed to update $tableName record: ${e.toString()}');
    }
  }

  /// Delete record
  Future<void> delete(String id, {bool filterByUserId = true}) async {
    try {
      await _ensureNetwork();

      debugPrint('[$tableName] [DELETE] Starting delete');
      debugPrint('[$tableName] [DELETE] id: $id');
      debugPrint('[$tableName] [DELETE] userId: $userId');

      var query = client.from(tableName).delete().eq('id', id);

      // Filter by user_id for security
      if (filterByUserId) {
        query = query.eq('user_id', userId);
        debugPrint('[$tableName] [DELETE] Filtering by user_id: $userId');
      }

      await query;

      // Clear cache
      await _cache.clearTable(tableName);

      debugPrint('[$tableName] [DELETE] ✅ Success: Deleted record $id');
    } catch (e) {
      debugPrint('[$tableName] [DELETE] ❌ Error: ${e.toString()}');
      _logSupabaseError(e, 'delete');
      if (e is NetworkException) rethrow;
      throw SupabaseException(
          'Failed to delete $tableName record: ${e.toString()}');
    }
  }

  /// Log Supabase errors with full details
  void _logSupabaseError(dynamic error, String operation) {
    debugPrint(
        '[$tableName] [${operation.toUpperCase()}] ========== ERROR DETAILS ==========');
    debugPrint(
        '[$tableName] [${operation.toUpperCase()}] Error type: ${error.runtimeType}');
    debugPrint(
        '[$tableName] [${operation.toUpperCase()}] Error message: ${error.toString()}');

    if (error is PostgrestException) {
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}] PostgrestException details:');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - code: ${error.code}');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - message: ${error.message}');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - details: ${error.details}');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - hint: ${error.hint}');
    } else if (error is gotrue.AuthException) {
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}] AuthException details:');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - message: ${error.message}');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - statusCode: ${error.statusCode}');
    } else if (error is StorageException) {
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}] StorageException details:');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - message: ${error.message}');
      debugPrint(
          '[$tableName] [${operation.toUpperCase()}]   - statusCode: ${error.statusCode}');
    }

    debugPrint(
        '[$tableName] [${operation.toUpperCase()}] ====================================');
  }
}
