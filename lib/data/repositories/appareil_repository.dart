import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appareil.dart';

/// Repository for managing devices (appareils)
class AppareilRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all devices
  Future<List<Appareil>> getAll() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[AppareilRepo] No authenticated user');
        return [];
      }

      debugPrint('[AppareilRepo] Fetching appareils, user: ${user.id}');
      final response = await _client.from('appareils').select().order('nom');
      final appareils = (response as List)
          .map((json) => Appareil.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[AppareilRepo] ✅ Fetched ${appareils.length} appareils');
      return appareils;
    } catch (e) {
      if (e.toString().contains('PostgrestException') ||
          e.toString().contains('PGRST')) {
        debugPrint('[AppareilRepo] ❌ Supabase error: $e');
        throw Exception('Failed to fetch devices: $e');
      }
      debugPrint('[AppareilRepo] ❌ Error: $e');
      throw Exception('Failed to fetch devices: $e');
    }
  }

  /// Create a new device
  Future<Appareil> create({
    required String nom,
    double? tempMin,
    double? tempMax,
  }) async {
    try {
      final response = await _client
          .from('appareils')
          .insert({
            'nom': nom,
            'temp_min': tempMin,
            'temp_max': tempMax,
          })
          .select()
          .single();
      return Appareil.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create device: $e');
    }
  }

  /// Update a device
  Future<Appareil> update({
    required String id,
    String? nom,
    double? tempMin,
    double? tempMax,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nom != null) updates['nom'] = nom;
      if (tempMin != null) updates['temp_min'] = tempMin;
      if (tempMax != null) updates['temp_max'] = tempMax;

      final response = await _client
          .from('appareils')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      return Appareil.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update device: $e');
    }
  }

  /// Delete a device
  Future<void> delete(String id) async {
    try {
      await _client.from('appareils').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete device: $e');
    }
  }
}
