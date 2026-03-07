import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/network_service.dart';
import '../exceptions/app_exceptions.dart';
import '../modules/haccp/documents/models.dart';
import 'base_repository.dart';

/// Repository for documents (Storage + metadata)
class DocumentsRepository extends BaseRepository {
  @override
  String get tableName => 'documents';

  static const String _storageBucket = 'documents';

  final SupabaseService _supabase = SupabaseService();
  final NetworkService _network = NetworkService();

  /// Get all documents (optionally filter by folder)
  Future<List<Map<String, dynamic>>> getAll({String? cacheKey}) async {
    return await fetchList(cacheKey: cacheKey ?? 'all');
  }

  /// Get documents and folders inside a folder (null = root).
  /// Falls back to getAll() filtered in memory if dossier_id column is missing.
  Future<List<Map<String, dynamic>>> getByFolderId(String? folderId) async {
    await _network.hasConnection();
    if (!await _network.hasConnection()) {
      throw NetworkException('Network required');
    }
    try {
      var query = client.from(tableName).select().eq('user_id', userId);
      if (folderId == null) {
        query = query.isFilter('dossier_id', null);
      } else {
        query = query.eq('dossier_id', folderId);
      }
      final data = await query.order('nom');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      // Fallback when dossier_id column does not exist yet (pre-migration)
      final all = await getAll(cacheKey: null);
      final docs = all.map((json) => Document.fromJson(json)).toList();
      final filtered = docs.where((d) => d.folderId == folderId).toList();
      filtered.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
      return filtered.map((d) => d.toJson()).toList();
    }
  }

  /// Get all folders (for move destination picker)
  Future<List<Map<String, dynamic>>> getAllFolders() async {
    await _network.hasConnection();
    if (!await _network.hasConnection()) {
      throw NetworkException('Network required');
    }
    final data = await client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('categorie', 'dossier')
        .order('nom');
    return List<Map<String, dynamic>>.from(data);
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

  /// Create document record (or folder when categorie == 'dossier' and storageUrl empty)
  Future<Map<String, dynamic>> createDocument({
    required String nom,
    required String categorie,
    required String storageUrl,
    int? taille,
    DateTime? documentDate,
    String? dossierId,
  }) async {
    final data = <String, dynamic>{
      'nom': nom,
      'categorie': categorie,
      'chemin': storageUrl,
      'date': (documentDate ?? DateTime.now()).toIso8601String(),
    };
    if (taille != null) data['taille'] = taille;
    if (dossierId != null) data['dossier_id'] = dossierId;
    return await super.create(data);
  }

  /// Update document metadata (rename, move, etc.)
  /// [dossierId]: set folder; use [clearDossierId: true] to move to root.
  Future<Map<String, dynamic>> updateDocument({
    required String id,
    String? title,
    String? nom,
    DocumentCategory? category,
    DateTime? documentDate,
    String? notes,
    String? dossierId,
    bool clearDossierId = false,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['titre'] = title;
    if (nom != null) data['nom'] = nom;
    if (category != null) data['categorie'] = category.name;
    if (documentDate != null) data['date'] = documentDate.toIso8601String();
    if (notes != null) data['notes'] = notes;
    if (clearDossierId) {
      data['dossier_id'] = null;
    } else if (dossierId != null) {
      data['dossier_id'] = dossierId;
    }
    return await update(id, data);
  }

  /// Delete document (both DB and Storage)
  Future<void> deleteDocument(String id, String? storagePath) async {
    try {
      await _network.hasConnection();
      if (!await _network.hasConnection()) {
        throw NetworkException('Network required');
      }

      // Delete from Storage if path provided (skip for folders with empty path)
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await _supabase.client.storage.from(_storageBucket).remove([
            storagePath,
          ]);
          debugPrint('[Documents] Deleted file from storage: $storagePath');
        } catch (e) {
          debugPrint(
            '[Documents] Warning: Could not delete file from storage: $e',
          );
        }
      }

      // Delete from DB
      await delete(id);
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw SupabaseException('Failed to delete document: ${e.toString()}');
    }
  }

  /// Delete folder and move its contents to parent (or root)
  Future<void> deleteFolder(String folderId, String? parentFolderId) async {
    final children = await getByFolderId(folderId);
    for (final raw in children) {
      final id = raw['id'] as String?;
      if (id == null) continue;
      if (parentFolderId != null) {
        await updateDocument(id: id, dossierId: parentFolderId);
      } else {
        await updateDocument(id: id, clearDossierId: true);
      }
    }
    await deleteDocument(folderId, null);
  }
}
