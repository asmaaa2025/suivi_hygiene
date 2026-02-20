import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for organizations
class OrganizationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get or create organization for current user
  /// Creates a default organization if none exists
  Future<String> getOrCreateOrganization() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint(
        '[OrganizationRepo] Looking for organization with id: ${user.id}',
      );

      // Try to find existing organization for this user
      // For simplicity, we'll use user.id as organization name/id
      // In production, you'd have a proper organization management

      // Check if an organization with this user's id exists
      final response = await _client
          .from('organizations')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        debugPrint(
          '[OrganizationRepo] ✅ Found existing organization: ${response['id']}',
        );
        return response['id'] as String;
      }

      debugPrint(
        '[OrganizationRepo] No organization found, creating new one...',
      );

      // Create a new organization using user.id as primary key
      try {
        final newOrg = await _client
            .from('organizations')
            .insert({
              'id': user.id, // Use user.id as organization id for simplicity
              'name': 'Organisation ${user.email ?? user.id}',
            })
            .select('id')
            .single();

        debugPrint(
          '[OrganizationRepo] ✅ Created new organization: ${newOrg['id']}',
        );
        return newOrg['id'] as String;
      } catch (e) {
        // If insert fails (e.g., constraint violation, RLS issue), try to get it again
        debugPrint(
          '[OrganizationRepo] ⚠️ Insert failed, trying to get again: $e',
        );
        final retryResponse = await _client
            .from('organizations')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (retryResponse != null) {
          debugPrint(
            '[OrganizationRepo] ✅ Found organization on retry: ${retryResponse['id']}',
          );
          return retryResponse['id'] as String;
        }

        // If still not found, log the error and throw
        debugPrint(
          '[OrganizationRepo] ❌ Failed to create or find organization: $e',
        );
        throw Exception('Failed to create or find organization: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('[OrganizationRepo] ❌ Error in getOrCreateOrganization: $e');
      debugPrint('[OrganizationRepo] Stack trace: $stackTrace');
      // Re-throw the error instead of returning empty string
      // This will make the error visible to the caller
      rethrow;
    }
  }

  /// Get organization by ID
  Future<Map<String, dynamic>?> getById(String id) async {
    try {
      final response = await _client
          .from('organizations')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[OrganizationRepo] ❌ Error: $e');
      return null;
    }
  }
}
