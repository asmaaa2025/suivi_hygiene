import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exceptions.dart';
import '../services/supabase_service.dart';

/// Repository for products (Supabase-only, no cache)
class ProductsRepository {
  final SupabaseService _supabase = SupabaseService();

  String get tableName => 'produits';
  SupabaseClient get client => _supabase.client;
  String get userId => _supabase.currentUserId;

  /// Get all products
  Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('[ProductsRepo] No authenticated user');
        return [];
      }

      debugPrint('[ProductsRepo] Fetching all products, user: ${user.id}');
      final response = await client
          .from(tableName)
          .select()
          .eq('owner_id', user.id)
          .order('nom');
      final List<Map<String, dynamic>> list =
          List<Map<String, dynamic>>.from(response);
      debugPrint('[ProductsRepo] ✅ Fetched ${list.length} products');
      return list;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('PostgrestException') ||
          errorStr.contains('PGRST')) {
        debugPrint('[ProductsRepo] ❌ Supabase error: $e');
        throw SupabaseException('Failed to fetch products: $errorStr');
      }
      debugPrint('[ProductsRepo] ❌ Error: $e');
      throw SupabaseException('Failed to fetch products: $e');
    }
  }

  /// Create product
  Future<Map<String, dynamic>> createProduct({
    required String nom,
    String? typeProduit,
    String? dlc,
    int? dlcJours,
    String? lot,
    double? poids,
    DateTime? dateFabrication,
    bool? surgelagable,
    int? dlcSurgelationJours,
    String? ingredients,
    String? quantite,
    String? origineViande,
    String? allergenes,
  }) async {
    try {
      debugPrint('[ProductsRepo] Creating product: $nom');
      final record = <String, dynamic>{
        'nom': nom,
        'type_produit': typeProduit,
        'dlc_jours': dlcJours,
        'dlc_surgelation_jours': dlcSurgelationJours,
        'ingredients': ingredients,
        'quantite': quantite,
        'origine_viande': origineViande,
        'allergenes': allergenes,
        'date_fabrication': dateFabrication?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'date_modification': DateTime.now().toIso8601String(),
        'surgelagable': (surgelagable ?? false) ? 1 : 0,
        'actif': true,
      };

      final result =
          await client.from(tableName).insert(record).select().single();

      debugPrint('[ProductsRepo] ✅ Created product ${result['id']}');
      return result;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('PostgrestException') ||
          errorStr.contains('PGRST')) {
        debugPrint('[ProductsRepo] ❌ Supabase error: $e');
        throw SupabaseException('Failed to create product: $errorStr');
      }
      debugPrint('[ProductsRepo] ❌ Error: $e');
      throw SupabaseException('Failed to create product: $e');
    }
    return <String, dynamic>{};
  }

  /// Update product
  Future<Map<String, dynamic>> updateProduct(
    String id, {
    String? nom,
    String? typeProduit,
    String? dlc,
    int? dlcJours,
    String? lot,
    double? poids,
    DateTime? dateFabrication,
    bool? surgelagable,
    int? dlcSurgelationJours,
    String? ingredients,
    String? quantite,
    String? origineViande,
    String? allergenes,
  }) async {
    try {
      debugPrint('[ProductsRepo] Updating product: $id');
      final updates = <String, dynamic>{
        'date_modification': DateTime.now().toIso8601String(),
      };

      if (nom != null) updates['nom'] = nom;
      if (typeProduit != null) updates['type_produit'] = typeProduit;
      if (dlcJours != null) updates['dlc_jours'] = dlcJours;
      if (dlcSurgelationJours != null) {
        updates['dlc_surgelation_jours'] = dlcSurgelationJours;
      }
      if (ingredients != null) updates['ingredients'] = ingredients;
      if (quantite != null) updates['quantite'] = quantite;
      if (origineViande != null) updates['origine_viande'] = origineViande;
      if (allergenes != null) updates['allergenes'] = allergenes;
      if (dateFabrication != null) {
        updates['date_fabrication'] = dateFabrication.toIso8601String();
      }
      if (surgelagable != null) updates['surgelagable'] = surgelagable ? 1 : 0;

      final result = await client
          .from(tableName)
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      debugPrint('[ProductsRepo] ✅ Updated product $id');
      return result;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('PostgrestException') ||
          errorStr.contains('PGRST')) {
        debugPrint('[ProductsRepo] ❌ Supabase error: $e');
        throw SupabaseException('Failed to update product: $errorStr');
      }
      debugPrint('[ProductsRepo] ❌ Error: $e');
      throw SupabaseException('Failed to update product: $e');
    }
    return <String, dynamic>{};
  }

  /// Delete product
  Future<void> deleteProduct(String id) async {
    try {
      debugPrint('[ProductsRepo] Deleting product: $id');
      await client.from(tableName).delete().eq('id', id);
      debugPrint('[ProductsRepo] ✅ Deleted product $id');
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('PostgrestException') ||
          errorStr.contains('PGRST')) {
        debugPrint('[ProductsRepo] ❌ Supabase error: $e');
        throw SupabaseException('Failed to delete product: $errorStr');
      }
      debugPrint('[ProductsRepo] ❌ Error: $e');
      throw SupabaseException('Failed to delete product: $e');
    }
  }

  /// Get product by ID
  Future<Map<String, dynamic>> getById(String id) async {
    try {
      final response =
          await client.from(tableName).select().eq('id', id).single();
      return response as Map<String, dynamic>;
    } catch (e) {
      throw SupabaseException('Failed to fetch product: $e');
    }
  }

  /// Create product (alias for createProduct)
  Future<Map<String, dynamic>> create({
    required String nom,
    String? categorie,
    String? allergenes,
    bool? actif,
  }) async {
    return createProduct(
      nom: nom,
      typeProduit: categorie,
      allergenes: allergenes,
    );
  }

  /// Update product (alias for updateProduct)
  Future<Map<String, dynamic>> update({
    required String id,
    String? nom,
    String? categorie,
    String? allergenes,
    bool? actif,
  }) async {
    return updateProduct(
      id,
      nom: nom,
      typeProduit: categorie,
      allergenes: allergenes,
    );
  }
}
