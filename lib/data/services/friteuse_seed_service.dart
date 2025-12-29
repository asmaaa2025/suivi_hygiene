import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/oil_repository.dart';

/// Service to seed default friteuses on first run
class FriteuseSeedService {
  final SupabaseClient _client = Supabase.instance.client;
  final OilRepository _oilRepo = OilRepository();

  /// Ensure default friteuses exist (idempotent)
  Future<void> ensureDefaultFriteuses() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[FriteuseSeed] No user logged in, skipping seed');
        return;
      }

      debugPrint('[FriteuseSeed] Checking for default friteuses');

      // Check existing friteuses
      final existing = await _oilRepo.getAllFriteuses();
      final existingNames = existing.map((f) => f.nom.toLowerCase()).toSet();

      // Default friteuses to create
      final defaults = ['Friteuse 1', 'Friteuse 2'];
      final toCreate = <String>[];

      for (final nom in defaults) {
        if (!existingNames.contains(nom.toLowerCase())) {
          toCreate.add(nom);
        }
      }

      if (toCreate.isEmpty) {
        debugPrint('[FriteuseSeed] All default friteuses already exist');
        return;
      }

      debugPrint(
          '[FriteuseSeed] Creating ${toCreate.length} default friteuses');

      // Create missing friteuses
      for (final nom in toCreate) {
        try {
          await _oilRepo.createFriteuse(nom: nom);
          debugPrint('[FriteuseSeed] Created: $nom');
        } catch (e) {
          debugPrint('[FriteuseSeed] Error creating $nom: $e');
        }
      }

      debugPrint('[FriteuseSeed] Seed completed');
    } catch (e) {
      debugPrint('[FriteuseSeed] Error during seed: $e');
      // Don't throw - seed failures shouldn't break the app
    }
  }
}
