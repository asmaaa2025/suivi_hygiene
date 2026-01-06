import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/temperature.dart';
import '../../services/employee_session_service.dart';

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
          .select('*, photo_url')
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

  /// Get a temperature by ID
  Future<Temperature?> getById(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('temperatures')
          .select('*, photo_url')
          .eq('id', id)
          .eq('owner_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Temperature.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error fetching temperature: $e');
      return null;
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
          .select('*, photo_url')
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
    String? appareilNom, // Optional: if not provided, will fetch from DB
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[TemperatureRepo] ❌ User not authenticated');
        throw Exception('User not authenticated');
      }

      // Get current employee if available
      final employeeSessionService = EmployeeSessionService();
      await employeeSessionService.initialize();
      final currentEmployee = employeeSessionService.currentEmployee;
      final employeeId = currentEmployee?.id;
      final employeeFirstName = currentEmployee?.firstName;
      final employeeLastName = currentEmployee?.lastName;

      debugPrint('[TemperatureRepo] [CREATE] Starting create');
      debugPrint('[TemperatureRepo] [CREATE] userId: ${user.id}');
      debugPrint('[TemperatureRepo] [CREATE] employeeId: $employeeId');
      debugPrint('[TemperatureRepo] [CREATE] employeeName: $employeeFirstName $employeeLastName');
      debugPrint('[TemperatureRepo] [CREATE] appareilId: $appareilId');
      debugPrint('[TemperatureRepo] [CREATE] temperature: $temperature');

      // Get appareil name if not provided
      String? appareilName = appareilNom;
      if (appareilName == null || appareilName.isEmpty) {
        try {
          final appareilResponse = await _client
              .from('appareils')
              .select('nom')
              .eq('id', appareilId)
              .maybeSingle();
          if (appareilResponse != null) {
            appareilName = appareilResponse['nom'] as String?;
            debugPrint('[TemperatureRepo] [CREATE] Fetched appareil name: $appareilName');
          }
        } catch (e) {
          debugPrint('[TemperatureRepo] [CREATE] ⚠️ Could not fetch appareil name: $e');
          // Continue without appareil name - will use appareilId as fallback
          appareilName = appareilId;
        }
      }

      final insertData = {
        'appareil_id': appareilId,
        'appareil': appareilName ?? appareilId, // Legacy column (NOT NULL)
        'temperature': temperature,
        'remarque': remarque,
        'photo_url': photoUrl,
        'owner_id': user.id,
        'date': DateTime.now().toIso8601String(),
        'employee_first_name': employeeFirstName, // Employee who performed the action
        'employee_last_name': employeeLastName, // Employee who performed the action
      };

      debugPrint('[TemperatureRepo] [CREATE] Insert data: $insertData');

      final response = await _client
          .from('temperatures')
          .insert(insertData)
          .select()
          .single();
      
      debugPrint('[TemperatureRepo] ✅ Success: Created temperature ${response['id']}');
      return Temperature.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('[TemperatureRepo] ❌ PostgrestException creating temperature:');
      debugPrint('[TemperatureRepo]   - code: ${e.code}');
      debugPrint('[TemperatureRepo]   - message: ${e.message}');
      debugPrint('[TemperatureRepo]   - details: ${e.details}');
      debugPrint('[TemperatureRepo]   - hint: ${e.hint}');
      throw Exception('Failed to create temperature: ${e.message}');
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error creating temperature: $e');
      throw Exception('Failed to create temperature: $e');
    }
  }

  /// Update a temperature reading
  Future<Temperature> update({
    required String id,
    String? appareilId,
    double? temperature,
    String? remarque,
    String? photoUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final updates = <String, dynamic>{};
      if (appareilId != null) {
        updates['appareil_id'] = appareilId;
        // Also update legacy appareil column if we can get the name
        try {
          final appareilResponse = await _client
              .from('appareils')
              .select('nom')
              .eq('id', appareilId)
              .maybeSingle();
          if (appareilResponse != null) {
            updates['appareil'] = appareilResponse['nom'] as String?;
          }
        } catch (e) {
          debugPrint('[TemperatureRepo] ⚠️ Could not fetch appareil name: $e');
        }
      }
      if (temperature != null) updates['temperature'] = temperature;
      if (remarque != null) updates['remarque'] = remarque;
      if (photoUrl != null) updates['photo_url'] = photoUrl;

      final response = await _client
          .from('temperatures')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Temperature.fromJson(response);
    } catch (e) {
      debugPrint('[TemperatureRepo] ❌ Error updating temperature: $e');
      throw Exception('Failed to update temperature: $e');
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
