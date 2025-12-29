import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/network_service.dart';
import '../exceptions/app_exceptions.dart';
import 'base_repository.dart';

/// Repository for documents (Storage + metadata)
class DocumentsRepository extends BaseRepository {
  @override
  String get tableName => 'documents';

  static const String _storageBucket = 'documents';

  final SupabaseService _supabase = SupabaseService();
  final NetworkService _network = NetworkService();

  /// Get all documents
  Future<List<Map<String, dynamic>>> getAll() async {
    return await fetchList(cacheKey: 'all');
  }

  /// Upload document file to Storage
  Future<String> uploadFile(File file, String fileName) async {
    try {
      await _network.hasConnection();
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      final fileBytes = await file.readAsBytes();
      final userId = _supabase.currentUserId;
      final storagePath = '$userId/$fileName';

      await _supabase.client.storage
          .from(_storageBucket)
          .uploadBinary(storagePath, fileBytes);

      final publicUrl = _supabase.client.storage
          .from(_storageBucket)
          .getPublicUrl(storagePath);

      debugPrint('[Documents] Uploaded file $fileName');
      return publicUrl;
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to upload document: ${e.toString()}');
    }
  }

  /// Create document record
  Future<Map<String, dynamic>> createDocument({
    required String nom,
    required String categorie,
    required String storageUrl,
    int? taille,
  }) async {
    return await super.create({
      'nom': nom,
      'categorie': categorie,
      'chemin': storageUrl,
      'taille': taille,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// Delete document (both DB and Storage)
  Future<void> deleteDocument(String id, String? storagePath) async {
    try {
      await _network.hasConnection();
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      // Delete from Storage if path provided
      if (storagePath != null) {
        try {
          await _supabase.client.storage
              .from(_storageBucket)
              .remove([storagePath]);
          debugPrint('[Documents] Deleted file from storage: $storagePath');
        } catch (e) {
          debugPrint(
              '[Documents] Warning: Could not delete file from storage: $e');
        }
      }

      // Delete from DB
      await delete(id);
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to delete document: ${e.toString()}');
    }
  }
}
