import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produit.dart';

/// Repository for products (produits)
class ProduitRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all products
  Future<List<Produit>> getAll() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[ProduitRepo] No authenticated user');
        return [];
      }

      debugPrint('[ProduitRepo] Fetching all products, user: ${user.id}');
      final response = await _client
          .from('produits')
          .select()
          .eq('owner_id', user.id)
          .order('nom');
      
      final products = (response as List)
          .map((json) => Produit.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[ProduitRepo] ✅ Fetched ${products.length} products');
      return products;
    } catch (e) {
      debugPrint('[ProduitRepo] ❌ Error: $e');
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get product by ID
  Future<Produit?> getById(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('produits')
          .select()
          .eq('id', id)
          .eq('owner_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Produit.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ProduitRepo] ❌ Error: $e');
      return null;
    }
  }

  /// Create a new product
  Future<Produit> create({
    required String nom,
    String? description,
    String? category,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('produits')
          .insert({
            'nom': nom,
            'description': description,
            'category': category,
            'owner_id': user.id,
          })
          .select()
          .single();
      
      return Produit.fromJson(response);
    } catch (e) {
      debugPrint('[ProduitRepo] ❌ Error creating product: $e');
      throw Exception('Failed to create product: $e');
    }
  }

  /// Update a product
  Future<Produit> update({
    required String id,
    String? nom,
    String? description,
    String? category,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nom != null) updates['nom'] = nom;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;

      final response = await _client
          .from('produits')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Produit.fromJson(response);
    } catch (e) {
      debugPrint('[ProduitRepo] ❌ Error updating product: $e');
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete a product
  Future<void> delete(String id) async {
    try {
      await _client.from('produits').delete().eq('id', id);
    } catch (e) {
      debugPrint('[ProduitRepo] ❌ Error deleting product: $e');
      throw Exception('Failed to delete product: $e');
    }
  }
}
