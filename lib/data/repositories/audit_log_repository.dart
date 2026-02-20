import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_log_entry.dart';

/// Repository for audit log (central history)
class AuditLogRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Expose client for user access
  SupabaseClient get client => _client;

  /// Get audit log entries with optional filters
  Future<List<AuditLogEntry>> getAll({
    String? organizationId,
    String? operationType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[AuditLogRepo] No authenticated user');
        return [];
      }

      debugPrint('[AuditLogRepo] Fetching audit log entries');
      var query = _client.from('audit_log').select();

      // Filter by organization (required)
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      // Filter by operation type
      if (operationType != null) {
        query = query.eq('operation_type', operationType);
      }

      // Filter by date range
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.lte('created_at', endOfDay.toIso8601String());
      }

      // Order and limit
      var finalQuery = query.order('created_at', ascending: false);
      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      final entries = (response as List)
          .map((json) => AuditLogEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
        '[AuditLogRepo] ✅ Fetched ${entries.length} audit log entries',
      );
      return entries;
    } catch (e) {
      debugPrint('[AuditLogRepo] ❌ Error: $e');
      throw Exception('Failed to fetch audit log: $e');
    }
  }

  /// Create an audit log entry
  /// Note: In production, this should be called via a database function or service role
  Future<AuditLogEntry> create({
    required String organizationId,
    required String operationType,
    String? operationId,
    required String action,
    String? actorUserId,
    String? actorEmployeeId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('audit_log')
          .insert({
            'organization_id': organizationId,
            'operation_type': operationType,
            'operation_id': operationId,
            'action': action,
            'actor_user_id': actorUserId ?? user.id,
            'actor_employee_id': actorEmployeeId,
            'description': description,
            'metadata': metadata,
          })
          .select()
          .single();

      return AuditLogEntry.fromJson(response);
    } catch (e) {
      debugPrint('[AuditLogRepo] ❌ Error creating audit log entry: $e');
      throw Exception('Failed to create audit log entry: $e');
    }
  }
}
