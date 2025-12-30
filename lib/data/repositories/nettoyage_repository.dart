import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nettoyage.dart';

/// Repository for cleaning records (nettoyages)
class NettoyageRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get nettoyages for a specific date
  Future<List<Nettoyage>> getByDate(DateTime date) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('nettoyages')
          .select()
          .eq('owner_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Nettoyage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NettoyageRepo] Error fetching nettoyages: $e');
      return [];
    }
  }

  /// Get nettoyage for a specific task on a specific date
  Future<Nettoyage?> getByTacheAndDate(String tacheId, DateTime date) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('nettoyages')
          .select()
          .eq('tache_id', tacheId)
          .eq('owner_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .maybeSingle();

      if (response == null) return null;
      return Nettoyage.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NettoyageRepo] Error fetching nettoyage: $e');
      return null;
    }
  }

  /// Create a nettoyage record (mark task as done)
  Future<Nettoyage> create({
    required String tacheId,
    bool conforme = true,
    String? remarque,
    String? photoUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final response = await _client
          .from('nettoyages')
          .insert({
            'tache_id': tacheId,
            'done': true,
            'done_at': now.toIso8601String(),
            'conforme': conforme,
            'remarque': remarque,
            'photo_url': photoUrl,
            'owner_id': user.id,
            // Note: created_by is a legacy column and may not be accessible via RLS
            // owner_id will be set automatically by the database default
          })
          .select()
          .single();

      return Nettoyage.fromJson(response);
    } catch (e) {
      debugPrint('[NettoyageRepo] Error creating nettoyage: $e');
      throw Exception('Failed to create nettoyage: $e');
    }
  }

  /// Update a nettoyage record
  Future<Nettoyage> update({
    required String id,
    bool? done,
    bool? conforme,
    String? remarque,
    String? photoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (done != null) {
        updates['done'] = done;
        if (done) {
          updates['done_at'] = DateTime.now().toIso8601String();
        } else {
          updates['done_at'] = null;
        }
      }
      if (conforme != null) updates['conforme'] = conforme;
      if (remarque != null) updates['remarque'] = remarque;
      if (photoUrl != null) updates['photo_url'] = photoUrl;

      final response = await _client
          .from('nettoyages')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Nettoyage.fromJson(response);
    } catch (e) {
      debugPrint('[NettoyageRepo] Error updating nettoyage: $e');
      throw Exception('Failed to update nettoyage: $e');
    }
  }

  /// Get all completed nettoyages (history)
  Future<List<Nettoyage>> getAllCompleted({int? limit, DateTime? startDate, DateTime? endDate}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      var query = _client
          .from('nettoyages')
          .select()
          .eq('owner_id', user.id)
          .eq('done', true);
      
      // Apply date filters if provided
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        query = query.gte('done_at', startOfDay.toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('done_at', endOfDay.toIso8601String());
      }
      
      // Apply ordering and limit
      var finalQuery = query.order('done_at', ascending: false);
      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      return (response as List)
          .map((json) => Nettoyage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NettoyageRepo] Error fetching all nettoyages: $e');
      return [];
    }
  }

  /// Delete a nettoyage record
  Future<void> delete(String id) async {
    try {
      await _client.from('nettoyages').delete().eq('id', id);
    } catch (e) {
      debugPrint('[NettoyageRepo] Error deleting nettoyage: $e');
      throw Exception('Failed to delete nettoyage: $e');
    }
  }
}

