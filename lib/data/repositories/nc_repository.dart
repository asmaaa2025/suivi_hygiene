/// Non-Conformity (NC) Repository
/// Complete CRUD operations for NC module with 8-section form structure

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nc_models.dart';
import 'organization_repository.dart';
import '../services/storage_service.dart';
import 'package:bekkapp/services/employee_session_service.dart';

class NCRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final StorageService _storageService = StorageService();
  final EmployeeSessionService _employeeSessionService =
      EmployeeSessionService();
  static const String _storageBucket = 'nc-files';

  // ============================================
  // MAIN NON_CONFORMITY CRUD
  // ============================================

  /// Create a draft NC from a source event
  /// Returns the created NC ID
  Future<String> createDraftFromSource({
    required NCSourceType sourceType,
    required String sourceTable,
    String? sourceId,
    required Map<String, dynamic> sourcePayload,
    String? employeeId,
    Map<String, dynamic>? prefillData,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      // Get employee ID from session if not provided
      String? finalEmployeeId = employeeId;
      if (finalEmployeeId == null) {
        finalEmployeeId = await _employeeSessionService.getCurrentEmployeeId();
      }

      // Validate employee ID - it must not be null
      if (finalEmployeeId == null) {
        throw Exception(
          'Employee ID is required but not available. Please ensure you are logged in as an employee.',
        );
      }

      // Build NC data with prefill
      final ncData = <String, dynamic>{
        'organization_id': orgId,
        'status': NCStatus.draft.value,
        'detection_date': DateTime.now().toIso8601String(),
        'source_type': sourceType.value,
        'source_table': sourceTable,
        'source_payload': sourcePayload,
        'created_by': finalEmployeeId, // Use employee ID, not user.id
        'opened_by_employee_id': finalEmployeeId,
      };

      // Add source_id only if provided
      if (sourceId != null) {
        ncData['source_id'] = sourceId;
      }

      // Apply prefill data if provided
      if (prefillData != null) {
        ncData.addAll(prefillData);
      }

      // Ensure created_by is always set to employee ID (not user.id from prefillData)
      // This prevents foreign key constraint violations
      // finalEmployeeId is guaranteed to be non-null at this point
      ncData['created_by'] = finalEmployeeId!;
      ncData['opened_by_employee_id'] = finalEmployeeId;

      // Ensure description is present (required field)
      if (ncData['description'] == null ||
          (ncData['description'] as String).isEmpty) {
        ncData['description'] = 'Non-conformité détectée automatiquement';
      }

      // Ensure object_category is present (required field)
      if (ncData['object_category'] == null) {
        ncData['object_category'] = NCObjectCategory.autre.value;
      }

      // Verify employee exists before inserting
      if (finalEmployeeId != null) {
        final employeeCheck = await _client
            .from('employees')
            .select('id')
            .eq('id', finalEmployeeId)
            .maybeSingle();

        if (employeeCheck == null) {
          throw Exception(
            'Employee ID $finalEmployeeId not found in employees table. Please ensure you are logged in as a valid employee.',
          );
        }
      }

      final response = await _client
          .from('non_conformities')
          .insert(ncData)
          .select('id')
          .single();

      final ncId = response['id'] as String;
      debugPrint('[NCRepo] ✅ Created draft NC: $ncId');
      return ncId;
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error creating draft NC: $e');

      // Provide more helpful error message for foreign key constraint violations
      if (e.toString().contains('foreign key constraint') &&
          e.toString().contains('users')) {
        throw Exception(
          'Erreur de configuration de la base de données: la contrainte created_by pointe vers la mauvaise table.\n\n'
          'Veuillez exécuter le script de migration: 31_fix_non_conformities_created_by_fkey.sql\n'
          'Ce script corrige la contrainte pour qu\'elle pointe vers public.employees au lieu de auth.users.',
        );
      }

      throw Exception('Failed to create draft NC: $e');
    }
  }

  /// Get all NCs with optional filters
  Future<List<NonConformity>> listNonConformities({
    NCStatus? status,
    NCSourceType? sourceType,
    NCObjectCategory? objectCategory,
    DateTime? startDate,
    DateTime? endDate,
    String? severity, // Not stored in DB, computed from source
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[NCRepo] No authenticated user');
        return [];
      }

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      var query = _client
          .from('non_conformities')
          .select()
          .eq('organization_id', orgId);

      // Apply filters
      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (sourceType != null) {
        query = query.eq('source_type', sourceType.value);
      }
      if (objectCategory != null) {
        query = query.eq('object_category', objectCategory.value);
      }
      if (startDate != null) {
        query = query.gte('detection_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.lte('detection_date', endOfDay.toIso8601String());
      }

      final response = await query.order('detection_date', ascending: false);

      final ncs = (response as List)
          .map((json) => NonConformity.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[NCRepo] ✅ Fetched ${ncs.length} NCs');
      return ncs;
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error listing NCs: $e');
      throw Exception('Failed to list NCs: $e');
    }
  }

  /// Get NC by ID with all related data
  Future<NonConformity?> getById(
    String id, {
    bool includeRelated = true,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      final response = await _client
          .from('non_conformities')
          .select()
          .eq('id', id)
          .eq('organization_id', orgId)
          .maybeSingle();

      if (response == null) return null;

      final nc = NonConformity.fromJson(response as Map<String, dynamic>);

      if (includeRelated) {
        // Load related data
        final causes = await getCauses(id);
        final solutions = await getSolutions(id);
        final actions = await getActions(id);
        final verifications = await getVerifications(id);
        final attachments = await getAttachments(id);

        return nc.copyWith(
          causes: causes,
          solutions: solutions,
          actions: actions,
          verifications: verifications,
          attachments: attachments,
        );
      }

      return nc;
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error fetching NC: $e');
      return null;
    }
  }

  /// Update NC
  Future<NonConformity> updateNonConformity(NonConformity nc) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      // Verify ownership
      if (nc.organizationId != orgId) {
        throw Exception('Unauthorized: NC belongs to different organization');
      }

      final updates = nc.toJson();
      // Remove fields that shouldn't be updated directly
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('organization_id');
      updates.remove('causes');
      updates.remove('solutions');
      updates.remove('actions');
      updates.remove('verifications');
      updates.remove('attachments');
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('non_conformities')
          .update(updates)
          .eq('id', nc.id)
          .eq('organization_id', orgId)
          .select()
          .single();

      debugPrint('[NCRepo] ✅ Updated NC: ${nc.id}');
      return NonConformity.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error updating NC: $e');
      throw Exception('Failed to update NC: $e');
    }
  }

  /// Save draft NC to Supabase (for persistence and history visibility)
  /// This creates or updates a draft NC in Supabase so it appears in the history
  Future<String?> saveDraftToSupabase({
    required String organizationId,
    required String employeeId,
    required Map<String, dynamic> draftData,
    String? existingNcId, // If updating an existing draft
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate employee ID
      if (employeeId.isEmpty) {
        throw Exception('Employee ID is required');
      }

      // Build NC data for draft
      final ncData = <String, dynamic>{
        'organization_id': organizationId,
        'status': NCStatus.draft.value,
        'created_by': employeeId,
        'opened_by_employee_id': employeeId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add draft data fields
      if (draftData['detection_date'] != null) {
        ncData['detection_date'] = draftData['detection_date'];
      } else {
        ncData['detection_date'] = DateTime.now().toIso8601String();
      }

      if (draftData['description'] != null &&
          (draftData['description'] as String).isNotEmpty) {
        ncData['description'] = draftData['description'];
      } else {
        ncData['description'] = 'Brouillon de non-conformité';
      }

      if (draftData['object_category'] != null) {
        ncData['object_category'] = draftData['object_category'];
      } else {
        ncData['object_category'] = NCObjectCategory.autre.value;
      }

      // Map other fields from draft
      if (draftData['source_type'] != null) {
        ncData['source_type'] = draftData['source_type'];
      }
      if (draftData['source_table'] != null) {
        ncData['source_table'] = draftData['source_table'];
      }
      if (draftData['source_id'] != null) {
        ncData['source_id'] = draftData['source_id'];
      }
      if (draftData['source_payload'] != null) {
        ncData['source_payload'] = draftData['source_payload'];
      }

      String ncId;
      if (existingNcId != null) {
        // Update existing draft
        await _client
            .from('non_conformities')
            .update(ncData)
            .eq('id', existingNcId)
            .eq('organization_id', organizationId);
        ncId = existingNcId;
        debugPrint('[NCRepo] ✅ Updated draft NC in Supabase: $ncId');
      } else {
        // Create new draft
        final response = await _client
            .from('non_conformities')
            .insert(ncData)
            .select('id')
            .single();
        ncId = response['id'] as String;
        debugPrint('[NCRepo] ✅ Created draft NC in Supabase: $ncId');
      }

      return ncId;
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error saving draft to Supabase: $e');
      // Don't throw - allow local-only draft saving
      return null;
    }
  }

  /// Delete NC (cascades to child tables via DB constraints)
  Future<void> deleteNonConformity(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final orgRepo = OrganizationRepository();
      final orgId = await orgRepo.getOrCreateOrganization();

      // Get attachments first to delete from storage
      final attachments = await getAttachments(id);
      for (final attachment in attachments) {
        try {
          await deleteAttachment(attachment.id);
        } catch (e) {
          debugPrint(
            '[NCRepo] Warning: Failed to delete attachment ${attachment.id}: $e',
          );
        }
      }

      await _client
          .from('non_conformities')
          .delete()
          .eq('id', id)
          .eq('organization_id', orgId);

      debugPrint('[NCRepo] ✅ Deleted NC: $id');
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error deleting NC: $e');
      throw Exception('Failed to delete NC: $e');
    }
  }

  // ============================================
  // CAUSES (Section 5: 5M)
  // ============================================

  Future<List<NCCause>> getCauses(String ncId) async {
    try {
      final response = await _client
          .from('non_conformity_causes')
          .select()
          .eq('non_conformity_id', ncId)
          .order('order_index');

      return (response as List)
          .map((json) => NCCause.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error fetching causes: $e');
      return [];
    }
  }

  Future<NCCause> addCause({
    required String ncId,
    required NCCauseCategory category,
    required String causeText,
    bool isMostProbable = false,
    int orderIndex = 0,
  }) async {
    try {
      final response = await _client
          .from('non_conformity_causes')
          .insert({
            'non_conformity_id': ncId,
            'category': category.value,
            'cause_text': causeText,
            'is_most_probable': isMostProbable,
            'order_index': orderIndex,
          })
          .select()
          .single();

      return NCCause.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error adding cause: $e');
      throw Exception('Failed to add cause: $e');
    }
  }

  Future<void> deleteCause(String causeId) async {
    try {
      await _client.from('non_conformity_causes').delete().eq('id', causeId);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error deleting cause: $e');
      throw Exception('Failed to delete cause: $e');
    }
  }

  // ============================================
  // SOLUTIONS (Section 6)
  // ============================================

  Future<List<NCSolution>> getSolutions(String ncId) async {
    try {
      final response = await _client
          .from('non_conformity_solutions')
          .select()
          .eq('non_conformity_id', ncId)
          .order('priority', ascending: false)
          .order('order_index');

      return (response as List)
          .map((json) => NCSolution.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error fetching solutions: $e');
      return [];
    }
  }

  Future<NCSolution> addSolution({
    required String ncId,
    required String solutionText,
    int priority = 0,
    int orderIndex = 0,
  }) async {
    try {
      final response = await _client
          .from('non_conformity_solutions')
          .insert({
            'non_conformity_id': ncId,
            'solution_text': solutionText,
            'priority': priority,
            'order_index': orderIndex,
          })
          .select()
          .single();

      return NCSolution.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error adding solution: $e');
      throw Exception('Failed to add solution: $e');
    }
  }

  Future<void> deleteSolution(String solutionId) async {
    try {
      await _client
          .from('non_conformity_solutions')
          .delete()
          .eq('id', solutionId);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error deleting solution: $e');
      throw Exception('Failed to delete solution: $e');
    }
  }

  // ============================================
  // ACTIONS (Section 7: Action Plan)
  // ============================================

  Future<List<NCAction>> getActions(String ncId) async {
    try {
      final response = await _client
          .from('non_conformity_actions')
          .select()
          .eq('non_conformity_id', ncId)
          .order('order_index');

      return (response as List)
          .map((json) => NCAction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error fetching actions: $e');
      return [];
    }
  }

  Future<NCAction> addAction({
    required String ncId,
    required String actionText,
    String? responsibleEmployeeId,
    DateTime? targetDate,
    NCActionStatus status = NCActionStatus.pending,
    int orderIndex = 0,
  }) async {
    try {
      final response = await _client
          .from('non_conformity_actions')
          .insert({
            'non_conformity_id': ncId,
            'action_text': actionText,
            'responsible_employee_id': responsibleEmployeeId,
            'target_date': targetDate?.toIso8601String(),
            'status': status.value,
            'order_index': orderIndex,
          })
          .select()
          .single();

      return NCAction.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error adding action: $e');
      throw Exception('Failed to add action: $e');
    }
  }

  Future<NCAction> updateAction(NCAction action) async {
    try {
      final updates = action.toJson();
      updates.remove('id');
      updates.remove('non_conformity_id');
      updates.remove('created_at');
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('non_conformity_actions')
          .update(updates)
          .eq('id', action.id)
          .select()
          .single();

      return NCAction.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error updating action: $e');
      throw Exception('Failed to update action: $e');
    }
  }

  Future<void> deleteAction(String actionId) async {
    try {
      await _client.from('non_conformity_actions').delete().eq('id', actionId);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error deleting action: $e');
      throw Exception('Failed to delete action: $e');
    }
  }

  // ============================================
  // VERIFICATIONS (Section 8)
  // ============================================

  Future<List<NCVerification>> getVerifications(String ncId) async {
    try {
      final response = await _client
          .from('non_conformity_verifications')
          .select()
          .eq('non_conformity_id', ncId)
          .order('order_index');

      return (response as List)
          .map((json) => NCVerification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error fetching verifications: $e');
      return [];
    }
  }

  Future<NCVerification> addVerification({
    required String ncId,
    String? actionVerified,
    String? responsibleEmployeeId,
    String? result,
    DateTime? verificationDate,
    int orderIndex = 0,
  }) async {
    try {
      final response = await _client
          .from('non_conformity_verifications')
          .insert({
            'non_conformity_id': ncId,
            'action_verified': actionVerified,
            'responsible_employee_id': responsibleEmployeeId,
            'result': result,
            'verification_date': verificationDate?.toIso8601String(),
            'order_index': orderIndex,
          })
          .select()
          .single();

      return NCVerification.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error adding verification: $e');
      throw Exception('Failed to add verification: $e');
    }
  }

  Future<void> deleteVerification(String verificationId) async {
    try {
      await _client
          .from('non_conformity_verifications')
          .delete()
          .eq('id', verificationId);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error deleting verification: $e');
      throw Exception('Failed to delete verification: $e');
    }
  }

  // ============================================
  // ATTACHMENTS
  // ============================================

  /// Télécharge les octets d'une pièce jointe (pour export PDF)
  Future<Uint8List?> downloadAttachmentBytes(NCAttachment att) async {
    try {
      final path = '${att.nonConformityId}/${att.fileName}';
      return await _client.storage.from(_storageBucket).download(path);
    } catch (e) {
      debugPrint('[NCRepo] Erreur download pièce jointe: $e');
      return null;
    }
  }

  Future<List<NCAttachment>> getAttachments(String ncId) async {
    try {
      final response = await _client
          .from('non_conformity_attachments')
          .select()
          .eq('non_conformity_id', ncId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NCAttachment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error fetching attachments: $e');
      return [];
    }
  }

  /// Upload file and create attachment record
  Future<NCAttachment> addAttachment({
    required String ncId,
    required File file,
    String? fileName,
    String? employeeId,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Supabase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name =
          fileName ?? 'nc_${ncId}_$timestamp.${file.path.split('.').last}';
      final path = '$ncId/$name';

      debugPrint(
        '[NCRepo] Uploading attachment to bucket: $_storageBucket, path: $path',
      );

      await _client.storage
          .from(_storageBucket)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get public URL
      final fileUrl = _client.storage.from(_storageBucket).getPublicUrl(path);

      // Determine file type
      final extension = file.path.split('.').last.toLowerCase();
      String? fileType;
      if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
        fileType = 'image';
      } else if (extension == 'pdf') {
        fileType = 'pdf';
      }

      // Get file size
      final fileSize = await file.length();

      // Create attachment record
      final response = await _client
          .from('non_conformity_attachments')
          .insert({
            'non_conformity_id': ncId,
            'file_name': name,
            'file_url': fileUrl,
            'file_type': fileType,
            'file_size': fileSize,
            'uploaded_by': employeeId ?? user.id,
          })
          .select()
          .single();

      debugPrint('[NCRepo] ✅ Added attachment: ${response['id']}');
      return NCAttachment.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error adding attachment: $e');
      throw Exception('Failed to add attachment: $e');
    }
  }

  Future<void> deleteAttachment(String attachmentId) async {
    try {
      // Get attachment to delete file from storage
      final response = await _client
          .from('non_conformity_attachments')
          .select('file_url')
          .eq('id', attachmentId)
          .maybeSingle();

      if (response != null) {
        final fileUrl = response['file_url'] as String;
        // Extract path from URL and delete from storage
        try {
          final uri = Uri.parse(fileUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf(_storageBucket);
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final path = pathSegments.sublist(bucketIndex + 1).join('/');
            await _client.storage.from(_storageBucket).remove([path]);
          }
        } catch (e) {
          debugPrint(
            '[NCRepo] Warning: Failed to delete file from storage: $e',
          );
        }
      }

      // Delete attachment record
      await _client
          .from('non_conformity_attachments')
          .delete()
          .eq('id', attachmentId);

      debugPrint('[NCRepo] ✅ Deleted attachment: $attachmentId');
    } catch (e) {
      debugPrint('[NCRepo] ❌ Error deleting attachment: $e');
      throw Exception('Failed to delete attachment: $e');
    }
  }
}
