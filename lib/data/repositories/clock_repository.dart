import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clock_session.dart';

/// Repository for clock sessions (clock-in/clock-out)
class ClockRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current open session for a specific employee
  /// Returns the open session (end_at IS NULL) for the given employeeId
  /// Business model: ONE open session per employee max (enforced by DB unique constraint)
  /// Multiple employees can have open sessions simultaneously
  /// This is the single source of truth for clock-in status (persisted in DB)
  /// CRITICAL: Uses employee_id, NOT user_id (employees are not auth users)
  Future<ClockSession?> getOpenSession(String employeeId) async {
    try {
      // Use employee_id (NOT user_id) - employees are not auth users
      final response = await _client
          .from('clock_sessions')
          .select()
          .eq('employee_id', employeeId) // Use employee_id only
          .isFilter('end_at', null)
          .maybeSingle();

      if (response == null) return null;
      return ClockSession.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint(
        '[ClockRepo] ❌ Error getting open session for employee $employeeId: $e',
      );
      return null;
    }
  }

  /// Clock in - create a new session for an employee
  /// Business model: ONE open session max per employee (enforced by DB unique constraint)
  /// Multiple employees can be clocked in simultaneously (multi-employés, multi-tablets)
  /// Rule: employee_id references employees.id (NOT auth.users.id)
  Future<ClockSession> clockIn({
    required String employeeId,
    String? deviceId,
  }) async {
    try {
      // Check if this employee already has an open session
      final existing = await getOpenSession(employeeId);
      if (existing != null) {
        throw Exception(
          'Vous avez déjà une session de pointage ouverte. Veuillez d\'abord pointer la sortie.',
        );
      }

      // Verify employee exists and get organization_id
      final employeeCheck = await _client
          .from('employees')
          .select('id, first_name, last_name, organization_id')
          .eq('id', employeeId)
          .maybeSingle();

      if (employeeCheck == null) {
        debugPrint(
          '[ClockRepo] ❌ Employee ID $employeeId does not exist in employees table',
        );
        throw Exception(
          'L\'employé avec l\'ID $employeeId n\'existe pas dans la base de données. Veuillez vérifier que l\'employé est bien créé dans la table employees.',
        );
      }

      final organizationId = employeeCheck['organization_id'] as String;
      debugPrint(
        '[ClockRepo] ✅ Employee verified: ${employeeCheck['first_name']} ${employeeCheck['last_name']} (ID: $employeeId, Org: $organizationId)',
      );

      final now = DateTime.now();
      // CRITICAL: Use employee_id and organization_id, NOT user_id
      // Business model: employees are NOT auth users, so we don't use user_id
      final insertData = <String, dynamic>{
        'employee_id':
            employeeId, // REQUIRED: employee_id references employees.id
        'organization_id':
            organizationId, // REQUIRED: organization_id references organizations.id
        'start_at': now.toIso8601String(),
        if (deviceId != null) 'device_id': deviceId,
        // DO NOT include user_id - employees are not auth users
      };

      debugPrint(
        '[ClockRepo] Clocking in employee: $employeeId (Org: $organizationId)',
      );

      final response = await _client
          .from('clock_sessions')
          .insert(insertData)
          .select()
          .single();

      debugPrint(
        '[ClockRepo] ✅ Clocked in successfully for employee $employeeId',
      );
      return ClockSession.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ClockRepo] ❌ Error clocking in: $e');
      // Provide more helpful error message
      if (e.toString().contains('foreign key constraint')) {
        throw Exception(
          'L\'employé sélectionné n\'existe pas dans la base de données. Veuillez sélectionner un employé valide ou créer cet employé d\'abord.',
        );
      }
      if (e.toString().contains('unique constraint') ||
          e.toString().contains('duplicate key')) {
        throw Exception(
          'Vous avez déjà une session de pointage ouverte. Veuillez d\'abord pointer la sortie.',
        );
      }
      throw Exception('Échec du pointage d\'entrée: $e');
    }
  }

  /// Clock out - close the current session for an employee
  /// Business model: Only the employee who clocked in can clock out (or admin override)
  /// Rule: employee_id references employees.id (NOT auth.users.id)
  /// CRITICAL: This method ONLY closes the session for the specified employeeId
  /// It NEVER closes sessions for other employees, even if called at midnight
  Future<ClockSession> clockOut(String employeeId) async {
    try {
      // Get current open session for THIS SPECIFIC employee only
      final session = await getOpenSession(employeeId);
      if (session == null) {
        throw Exception(
          'Aucune session ouverte pour vous. Veuillez d\'abord pointer l\'entrée.',
        );
      }

      final now = DateTime.now();
      debugPrint('[ClockRepo] [CLOCK_OUT] Clocking out employee: $employeeId');
      debugPrint('[ClockRepo] [CLOCK_OUT] Session ID: ${session.id}');
      debugPrint(
        '[ClockRepo] [CLOCK_OUT] Session start_at: ${session.startAt}',
      );
      debugPrint(
        '[ClockRepo] [CLOCK_OUT] Session employee_id: ${session.employeeId}',
      );

      // CRITICAL: Update ONLY this specific session by ID AND employee_id
      // This ensures we never accidentally close other employees' sessions
      // We use BOTH session.id AND employee_id to be absolutely sure
      final response = await _client
          .from('clock_sessions')
          .update({
            'end_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', session.id) // Match by session ID first (most specific)
          .eq(
            'employee_id',
            employeeId,
          ) // CRITICAL: Double-check employee_id matches
          .isFilter('end_at', null) // Only update if still open
          .select()
          .single();

      // Verify the response is for the correct employee
      final closedSession = ClockSession.fromJson(
        response as Map<String, dynamic>,
      );
      if (closedSession.employeeId != employeeId) {
        debugPrint(
          '[ClockRepo] ❌ CRITICAL ERROR: Closed session belongs to different employee!',
        );
        debugPrint('[ClockRepo] Expected employee_id: $employeeId');
        debugPrint('[ClockRepo] Got employee_id: ${closedSession.employeeId}');
        throw Exception(
          'Erreur critique: La session fermée appartient à un autre employé',
        );
      }

      debugPrint(
        '[ClockRepo] ✅ Clocked out successfully for employee $employeeId',
      );
      return closedSession;
    } catch (e) {
      debugPrint('[ClockRepo] ❌ Error clocking out: $e');
      throw Exception('Échec du pointage de sortie: $e');
    }
  }

  /// Auto-close old sessions for a specific employee (if session is older than 24 hours)
  /// This should be called when checking for open sessions, not automatically at midnight
  /// CRITICAL: Only closes sessions for the specified employeeId, never all employees
  Future<void> autoCloseOldSession(String employeeId) async {
    try {
      final session = await getOpenSession(employeeId);
      if (session == null) return; // No open session

      final now = DateTime.now();
      final sessionAge = now.difference(session.startAt);

      // Only auto-close if session is older than 24 hours
      if (sessionAge.inHours >= 24) {
        debugPrint(
          '[ClockRepo] [AUTO_CLOSE] Auto-closing old session for employee $employeeId',
        );
        debugPrint(
          '[ClockRepo] [AUTO_CLOSE] Session age: ${sessionAge.inHours} hours',
        );
        debugPrint(
          '[ClockRepo] [AUTO_CLOSE] Session started at: ${session.startAt}',
        );
        debugPrint('[ClockRepo] [AUTO_CLOSE] Session ID: ${session.id}');

        // Close ONLY this employee's session - use BOTH id and employee_id
        await _client
            .from('clock_sessions')
            .update({
              'end_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', session.id) // Match by session ID
            .eq('employee_id', employeeId) // CRITICAL: Only this employee
            .isFilter('end_at', null); // Only if still open

        debugPrint(
          '[ClockRepo] ✅ Auto-closed old session for employee $employeeId',
        );
      }
    } catch (e) {
      debugPrint('[ClockRepo] ❌ Error auto-closing old session: $e');
      // Don't throw - this is a background cleanup, shouldn't block the app
    }
  }

  /// Get clock history for an employee with optional filters
  /// Business model: employee_id references employees.id (NOT auth.users.id)
  Future<List<ClockSession>> getHistory({
    String? employeeId,
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
    bool? openSessionsOnly,
    int? limit,
  }) async {
    try {
      dynamic query = _client.from('clock_sessions').select();

      if (employeeId != null) {
        // Use employee_id only (NOT user_id) - employees are not auth users
        query = query.eq('employee_id', employeeId);
      }

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      if (startDate != null) {
        query = query.gte('start_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('start_at', endDate.toIso8601String());
      }

      if (openSessionsOnly == true) {
        query = query.isFilter('end_at', null);
      }

      final response = limit != null
          ? await query.order('start_at', ascending: false).limit(limit) as List
          : await query.order('start_at', ascending: false) as List;
      final sessions = (response as List)
          .map((json) => ClockSession.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[ClockRepo] ✅ Fetched ${sessions.length} sessions');
      return sessions;
    } catch (e) {
      debugPrint('[ClockRepo] ❌ Error getting history: $e');
      throw Exception('Échec de la récupération de l\'historique: $e');
    }
  }

  /// Get clock history for multiple employees (admin only)
  /// Business model: employee_id references employees.id (NOT auth.users.id)
  Future<List<ClockSession>> getHistoryForEmployees({
    required List<String> employeeIds,
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
    bool? openSessionsOnly,
  }) async {
    try {
      dynamic query = _client.from('clock_sessions').select();

      if (employeeIds.isNotEmpty) {
        // Use employee_id only (NOT user_id) - employees are not auth users
        query = query.inFilter('employee_id', employeeIds);
      }

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      if (startDate != null) {
        query = query.gte('start_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('start_at', endDate.toIso8601String());
      }

      if (openSessionsOnly == true) {
        query = query.isFilter('end_at', null);
      }

      final response = await query.order('start_at', ascending: false) as List;
      final sessions = response
          .map((json) => ClockSession.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
        '[ClockRepo] ✅ Fetched ${sessions.length} sessions for ${employeeIds.length} employees',
      );
      return sessions;
    } catch (e) {
      debugPrint('[ClockRepo] ❌ Error getting history for users: $e');
      throw Exception('Échec de la récupération de l\'historique: $e');
    }
  }
}
