import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/haccp_action.dart';

/// Repository for HACCP actions
class HaccpRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Create a new HACCP action
  Future<HaccpAction> create({
    required String userId,
    required HaccpActionType type,
    required DateTime occurredAt,
    required Map<String, dynamic> payloadJson,
  }) async {
    try {
      final insertData = <String, dynamic>{
        'user_id': userId,
        'type': type.toValue(),
        'occurred_at': occurredAt.toIso8601String(),
        'payload_json': payloadJson,
      };

      debugPrint('[HaccpRepo] Creating action: ${type.toValue()} for user: $userId');
      final response = await _client
          .from('haccp_actions')
          .insert(insertData)
          .select()
          .single();

      debugPrint('[HaccpRepo] ✅ Action created successfully');
      return HaccpAction.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[HaccpRepo] ❌ Error creating action: $e');
      throw Exception('Échec de la création de l\'action HACCP: $e');
    }
  }

  /// Get HACCP actions for a user with optional filters
  Future<List<HaccpAction>> getActionsForUser({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    HaccpActionType? type,
    int? limit,
  }) async {
    try {
      dynamic query = _client.from('haccp_actions').select();

      query = query.eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('occurred_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('occurred_at', endDate.toIso8601String());
      }

      if (type != null) {
        query = query.eq('type', type.toValue());
      }

      final response = limit != null
          ? await query.order('occurred_at', ascending: false).limit(limit) as List
          : await query.order('occurred_at', ascending: false) as List;
      final actions = response
          .map((json) => HaccpAction.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[HaccpRepo] ✅ Fetched ${actions.length} actions for user: $userId');
      return actions;
    } catch (e) {
      debugPrint('[HaccpRepo] ❌ Error getting actions: $e');
      throw Exception('Échec de la récupération des actions: $e');
    }
  }

  /// Get HACCP actions for multiple users (admin only)
  Future<List<HaccpAction>> getActionsForUsers({
    required List<String> userIds,
    DateTime? startDate,
    DateTime? endDate,
    HaccpActionType? type,
  }) async {
    try {
      dynamic query = _client.from('haccp_actions').select();

      if (userIds.isNotEmpty) {
        query = query.inFilter('user_id', userIds);
      }

      if (startDate != null) {
        query = query.gte('occurred_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('occurred_at', endDate.toIso8601String());
      }

      if (type != null) {
        query = query.eq('type', type.toValue());
      }

      final response = await query.order('occurred_at', ascending: false) as List;
      final actions = response
          .map((json) => HaccpAction.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[HaccpRepo] ✅ Fetched ${actions.length} actions for ${userIds.length} users');
      return actions;
    } catch (e) {
      debugPrint('[HaccpRepo] ❌ Error getting actions: $e');
      throw Exception('Échec de la récupération des actions: $e');
    }
  }

  /// Get actions grouped by type for correlation analysis
  Future<Map<HaccpActionType, List<HaccpAction>>> getActionsGroupedByType({
    required List<String> userIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final actions = await getActionsForUsers(
        userIds: userIds,
        startDate: startDate,
        endDate: endDate,
      );

      final grouped = <HaccpActionType, List<HaccpAction>>{};
      for (final action in actions) {
        grouped.putIfAbsent(action.type, () => []).add(action);
      }

      return grouped;
    } catch (e) {
      debugPrint('[HaccpRepo] ❌ Error grouping actions: $e');
      return {};
    }
  }
}

