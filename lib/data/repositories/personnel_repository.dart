import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/personnel.dart';

/// Repository for personnel (HR registry) - Admin only
class PersonnelRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all personnel with optional filters
  Future<List<Personnel>> getAll({
    bool? activeOnly,
    String? searchQuery,
  }) async {
    try {
      dynamic query = _client.from('personnel').select();

      if (activeOnly == true) {
        // Get only active personnel (endDate is null or in the future)
        final now = DateTime.now().toIso8601String();
        query = query.or('end_date.is.null,end_date.gte.$now');
      }

      final response = await query.order('last_name') as List;
      var personnel = response
          .map((json) => Personnel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        personnel = personnel.where((p) {
          return p.firstName.toLowerCase().contains(queryLower) ||
              p.lastName.toLowerCase().contains(queryLower) ||
              p.fullName.toLowerCase().contains(queryLower);
        }).toList();
      }

      debugPrint('[PersonnelRepo] ✅ Fetched ${personnel.length} personnel');
      return personnel;
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error: $e');
      throw Exception('Échec de la récupération du personnel: $e');
    }
  }

  /// Get personnel by ID
  Future<Personnel?> getById(String id) async {
    try {
      final response = await _client
          .from('personnel')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Personnel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error: $e');
      return null;
    }
  }

  /// Get personnel by user ID (if linked to a user account)
  Future<Personnel?> getByUserId(String userId) async {
    try {
      final response = await _client
          .from('personnel')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Personnel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error: $e');
      return null;
    }
  }

  /// Create a new personnel record
  Future<Personnel> create({
    required String firstName,
    required String lastName,
    required DateTime startDate,
    DateTime? endDate,
    required ContractType contractType,
    bool isForeignWorker = false,
    String? foreignWorkPermitType,
    String? foreignWorkPermitNumber,
    String? userId,
  }) async {
    try {
      // Validate dates
      if (endDate != null && endDate.isBefore(startDate)) {
        throw Exception('La date de fin doit être postérieure à la date de début');
      }

      // Validate foreign worker fields
      if (isForeignWorker) {
        if (foreignWorkPermitType == null || foreignWorkPermitType.isEmpty) {
          throw Exception('Le type de permis de travail est requis pour un travailleur étranger');
        }
        if (foreignWorkPermitNumber == null || foreignWorkPermitNumber.isEmpty) {
          throw Exception('Le numéro de permis de travail est requis pour un travailleur étranger');
        }
      }

      final insertData = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        'contract_type': contractType.toValue(),
        'is_foreign_worker': isForeignWorker,
        if (isForeignWorker) 'foreign_work_permit_type': foreignWorkPermitType,
        if (isForeignWorker) 'foreign_work_permit_number': foreignWorkPermitNumber,
        if (userId != null) 'user_id': userId,
      };

      debugPrint('[PersonnelRepo] Creating personnel: $firstName $lastName');
      final response = await _client
          .from('personnel')
          .insert(insertData)
          .select()
          .single();

      debugPrint('[PersonnelRepo] ✅ Personnel created successfully');
      return Personnel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error creating personnel: $e');
      throw Exception('Échec de la création du personnel: $e');
    }
  }

  /// Update a personnel record
  Future<Personnel> update({
    required String id,
    String? firstName,
    String? lastName,
    DateTime? startDate,
    DateTime? endDate,
    ContractType? contractType,
    bool? isForeignWorker,
    String? foreignWorkPermitType,
    String? foreignWorkPermitNumber,
    String? userId,
  }) async {
    try {
      // Get current record to validate
      final current = await getById(id);
      if (current == null) {
        throw Exception('Personnel introuvable');
      }

      // Validate dates
      final finalStartDate = startDate ?? current.startDate;
      final finalEndDate = endDate ?? current.endDate;
      if (finalEndDate != null && finalEndDate.isBefore(finalStartDate)) {
        throw Exception('La date de fin doit être postérieure à la date de début');
      }

      // Validate foreign worker fields
      final finalIsForeignWorker = isForeignWorker ?? current.isForeignWorker;
      if (finalIsForeignWorker) {
        final finalPermitType = foreignWorkPermitType ?? current.foreignWorkPermitType;
        final finalPermitNumber = foreignWorkPermitNumber ?? current.foreignWorkPermitNumber;
        if (finalPermitType == null || finalPermitType.isEmpty) {
          throw Exception('Le type de permis de travail est requis pour un travailleur étranger');
        }
        if (finalPermitNumber == null || finalPermitNumber.isEmpty) {
          throw Exception('Le numéro de permis de travail est requis pour un travailleur étranger');
        }
      }

      final updates = <String, dynamic>{};
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (startDate != null) updates['start_date'] = startDate.toIso8601String();
      if (endDate != null) {
        updates['end_date'] = endDate.toIso8601String();
      } else if (endDate == null && current.endDate != null) {
        // Explicitly set to null if removing end date
        updates['end_date'] = null;
      }
      if (contractType != null) updates['contract_type'] = contractType.toValue();
      if (isForeignWorker != null) updates['is_foreign_worker'] = isForeignWorker;
      if (foreignWorkPermitType != null) {
        updates['foreign_work_permit_type'] = foreignWorkPermitType;
      }
      if (foreignWorkPermitNumber != null) {
        updates['foreign_work_permit_number'] = foreignWorkPermitNumber;
      }
      if (userId != null) updates['user_id'] = userId;

      debugPrint('[PersonnelRepo] Updating personnel: $id');
      final response = await _client
          .from('personnel')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      debugPrint('[PersonnelRepo] ✅ Personnel updated successfully');
      return Personnel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error updating personnel: $e');
      throw Exception('Échec de la mise à jour du personnel: $e');
    }
  }

  /// Soft delete a personnel record (set end_date to now)
  Future<Personnel> softDelete(String id) async {
    try {
      final now = DateTime.now();
      final response = await _client
          .from('personnel')
          .update({
            'end_date': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      debugPrint('[PersonnelRepo] ✅ Personnel soft deleted successfully');
      return Personnel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error soft deleting personnel: $e');
      throw Exception('Échec de la suppression du personnel: $e');
    }
  }

  /// Hard delete a personnel record (admin only, use with caution)
  Future<void> delete(String id) async {
    try {
      await _client.from('personnel').delete().eq('id', id);
      debugPrint('[PersonnelRepo] ✅ Personnel deleted successfully');
    } catch (e) {
      debugPrint('[PersonnelRepo] ❌ Error deleting personnel: $e');
      throw Exception('Échec de la suppression du personnel: $e');
    }
  }
}

