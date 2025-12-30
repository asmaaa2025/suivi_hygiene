import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/temperature.dart';

/// Repository for temperature readings
class TemperatureRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all temperature readings
  Future<List<Temperature>> getAll({DateTime? startDate, DateTime? endDate}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[TemperatureRepo] No authenticated user');
        return [];
      }

      debugPrint('[TemperatureRepo] Fetching temperatures, user: ${user.id}');
      var query = _client
          .from('temperatures')
          .select()
          .eq('owner_id', user.id);
      
      // Apply date filters if provided
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        query = query.gte('date', startOfDay.toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('date', endOfDay.toIso8601String());
      }
      
      final response = await query.order('date', ascending: false);
      
      final temperatures = (response as List)
          .map((json) => Temperature.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[TemperatureRepo] ✅ Fetched ${temperatures.length} temperatures');
      return temperatures;
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error: $e');
      throw Exception('Failed to fetch temperatures: $e');
    }
  }

  /// Get temperatures for a specific device
  Future<List<Temperature>> getByAppareil(String appareilId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _client
          .from('temperatures')
          .select()
          .eq('appareil_id', appareilId)
          .eq('owner_id', user.id)
          .order('date', ascending: false);
      
      return (response as List)
          .map((json) => Temperature.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error: $e');
      throw Exception('Failed to fetch temperatures: $e');
    }
  }

  /// Create a new temperature reading
  Future<Temperature> create({
    required String appareilId,
    required double temperature,
    String? remarque,
    String? photoUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('temperatures')
          .insert({
            'appareil_id': appareilId,
            'temperature': temperature,
            'remarque': remarque,
            'photo_url': photoUrl,
            'owner_id': user.id,
          })
          .select()
          .single();
      
      return Temperature.fromJson(response);
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error creating temperature: $e');
      throw Exception('Failed to create temperature: $e');
    }
  }

  /// Delete a temperature reading
  Future<void> delete(String id) async {
    try {
      await _client.from('temperatures').delete().eq('id', id);
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error deleting temperature: $e');
      throw Exception('Failed to delete temperature: $e');
    }
  }
}
