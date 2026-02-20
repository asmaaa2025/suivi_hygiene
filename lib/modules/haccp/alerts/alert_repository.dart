/// HACCP Alert Repository
/// 
/// Manages storage and retrieval of alerts in SQLite (offline) and Supabase (online)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import '../../../../data/repositories/organization_repository.dart';

class AlertRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Create an alert (stores in Supabase)
  Future<Alert> create(Alert alert) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get organization ID
      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final alertId = alert.id.isEmpty ? _uuid.v4() : alert.id;

      final data = {
        'id': alertId,
        'alert_code': alert.alertCode,
        'module': alert.module,
        'severity': alert.severity.toJson(),
        'blocking': alert.blocking,
        'title': alert.title,
        'message': alert.message,
        'recommended_actions': alert.recommendedActions,
        'dedupe_key': alert.dedupeKey,
        'event_snapshot': alert.eventSnapshot,
        'organization_id': orgId,
        'employee_id': alert.employeeId,
        'status': alert.status.toJson(),
        'created_at': alert.createdAt.toIso8601String(),
        'owner_id': user.id,
      };

      debugPrint('[AlertRepo] Creating alert: $alertId');
      final response = await _client
          .from('haccp_alerts')
          .insert(data)
          .select()
          .single();

      return Alert.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      debugPrint('[AlertRepo] Error creating alert: $e');
      debugPrint('[AlertRepo] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all alerts with optional filters
  Future<List<Alert>> getAll({
    String? module,
    AlertSeverity? severity,
    AlertStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[AlertRepo] No authenticated user');
        return [];
      }

      // Get organization ID
      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      var query = _client
          .from('haccp_alerts')
          .select()
          .eq('organization_id', orgId);

      if (module != null) {
        query = query.eq('module', module);
      }

      if (severity != null) {
        query = query.eq('severity', severity.toJson());
      }

      if (status != null) {
        query = query.eq('status', status.toJson());
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      var finalQuery = query.order('created_at', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;
      final alerts = (response as List)
          .map((json) => Alert.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[AlertRepo] Fetched ${alerts.length} alerts');
      return alerts;
    } catch (e) {
      debugPrint('[AlertRepo] Error fetching alerts: $e');
      return [];
    }
  }

  /// Get active alerts (not resolved)
  Future<List<Alert>> getActive({
    String? module,
    AlertSeverity? severity,
  }) async {
    return getAll(
      module: module,
      severity: severity,
      status: AlertStatus.active,
    );
  }

  /// Get critical blocking alerts
  Future<List<Alert>> getBlockingAlerts() async {
    return getAll(
      severity: AlertSeverity.critical,
      status: AlertStatus.active,
    ).then((alerts) => alerts.where((a) => a.blocking).toList());
  }

  /// Check if duplicate alert exists within dedupe window
  Future<bool> hasDuplicate(String dedupeKey, int windowMinutes) async {
    if (dedupeKey.isEmpty) return false;

    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final cutoffTime = DateTime.now().subtract(Duration(minutes: windowMinutes));

      final response = await _client
          .from('haccp_alerts')
          .select('id')
          .eq('organization_id', orgId)
          .eq('dedupe_key', dedupeKey)
          .eq('status', 'active')
          .gte('created_at', cutoffTime.toIso8601String())
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('[AlertRepo] Error checking duplicate: $e');
      return false;
    }
  }

  /// Resolve an alert
  Future<void> resolve(String alertId, {String? resolvedBy}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('haccp_alerts')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
            'resolved_by': resolvedBy ?? user.id,
          })
          .eq('id', alertId);

      debugPrint('[AlertRepo] Resolved alert: $alertId');
    } catch (e) {
      debugPrint('[AlertRepo] Error resolving alert: $e');
      rethrow;
    }
  }

  /// Acknowledge an alert (mark as acknowledged but keep active)
  Future<void> acknowledge(String alertId) async {
    try {
      await _client
          .from('haccp_alerts')
          .update({
            'status': 'acknowledged',
          })
          .eq('id', alertId);

      debugPrint('[AlertRepo] Acknowledged alert: $alertId');
    } catch (e) {
      debugPrint('[AlertRepo] Error acknowledging alert: $e');
      rethrow;
    }
  }

  /// Link alert to corrective action
  Future<void> linkCorrectiveAction(String alertId, String correctiveActionId) async {
    try {
      await _client
          .from('haccp_alerts')
          .update({
            'corrective_action_id': correctiveActionId,
          })
          .eq('id', alertId);

      debugPrint('[AlertRepo] Linked alert $alertId to corrective action $correctiveActionId');
    } catch (e) {
      debugPrint('[AlertRepo] Error linking corrective action: $e');
      rethrow;
    }
  }

  /// Get alert by ID
  Future<Alert?> getById(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final response = await _client
          .from('haccp_alerts')
          .select()
          .eq('id', id)
          .eq('organization_id', orgId)
          .maybeSingle();

      if (response == null) return null;
      return Alert.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AlertRepo] Error fetching alert: $e');
      return null;
    }
  }

  /// Delete alert
  Future<void> delete(String id) async {
    try {
      await _client
          .from('haccp_alerts')
          .delete()
          .eq('id', id);

      debugPrint('[AlertRepo] Deleted alert: $id');
    } catch (e) {
      debugPrint('[AlertRepo] Error deleting alert: $e');
      rethrow;
    }
  }
}

