import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reception.dart';

/// Repository for receptions
class ReceptionRepository {
  final SupabaseClient _client = Supabase.instance.client;
  
  // Expose client for audit log creation
  SupabaseClient get client => _client;

  /// Get all receptions
  Future<List<Reception>> getAll({DateTime? startDate, DateTime? endDate}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[ReceptionRepo] No authenticated user');
        return [];
      }

      debugPrint('[ReceptionRepo] Fetching receptions, user: ${user.id}');
      var query = _client
          .from('receptions')
          .select()
          .eq('owner_id', user.id);
      
      // Apply date filters if provided
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        query = query.gte('received_at', startOfDay.toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('received_at', endOfDay.toIso8601String());
      }
      
      final response = await query.order('received_at', ascending: false);
      
      final receptions = (response as List)
          .map((json) => Reception.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[ReceptionRepo] ✅ Fetched ${receptions.length} receptions');
      return receptions;
    } catch (e) {
      debugPrint('[ReceptionRepo] ❌ Error: $e');
      throw Exception('Failed to fetch receptions: $e');
    }
  }

  /// Create a new reception
  /// Reception time can be customized (defaults to 10:00)
  Future<Reception> create({
    required String produitId,
    required String supplierId,
    String? lot,
    DateTime? dluo,
    required double temperature,
    String? remarque,
    String? photoUrl,
    String? nonConformityId,
    String? performedByEmployeeId,
    int? receptionHour,
    int? receptionMinute,
    bool isNonConformant = false, // Flag for incomplete checklist
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Reception time (defaults to 10:00 if not provided)
      final hour = receptionHour ?? 10;
      final minute = receptionMinute ?? 0;
      final now = DateTime.now();
      final receptionDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      final response = await _client
          .from('receptions')
          .insert({
            'produit_id': produitId,
            'supplier_id': supplierId, // Link to supplier (new column)
            'fournisseur_id': supplierId, // Legacy column for compatibility
            'lot': lot,
            'dluo': dluo?.toIso8601String(),
            'temperature': temperature,
            'remarque': remarque,
            'photo_url': photoUrl,
            'received_at': receptionDateTime.toIso8601String(),
            'reception_time': '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
            'non_conformity_id': nonConformityId,
            'performed_by_employee_id': performedByEmployeeId,
            'owner_id': user.id,
          })
          .select()
          .single();
      
      return Reception.fromJson(response);
    } catch (e) {
      debugPrint('[ReceptionRepo] ❌ Error creating reception: $e');
      throw Exception('Failed to create reception: $e');
    }
  }

  /// Update a reception
  Future<Reception> update({
    required String id,
    String? lot,
    DateTime? dluo,
    double? temperature,
    String? remarque,
    String? photoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (lot != null) updates['lot'] = lot;
      if (dluo != null) updates['dluo'] = dluo.toIso8601String();
      if (temperature != null) updates['temperature'] = temperature;
      if (remarque != null) updates['remarque'] = remarque;
      if (photoUrl != null) updates['photo_url'] = photoUrl;

      final response = await _client
          .from('receptions')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Reception.fromJson(response);
    } catch (e) {
      debugPrint('[ReceptionRepo] ❌ Error updating reception: $e');
      throw Exception('Failed to update reception: $e');
    }
  }

  /// Delete a reception
  Future<void> delete(String id) async {
    try {
      await _client.from('receptions').delete().eq('id', id);
    } catch (e) {
      debugPrint('[ReceptionRepo] ❌ Error deleting reception: $e');
      throw Exception('Failed to delete reception: $e');
    }
  }
}
