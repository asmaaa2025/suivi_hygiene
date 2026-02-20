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

      debugPrint(
        '[SupplierProductRepo] Fetching products for supplier: $supplierId',
      );

      // First, get product IDs linked to this supplier
      final linkResponse = await _client
          .from('supplier_products')
          .select('product_id')
          .eq('supplier_id', supplierId);

      if (linkResponse.isEmpty) {
        debugPrint('[SupplierProductRepo] No products linked to supplier');
        return [];
      }

      final productIds = (linkResponse as List)
          .map((item) => item['product_id'] as String)
          .toList();

      debugPrint(
        '[SupplierProductRepo] Found ${productIds.length} linked product IDs',
      );

      // Then, fetch the actual products
      final productsResponse = await _client
          .from('produits')
          .select()
          .inFilter('id', productIds)
          .eq('owner_id', user.id);

      final products = (productsResponse as List).map((json) {
        // Map categorie to category for the model
        final productJson = Map<String, dynamic>.from(json);
        if (productJson.containsKey('categorie') &&
            !productJson.containsKey('category')) {
          productJson['category'] = productJson['categorie'];
        }
        return Produit.fromJson(productJson);
      }).toList();

      debugPrint(
        '[SupplierProductRepo] ✅ Fetched ${products.length} products for supplier',
      );
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
      debugPrint(
        '[SupplierProductRepo] [LINK] Linking product $productId to supplier $supplierId',
      );

      // Check if link already exists
      final existing = await _client
          .from('supplier_products')
          .select('id')
          .eq('supplier_id', supplierId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        debugPrint(
          '[SupplierProductRepo] [LINK] ⚠️ Link already exists, skipping',
        );
        return;
      }

      final insertData = {
        'supplier_id': supplierId,
        'product_id': productId,
        if (defaultLotNumber != null) 'default_lot_number': defaultLotNumber,
        if (defaultDluoDays != null) 'default_dluo_days': defaultDluoDays,
      };

      debugPrint('[SupplierProductRepo] [LINK] Insert data: $insertData');

      await _client.from('supplier_products').insert(insertData);
      debugPrint('[SupplierProductRepo] ✅ Linked product to supplier');
    } on PostgrestException catch (e) {
      debugPrint('[SupplierProductRepo] ❌ PostgrestException linking:');
      debugPrint('[SupplierProductRepo]   - code: ${e.code}');
      debugPrint('[SupplierProductRepo]   - message: ${e.message}');
      debugPrint('[SupplierProductRepo]   - details: ${e.details}');
      debugPrint('[SupplierProductRepo]   - hint: ${e.hint}');
      throw Exception('Failed to link product to supplier: ${e.message}');
    } catch (e) {
      debugPrint('[SupplierProductRepo] ❌ Error linking: $e');
      throw Exception('Failed to link product to supplier: $e');
    }
  }
}
