// STUB: Partially implemented - needs completion
// TODO: Add proper error handling with AppExceptions
// TODO: Add RLS filtering by owner_id
// TODO: Add caching support if needed
// TODO: Add pagination for large datasets
// TODO: Implement update and delete methods for friteuses
// TODO: Add validation for oil change data

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friteuse.dart';

/// Repository for oil changes and fryers (friteuses)
/// Stub implementation to satisfy compilation
class OilRepository {
  OilRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Get all fryers (friteuses)
  Future<List<Friteuse>> getAllFriteuses() async {
    try {
      final response = await _client.from('friteuses').select().order('nom');
      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
        response,
      );
      return list.map((json) => Friteuse.fromJson(json)).toList();
    } catch (e) {
      // Return empty list on error to prevent crashes
      return [];
    }
  }

  /// Create a new fryer (friteuse)
  Future<Friteuse> createFriteuse({required String nom}) async {
    try {
      final response = await _client
          .from('friteuses')
          .insert({'nom': nom})
          .select()
          .single();
      return Friteuse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create friteuse: $e');
    }
  }

  /// Get all oil changes
  Future<List<Map<String, dynamic>>> listOilChanges() async {
    try {
      final response = await _client.from('oil_changes').select();
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Add an oil change
  Future<void> addOilChange(Map<String, dynamic> payload) async {
    await _client.from('oil_changes').insert(payload);
  }
}
