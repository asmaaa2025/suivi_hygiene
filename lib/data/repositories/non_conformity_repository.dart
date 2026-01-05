import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/non_conformity.dart';

/// Repository for non-conformities
class NonConformityRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get non-conformity by reception ID
  Future<NonConformity?> getByReceptionId(String receptionId) async {
    try {
      final response = await _client
          .from('non_conformities')
          .select()
          .eq('reception_id', receptionId)
          .maybeSingle();

      if (response == null) return null;
      return NonConformity.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NonConformityRepo] ❌ Error: $e');
      return null;
    }
  }

  /// Create a new non-conformity
  Future<NonConformity> create({
    String? receptionId,
    bool temperatureNonCompliant = false,
    bool packagingOpened = false,
    bool packagingWet = false,
    bool labelMissing = false,
    String? declarationText,
    List<String> photoUrls = const [],
    String? performedByEmployeeId,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('non_conformities')
          .insert({
            'reception_id': receptionId,
            'temperature_non_compliant': temperatureNonCompliant,
            'packaging_opened': packagingOpened,
            'packaging_wet': packagingWet,
            'label_missing': labelMissing,
            'declaration_text': declarationText,
            'photo_urls': photoUrls,
            'performed_by_employee_id': performedByEmployeeId,
            'created_by': user.id,
          })
          .select()
          .single();
      
      return NonConformity.fromJson(response);
    } catch (e) {
      debugPrint('[NonConformityRepo] ❌ Error creating non-conformity: $e');
      throw Exception('Failed to create non-conformity: $e');
    }
  }

  /// Update a non-conformity
  Future<NonConformity> update({
    required String id,
    bool? temperatureNonCompliant,
    bool? packagingOpened,
    bool? packagingWet,
    bool? labelMissing,
    String? declarationText,
    List<String>? photoUrls,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (temperatureNonCompliant != null) updates['temperature_non_compliant'] = temperatureNonCompliant;
      if (packagingOpened != null) updates['packaging_opened'] = packagingOpened;
      if (packagingWet != null) updates['packaging_wet'] = packagingWet;
      if (labelMissing != null) updates['label_missing'] = labelMissing;
      if (declarationText != null) updates['declaration_text'] = declarationText;
      if (photoUrls != null) updates['photo_urls'] = photoUrls;

      final response = await _client
          .from('non_conformities')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return NonConformity.fromJson(response);
    } catch (e) {
      debugPrint('[NonConformityRepo] ❌ Error updating non-conformity: $e');
      throw Exception('Failed to update non-conformity: $e');
    }
  }
}



