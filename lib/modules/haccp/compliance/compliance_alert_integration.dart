/// Compliance Alert Integration
/// 
/// Integrates compliance daily checks with the alert engine
/// Should be called on app start and after document uploads

import 'package:flutter/foundation.dart';
import '../alerts/alert_service.dart';
import '../alerts/models.dart';
import '../documents/models.dart';
import 'compliance_repository.dart';
import 'compliance_service.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../services/employee_session_service.dart';

class ComplianceAlertIntegration {
  final ComplianceRepository _complianceRepo = ComplianceRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final EmployeeSessionService _employeeSession = EmployeeSessionService();
  final AlertService _alertService = AlertService.instance;

  /// Run daily compliance checks and evaluate alerts
  /// Should be called on app start and once per day
  Future<void> runDailyComplianceChecks() async {
    try {
      debugPrint('[ComplianceAlert] Running daily compliance checks...');

      // Get organization ID
      await _employeeSession.initialize();
      final employee = _employeeSession.currentEmployee;
      String? organizationId;
      if (employee != null) {
        organizationId = employee.organizationId;
      } else {
        organizationId = await _orgRepo.getOrCreateOrganization();
      }

      if (organizationId == null) {
        debugPrint('[ComplianceAlert] No organization ID found, skipping checks');
        return;
      }

      // Load requirements and events
      final requirements = await _complianceRepo.getRequirements(organizationId);
      final events = await _complianceRepo.getEvents(organizationId);

      // Build daily check events
      final checkEvents = ComplianceService.buildDailyCheckEvents(
        requirements,
        events,
      );

      // Initialize alert service if needed
      await _alertService.initialize();

      // Evaluate each check event
      for (final eventData in checkEvents) {
        // Only generate alerts for dueSoon and overdue statuses
        final status = eventData['status'] as String?;
        if (status != 'dueSoon' && status != 'overdue') {
          debugPrint('[ComplianceAlert] Skipping alert for status: $status');
          continue;
        }

        final event = AlertEvent(
          eventType: 'compliance.daily_check',
          payload: eventData,
          organizationId: organizationId,
          employeeId: employee?.id,
          timestamp: DateTime.now(),
        );

        final storedAlerts = await _alertService.evaluateAndStore(event);
        if (storedAlerts.isNotEmpty) {
          debugPrint('[ComplianceAlert] ✅ Created ${storedAlerts.length} alert(s) for ${eventData['requirement_code']}');
        }
      }

      debugPrint('[ComplianceAlert] ✅ Completed daily compliance checks');
    } catch (e, stackTrace) {
      debugPrint('[ComplianceAlert] ❌ Error running daily checks: $e');
      debugPrint('[ComplianceAlert] Stack trace: $stackTrace');
      // Don't throw - alerts are non-blocking
    }
  }

  /// Trigger compliance check after document upload
  /// Should be called after uploading a document in a compliance category
  Future<void> checkComplianceAfterUpload({
    required String organizationId,
    required DocumentCategory category,
  }) async {
    // Only check if it's a compliance category
    if (!category.isComplianceCategory) {
      return;
    }

    try {
      debugPrint('[ComplianceAlert] Checking compliance after document upload...');

      // Load requirements and events
      final requirements = await _complianceRepo.getRequirements(organizationId);
      final events = await _complianceRepo.getEvents(organizationId);

      // Build daily check events
      final checkEvents = ComplianceService.buildDailyCheckEvents(
        requirements,
        events,
      );

      // Initialize alert service if needed
      await _alertService.initialize();

      // Evaluate each check event
      for (final eventData in checkEvents) {
        final event = AlertEvent(
          eventType: 'compliance.daily_check',
          payload: eventData,
          organizationId: organizationId,
          employeeId: null,
          timestamp: DateTime.now(),
        );

        await _alertService.evaluateAndStore(event);
      }

      debugPrint('[ComplianceAlert] ✅ Completed compliance check after upload');
    } catch (e, stackTrace) {
      debugPrint('[ComplianceAlert] ❌ Error checking compliance after upload: $e');
      debugPrint('[ComplianceAlert] Stack trace: $stackTrace');
      // Don't throw - alerts are non-blocking
    }
  }
}

