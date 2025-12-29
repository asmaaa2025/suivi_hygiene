import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tache_nettoyage.dart';

/// Repository for managing cleaning tasks with recurrence
class TacheNettoyageRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<TacheNettoyage>> getAll({bool? isActive}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint(
            '[TacheNettoyageRepo] ❌ No authenticated user - cannot fetch tasks');
        debugPrint('[TacheNettoyageRepo]   - Method: getAll');
        debugPrint('[TacheNettoyageRepo]   - Table: taches_nettoyage');
        throw Exception(
            'Vous devez être connecté pour accéder aux tâches de nettoyage');
      }

      debugPrint('[TacheNettoyageRepo] 🔍 Fetching tasks');
      debugPrint('[TacheNettoyageRepo]   - Method: getAll');
      debugPrint('[TacheNettoyageRepo]   - User ID: ${user.id}');
      debugPrint('[TacheNettoyageRepo]   - Table: taches_nettoyage');
      debugPrint('[TacheNettoyageRepo]   - Filter isActive: $isActive');

      var query = _client.from('taches_nettoyage').select();
      if (isActive != null) {
        query = query.eq('is_active', isActive);
        debugPrint(
            '[TacheNettoyageRepo]   - Applied filter: is_active = $isActive');
      }

      final response = await query.order('nom');
      debugPrint(
          '[TacheNettoyageRepo]   - Raw response length: ${(response as List).length}');

      final tasks = (response as List).map((json) {
        try {
          return TacheNettoyage.fromJson(json as Map<String, dynamic>);
        } catch (e, stackTrace) {
          debugPrint('[TacheNettoyageRepo] ⚠️ Error parsing task: $e');
          debugPrint('[TacheNettoyageRepo]   - JSON: $json');
          debugPrint('[TacheNettoyageRepo]   - StackTrace: $stackTrace');
          rethrow;
        }
      }).toList();

      debugPrint(
          '[TacheNettoyageRepo] ✅ Successfully fetched ${tasks.length} task(s)');
      return tasks;
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      if (errorStr.contains('PostgrestException') ||
          errorStr.contains('PGRST') ||
          errorStr.contains('42501')) {
        debugPrint('[TacheNettoyageRepo] ❌ Supabase error: $e');
        debugPrint('[TacheNettoyageRepo]   - StackTrace: $stackTrace');
        String errorMessage = 'Erreur lors de la récupération des tâches';
        if (errorStr.contains('42501')) {
          errorMessage = 'Permission refusée. Vérifiez vos droits d\'accès.';
        } else if (errorStr.isNotEmpty) {
          errorMessage = 'Erreur Supabase: $errorStr';
        }
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('[TacheNettoyageRepo] ❌ Unexpected error: $e');
      debugPrint('[TacheNettoyageRepo]   - Error type: ${e.runtimeType}');
      debugPrint('[TacheNettoyageRepo]   - StackTrace: $stackTrace');
      if (e.toString().contains('connecté')) {
        rethrow;
      }
      throw Exception(
          'Erreur lors de la récupération des tâches: ${e.toString()}');
    }
    return <TacheNettoyage>[];
  }

  Future<TacheNettoyage> getById(String id) async {
    try {
      final response =
          await _client.from('taches_nettoyage').select().eq('id', id).single();
      return TacheNettoyage.fromJson(response);
    } catch (e) {
      debugPrint('[TacheNettoyageRepo] Error fetching task: $e');
      throw Exception('Failed to fetch cleaning task: $e');
    }
  }

  Future<TacheNettoyage> create({
    required String nom,
    required String recurrenceType,
    required int interval,
    List<int>? weekdays,
    int? dayOfMonth,
    required String timeOfDay,
    bool isActive = true,
  }) async {
    try {
      debugPrint('[TacheNettoyageRepo] Creating task: $nom');
      final response = await _client
          .from('taches_nettoyage')
          .insert({
            'nom': nom,
            'recurrence_type': recurrenceType,
            'interval': interval,
            'weekdays': weekdays,
            'day_of_month': dayOfMonth,
            'time_of_day': timeOfDay,
            'is_active': isActive,
          })
          .select()
          .single();
      debugPrint('[TacheNettoyageRepo] Task created successfully');
      return TacheNettoyage.fromJson(response);
    } catch (e) {
      debugPrint('[TacheNettoyageRepo] Error creating task: $e');
      throw Exception('Failed to create cleaning task: $e');
    }
  }

  Future<TacheNettoyage> update({
    required String id,
    String? nom,
    String? recurrenceType,
    int? interval,
    List<int>? weekdays,
    int? dayOfMonth,
    String? timeOfDay,
    bool? isActive,
  }) async {
    try {
      debugPrint('[TacheNettoyageRepo] Updating task: $id');
      final updates = <String, dynamic>{};
      if (nom != null) updates['nom'] = nom;
      if (recurrenceType != null) updates['recurrence_type'] = recurrenceType;
      if (interval != null) updates['interval'] = interval;
      if (weekdays != null) updates['weekdays'] = weekdays;
      if (dayOfMonth != null) updates['day_of_month'] = dayOfMonth;
      if (timeOfDay != null) updates['time_of_day'] = timeOfDay;
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _client
          .from('taches_nettoyage')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      debugPrint('[TacheNettoyageRepo] Task updated successfully');
      return TacheNettoyage.fromJson(response);
    } catch (e) {
      debugPrint('[TacheNettoyageRepo] Error updating task: $e');
      throw Exception('Failed to update cleaning task: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      debugPrint('[TacheNettoyageRepo] Deleting task: $id');
      await _client.from('taches_nettoyage').delete().eq('id', id);
      debugPrint('[TacheNettoyageRepo] Task deleted successfully');
    } catch (e) {
      debugPrint('[TacheNettoyageRepo] Error deleting task: $e');
      throw Exception('Failed to delete cleaning task: $e');
    }
  }

  /// Get tasks due for a specific date based on recurrence rules
  Future<List<TacheNettoyage>> getTasksDueForDate(DateTime date) async {
    try {
      debugPrint(
          '[TacheNettoyageRepo] ========== getTasksDueForDate START ==========');
      debugPrint('[TacheNettoyageRepo] Repository: TacheNettoyageRepository');
      debugPrint('[TacheNettoyageRepo] Method: getTasksDueForDate');
      debugPrint(
          '[TacheNettoyageRepo] Data source: Supabase ONLY (no local storage)');
      debugPrint('[TacheNettoyageRepo] Date: $date');
      debugPrint('[TacheNettoyageRepo] Table: taches_nettoyage');

      final allTasks = await getAll(isActive: true);
      debugPrint(
          '[TacheNettoyageRepo]   - Found ${allTasks.length} active tasks');

      final dueTasks = <TacheNettoyage>[];

      for (final task in allTasks) {
        if (_isTaskDue(task, date)) {
          dueTasks.add(task);
        }
      }

      debugPrint(
          '[TacheNettoyageRepo] ✅ Found ${dueTasks.length} due tasks for $date');
      debugPrint(
          '[TacheNettoyageRepo] ========== getTasksDueForDate SUCCESS ==========');
      return dueTasks;
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      if (errorStr.contains('PostgrestException') ||
          errorStr.contains('PGRST')) {
        debugPrint(
            '[TacheNettoyageRepo] ❌ Supabase error in getTasksDueForDate');
        debugPrint('[TacheNettoyageRepo]   - Error: $e');
        debugPrint('[TacheNettoyageRepo]   - StackTrace: $stackTrace');
        debugPrint('[TacheNettoyageRepo] ====================================');
        throw Exception(
            'Erreur Supabase lors de la récupération des tâches: $errorStr');
      }
    } catch (e, stackTrace) {
      debugPrint(
          '[TacheNettoyageRepo] ❌ UNEXPECTED ERROR in getTasksDueForDate');
      debugPrint('[TacheNettoyageRepo]   - Error type: ${e.runtimeType}');
      debugPrint('[TacheNettoyageRepo]   - Error message: $e');
      debugPrint('[TacheNettoyageRepo]   - StackTrace: $stackTrace');

      // Check for LocalDataException specifically
      if (e.toString().contains('LocalData') ||
          e.toString().contains('LocalDataException') ||
          e.toString().contains('initializeDataForming')) {
        debugPrint(
            '[TacheNettoyageRepo] ⚠️⚠️⚠️ LocalDataException detected! ⚠️⚠️⚠️');
        debugPrint(
            '[TacheNettoyageRepo]   - This should NOT happen - app uses Supabase-only');
        debugPrint(
            '[TacheNettoyageRepo]   - This suggests an old code path is still active');
        debugPrint(
            '[TacheNettoyageRepo]   - Check for any imports or calls to LocalData/LocalDataSource');
      }

      debugPrint('[TacheNettoyageRepo] ====================================');
      // Return empty list instead of throwing to prevent crashes
      return <TacheNettoyage>[];
    }
    return <TacheNettoyage>[];
  }

  bool _isTaskDue(TacheNettoyage task, DateTime date) {
    switch (task.recurrenceType) {
      case 'daily':
        // Due every N days from creation date
        final daysSinceCreation = date.difference(task.createdAt).inDays;
        return daysSinceCreation >= 0 && daysSinceCreation % task.interval == 0;

      case 'weekly':
        if (task.weekdays == null || task.weekdays!.isEmpty) return false;
        // Check if today's weekday is in the list (1=Monday, 7=Sunday)
        final todayWeekday = date.weekday;
        if (!task.weekdays!.contains(todayWeekday)) return false;

        // Check if it's the right week interval
        final weeksSinceCreation = date.difference(task.createdAt).inDays ~/ 7;
        return weeksSinceCreation >= 0 &&
            weeksSinceCreation % task.interval == 0;

      case 'monthly':
        if (task.dayOfMonth == null) return false;
        // Check if today matches the day of month (handle months with fewer days)
        final targetDay = task.dayOfMonth!;
        final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
        final dayToCheck =
            targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;

        if (date.day != dayToCheck) return false;

        // Check if it's the right month interval
        final monthsSinceCreation = (date.year - task.createdAt.year) * 12 +
            (date.month - task.createdAt.month);
        return monthsSinceCreation >= 0 &&
            monthsSinceCreation % task.interval == 0;

      default:
        return false;
    }
  }
}
