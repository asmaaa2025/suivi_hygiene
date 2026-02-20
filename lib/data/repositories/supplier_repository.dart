import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier.dart';

/// Repository for suppliers
class SupplierRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Expose client for organization access
  SupabaseClient get client => _client;

  /// Get all suppliers for the current user's organization
  Future<List<Supplier>> getAll({bool? includeOccasional}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[SupplierRepo] No authenticated user');
        return [];
      }

      debugPrint('[SupplierRepo] Fetching suppliers, user: ${user.id}');
      var query = _client.from('suppliers').select().eq('owner_id', user.id);

      if (includeOccasional != null) {
        query = query.eq('is_occasional', includeOccasional);
      }

      final response = await query.order('name');

      final suppliers = (response as List)
          .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[SupplierRepo] ✅ Fetched ${suppliers.length} suppliers');
      return suppliers;
    } catch (e) {
      debugPrint('[SupplierRepo] ❌ Error: $e');
      throw Exception('Failed to fetch suppliers: $e');
    }
  }

  /// Get supplier by ID
  Future<Supplier?> getById(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('suppliers')
          .select()
          .eq('id', id)
          .eq('owner_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SupplierRepo] ❌ Error: $e');
      return null;
    }
  }

  /// Create a new supplier
  Future<Supplier> create({
    required String organizationId,
    required String name,
    String? contactInfo,
    bool isOccasional = false,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('suppliers')
          .insert({
            'organization_id': organizationId,
            'name': name,
            'contact_info': contactInfo,
            'is_occasional': isOccasional,
            'owner_id': user.id,
            'created_by': user.id,
          })
          .select()
          .single();

      return Supplier.fromJson(response);
    } catch (e) {
      debugPrint('[SupplierRepo] ❌ Error creating supplier: $e');
      throw Exception('Failed to create supplier: $e');
    }
  }

  /// Update a supplier
  Future<Supplier> update({
    required String id,
    String? name,
    String? contactInfo,
    bool? isOccasional,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (contactInfo != null) updates['contact_info'] = contactInfo;
      if (isOccasional != null) updates['is_occasional'] = isOccasional;

      final response = await _client
          .from('suppliers')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Supplier.fromJson(response);
    } catch (e) {
      debugPrint('[SupplierRepo] ❌ Error updating supplier: $e');
      throw Exception('Failed to update supplier: $e');
    }
  }

  /// Delete a supplier
  Future<void> delete(String id) async {
    try {
      await _client.from('suppliers').delete().eq('id', id);
    } catch (e) {
      debugPrint('[SupplierRepo] ❌ Error deleting supplier: $e');
      throw Exception('Failed to delete supplier: $e');
    }
  }
}
