import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

/// Service for handling file uploads to Supabase Storage
class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Upload a photo file to Supabase Storage
  /// Returns the public URL of the uploaded file
  Future<String> uploadPhoto(
    File file, {
    String? fileName,
    String? bucket,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'photo_$timestamp.jpg';
      final path = '$userId/$name';
      final bucketName = bucket ?? SupabaseConfig.photosBucket;

      debugPrint(
        '[StorageService] Uploading to bucket: $bucketName, path: $path',
      );

      // Upload file to Supabase Storage
      await _client.storage
          .from(bucketName)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get public URL - Supabase getPublicUrl() returns the full URL
      // Format: https://project.supabase.co/storage/v1/object/public/bucket/path
      final url = _client.storage.from(bucketName).getPublicUrl(path);

      debugPrint('[StorageService] Upload successful, URL: $url');

      // Verify it's a full URL (should always be with Supabase)
      if (!url.startsWith('http')) {
        // Fallback: construct full URL manually
        return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/$bucketName/$path';
      }

      return url;
    } catch (e) {
      debugPrint('[StorageService] Error uploading photo: $e');
      throw Exception('Failed to upload photo to Supabase Storage: $e');
    }
  }

  /// Delete a photo from Supabase Storage
  Future<void> deletePhoto(String url) async {
    try {
      // Extract path from full URL
      // URL format: https://project.supabase.co/storage/v1/object/public/bucket/userId/filename.jpg
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Find the bucket name index and get everything after it
      final bucketIndex = pathSegments.indexOf(SupabaseConfig.photosBucket);
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final path = pathSegments.sublist(bucketIndex + 1).join('/');
        await _client.storage.from(SupabaseConfig.photosBucket).remove([path]);
      } else {
        // Fallback: try to extract from last segments
        final path = pathSegments.length >= 2
            ? pathSegments.sublist(pathSegments.length - 2).join('/')
            : pathSegments.last;
        await _client.storage.from(SupabaseConfig.photosBucket).remove([path]);
      }
    } catch (e) {
      // Log error but don't throw - file might not exist
      print('Failed to delete photo from Supabase Storage: $e');
    }
  }

  /// Migrate a local file path to Supabase Storage
  /// Returns the new public URL if successful, null otherwise
  Future<String?> migrateLocalPhotoToStorage(String localPath) async {
    try {
      final file = File(localPath);

      // Check if file exists
      if (!await file.exists()) {
        debugPrint('[StorageService] ⚠️ Local file does not exist: $localPath');
        return null;
      }

      debugPrint(
        '[StorageService] Migrating local photo to Supabase Storage: $localPath',
      );

      // Upload to Supabase Storage
      final publicUrl = await uploadPhoto(file);

      debugPrint('[StorageService] ✅ Migration successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[StorageService] ❌ Error migrating photo: $e');
      return null;
    }
  }

  /// Check if a photo URL is a valid Supabase Storage URL
  bool isValidStorageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    // Check if it's a valid HTTP/HTTPS URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Check if it's a Supabase Storage URL
      return url.contains('/storage/v1/object/public/') ||
          url.contains('supabase.co/storage/') ||
          url.contains('supabase.in/storage/');
    }

    return false;
  }

  /// Check if a photo URL is a local file path
  bool isLocalPath(String? url) {
    if (url == null || url.isEmpty) return false;

    // Check if it looks like a local file path (not starting with http)
    return !url.startsWith('http://') &&
        !url.startsWith('https://') &&
        !url.startsWith('/storage/');
  }
}
