import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produit.dart';

/// Repository for supplier-product relationships
class SupplierProductRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get products for a specific supplier
  Future<List<Produit>> getProductsBySupplier(String supplierId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[SupplierProductRepo] No authenticated user');
        return [];
      }

      debugPrint('[SupplierProductRepo] Fetching products for supplier: $supplierId');
      
      // Get products linked to this supplier via supplier_products
      final response = await _client
          .from('supplier_products')
          .select('''
            product_id,
            produits!inner(
              id,
              nom,
              description,
              category,
              type_produit,
              created_at,
              updated_at
            )
          ''')
          .eq('supplier_id', supplierId);

      final products = <Produit>[];
      for (var item in response as List) {
        if (item['produits'] != null) {
          products.add(Produit.fromJson(item['produits'] as Map<String, dynamic>));
        }
      }

      debugPrint('[SupplierProductRepo] ✅ Fetched ${products.length} products for supplier');
      return products;
    } catch (e) {
      debugPrint('[SupplierProductRepo] ❌ Error: $e');
      return [];
    }
  }

  /// Get supplier-product relationship details (default lot, DLUO days)
  Future<Map<String, dynamic>?> getSupplierProductDetails({
    required String supplierId,
    required String productId,
  }) async {
    try {
      final response = await _client
          .from('supplier_products')
          .select()
          .eq('supplier_id', supplierId)
          .eq('product_id', productId)
          .maybeSingle();

      if (response == null) return null;
      return {
        'default_lot_number': response['default_lot_number'] as String?,
        'default_dluo_days': response['default_dluo_days'] as int?,
      };
    } catch (e) {
      debugPrint('[SupplierProductRepo] ❌ Error getting details: $e');
      return null;
    }
  }

  /// Link a product to a supplier
  Future<void> linkProductToSupplier({
    required String supplierId,
    required String productId,
    String? defaultLotNumber,
    int? defaultDluoDays,
  }) async {
    try {
      await _client.from('supplier_products').insert({
        'supplier_id': supplierId,
        'product_id': productId,
        'default_lot_number': defaultLotNumber,
        'default_dluo_days': defaultDluoDays,
      });
      debugPrint('[SupplierProductRepo] ✅ Linked product to supplier');
    } catch (e) {
      debugPrint('[SupplierProductRepo] ❌ Error linking: $e');
      throw Exception('Failed to link product to supplier: $e');
    }
  }
}



