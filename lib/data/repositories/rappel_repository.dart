/// Repository pour le plan de rappel (gestion des crises sanitaires)
/// Table Supabase: rappels (créer via migration si nécessaire)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rappel.dart';
import 'organization_repository.dart';

class RappelRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Rappel>> getAll() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final response = await _client
          .from('rappels')
          .select()
          .eq('organization_id', orgId)
          .order('date_detection', ascending: false);

      return (response as List)
          .map((json) => Rappel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[RappelRepo] Error: $e');
      return [];
    }
  }

  Future<Rappel?> getById(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final response = await _client
          .from('rappels')
          .select()
          .eq('id', id)
          .eq('organization_id', orgId)
          .maybeSingle();

      if (response == null) return null;
      return Rappel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[RappelRepo] Error: $e');
      return null;
    }
  }

  Future<Rappel> create(Rappel rappel) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non authentifié');

    final orgRepo = OrganizationRepository();
    final orgId = await orgRepo.getOrCreateOrganization();

    final insertData = {
      'produit_nom': rappel.produitNom,
      'lot': rappel.lot,
      'fournisseur': rappel.fournisseur,
      'motif': rappel.motif,
      'date_detection': rappel.dateDetection.toIso8601String().split('T')[0],
      'statut': rappel.statut.value,
      'actions_prises': rappel.actionsPrises,
      'contact_ddpp': rappel.contactDdpp,
      'organization_id': orgId,
      'created_by': user.id,
    };

    final response = await _client
        .from('rappels')
        .insert(insertData)
        .select()
        .single();
    return Rappel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> update(Rappel rappel) async {
    final orgRepo = OrganizationRepository();
    final orgId = await orgRepo.getOrCreateOrganization();

    await _client
        .from('rappels')
        .update({
          'produit_nom': rappel.produitNom,
          'lot': rappel.lot,
          'fournisseur': rappel.fournisseur,
          'motif': rappel.motif,
          'date_detection': rappel.dateDetection.toIso8601String().split(
            'T',
          )[0],
          'statut': rappel.statut.value,
          'actions_prises': rappel.actionsPrises,
          'contact_ddpp': rappel.contactDdpp,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rappel.id)
        .eq('organization_id', orgId);
  }

  Future<void> delete(String id) async {
    final orgRepo = OrganizationRepository();
    final orgId = await orgRepo.getOrCreateOrganization();
    await _client
        .from('rappels')
        .delete()
        .eq('id', id)
        .eq('organization_id', orgId);
  }
}
