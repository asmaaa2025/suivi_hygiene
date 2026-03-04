/// Compliance Repository
///
/// Handles database operations for compliance requirements and events

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/network_service.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../documents/models.dart';

class ComplianceRepository {
  final SupabaseService _supabase = SupabaseService();
  final NetworkService _network = NetworkService();

  SupabaseClient get _client => _supabase.client;

  /// Get all compliance requirements for an organization
  Future<List<ComplianceRequirement>> getRequirements(
    String organizationId,
  ) async {
    try {
      await _network.hasConnection();

      final response = await _client
          .from('compliance_requirements')
          .select()
          .eq('organization_id', organizationId)
          .eq('active', true)
          .order('code');

      return (response as List)
          .map(
            (json) =>
                ComplianceRequirement.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('[ComplianceRepo] Error fetching requirements: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch compliance requirements: $e');
    }
  }

  /// Get a specific requirement by code
  Future<ComplianceRequirement?> getRequirementByCode(
    String organizationId,
    String code,
  ) async {
    try {
      await _network.hasConnection();

      final response = await _client
          .from('compliance_requirements')
          .select()
          .eq('organization_id', organizationId)
          .eq('code', code)
          .maybeSingle();

      if (response == null) return null;
      return ComplianceRequirement.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ComplianceRepo] Error fetching requirement: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch compliance requirement: $e');
    }
  }

  /// Get all compliance events for an organization
  Future<List<ComplianceEvent>> getEvents(String organizationId) async {
    try {
      await _network.hasConnection();

      final response = await _client
          .from('compliance_events')
          .select()
          .eq('organization_id', organizationId)
          .order('event_date', ascending: false);

      return (response as List)
          .map((json) => ComplianceEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ComplianceRepo] Error fetching events: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch compliance events: $e');
    }
  }

  /// Get events for a specific requirement
  Future<List<ComplianceEvent>> getEventsForRequirement(
    String requirementId,
  ) async {
    try {
      await _network.hasConnection();

      final response = await _client
          .from('compliance_events')
          .select()
          .eq('requirement_id', requirementId)
          .order('event_date', ascending: false);

      return (response as List)
          .map((json) => ComplianceEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ComplianceRepo] Error fetching events for requirement: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch compliance events: $e');
    }
  }

  /// Get compliance events linked to a specific document
  Future<List<ComplianceEvent>> getEventsForDocument(String documentId) async {
    try {
      await _network.hasConnection();

      final response = await _client
          .from('compliance_events')
          .select()
          .eq('document_id', documentId)
          .order('event_date', ascending: false);

      return (response as List)
          .map((json) => ComplianceEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ComplianceRepo] Error fetching events for document: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to fetch compliance events for document: $e');
    }
  }

  /// Create a compliance event
  Future<ComplianceEvent> createEvent({
    required String organizationId,
    required String requirementId,
    required DateTime eventDate,
    String? documentId,
    String? notes,
    String? createdBy,
  }) async {
    try {
      await _network.hasConnection();

      final data = {
        'organization_id': organizationId,
        'requirement_id': requirementId,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'document_id': documentId,
        'notes': notes,
        'created_by': createdBy,
      };

      final response = await _client
          .from('compliance_events')
          .insert(data)
          .select()
          .single();

      return ComplianceEvent.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ComplianceRepo] Error creating event: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to create compliance event: $e');
    }
  }

  /// Update a compliance event
  Future<ComplianceEvent> updateEvent(
    String eventId, {
    DateTime? eventDate,
    String? documentId,
    String? notes,
  }) async {
    try {
      await _network.hasConnection();

      final data = <String, dynamic>{};
      if (eventDate != null) {
        data['event_date'] = eventDate.toIso8601String().split('T')[0];
      }
      if (documentId != null) {
        data['document_id'] = documentId;
      }
      if (notes != null) {
        data['notes'] = notes;
      }

      final response = await _client
          .from('compliance_events')
          .update(data)
          .eq('id', eventId)
          .select()
          .single();

      return ComplianceEvent.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ComplianceRepo] Error updating event: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to update compliance event: $e');
    }
  }

  /// Delete a compliance event (soft delete via update or hard delete)
  Future<void> deleteEvent(String eventId) async {
    try {
      await _network.hasConnection();

      await _client.from('compliance_events').delete().eq('id', eventId);
    } catch (e) {
      debugPrint('[ComplianceRepo] Error deleting event: $e');
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to delete compliance event: $e');
    }
  }
}
