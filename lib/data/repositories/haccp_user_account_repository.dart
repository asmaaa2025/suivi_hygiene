import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/haccp_user_account.dart';
import 'organization_repository.dart';

/// Repository pour les comptes utilisateurs HACCPilot (admin only)
/// Distinct du registre personnel - gestion des comptes de connexion à l'app
class HaccpUserAccountRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Liste les comptes créés par l'admin connecté
  Future<List<HaccpUserAccount>> getAll() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('haccp_user_accounts')
          .select()
          .eq('created_by', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => HaccpUserAccount.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[HaccpUserAccountRepo] Error: $e');
      rethrow;
    }
  }

  /// Crée un compte HACCPilot via Edge Function puis enregistre dans la table
  Future<HaccpUserAccount> create({
    required String email,
    required String password,
    String? displayName,
    String? personnelId,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Vous devez être connecté');
      }

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final response = await _client.functions.invoke(
        'create-haccp-user',
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'displayName': displayName?.trim().isEmpty == true ? null : displayName?.trim(),
        },
      );

      if (response.status != 200) {
        final err = response.data is Map ? (response.data['error'] ?? response.data) : response.data;
        throw Exception(err.toString());
      }

      final data = response.data as Map<String, dynamic>?;
      final authUserId = data?['id'] as String?;
      final createdEmail = (data?['email'] ?? email) as String;

      final insertData = <String, dynamic>{
        'email': createdEmail,
        'auth_user_id': authUserId,
        'display_name': displayName?.trim().isEmpty == true ? null : displayName?.trim(),
        'organization_id': orgId,
        if (personnelId != null && personnelId.isNotEmpty) 'personnel_id': personnelId,
        'created_by': user.id,
      };

      final row = await _client
          .from('haccp_user_accounts')
          .insert(insertData)
          .select()
          .single();

      return HaccpUserAccount.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[HaccpUserAccountRepo] Create error: $e');
      rethrow;
    }
  }

  /// Supprime un enregistrement de compte (n'affecte pas auth.users)
  Future<void> delete(String id) async {
    await _client.from('haccp_user_accounts').delete().eq('id', id);
  }
}
