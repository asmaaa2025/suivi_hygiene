/// Compliance Service
/// 
/// Handles compliance requirement calculations, status, and alert generation

import 'package:flutter/foundation.dart';
import '../documents/models.dart';

class ComplianceService {
  /// Get the last compliance event for a requirement
  static DateTime? getLastEventDate(
    ComplianceRequirement requirement,
    List<ComplianceEvent> events,
  ) {
    final requirementEvents = events
        .where((e) => e.requirementId == requirement.id)
        .toList();
    
    if (requirementEvents.isEmpty) return null;
    
    requirementEvents.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return requirementEvents.first.eventDate;
  }

  /// Compute the next due date based on last event date and frequency
  static DateTime? computeDueDate(
    ComplianceRequirement requirement,
    DateTime? lastEventDate,
  ) {
    if (lastEventDate == null) {
      // If no previous event, due date is today (immediately due)
      return DateTime.now();
    }
    
    return lastEventDate.add(Duration(days: requirement.frequencyDays));
  }

  /// Calculate compliance status
  static ComplianceStatusInfo calculateStatus(
    ComplianceRequirement requirement,
    List<ComplianceEvent> events,
  ) {
    final lastEventDate = getLastEventDate(requirement, events);
    final nextDueDate = computeDueDate(requirement, lastEventDate);
    final today = DateTime.now();
    
    ComplianceStatus status;
    int? daysUntilDue;
    int? daysOverdue;

    if (nextDueDate == null) {
      // No due date means no previous event - immediately due
      status = ComplianceStatus.overdue;
      daysOverdue = 0;
    } else {
      final daysDifference = nextDueDate.difference(today).inDays;
      final warningThreshold = 14; // Days before due date to show warning
      
      if (daysDifference < -requirement.graceDays) {
        // Overdue (past grace period)
        status = ComplianceStatus.overdue;
        daysOverdue = -daysDifference - requirement.graceDays;
      } else if (daysDifference <= 0) {
        // Overdue but within grace period
        status = ComplianceStatus.overdue;
        daysOverdue = -daysDifference;
      } else if (daysDifference <= warningThreshold) {
        // Due soon (within warning threshold)
        status = ComplianceStatus.dueSoon;
        daysUntilDue = daysDifference;
      } else {
        // OK
        status = ComplianceStatus.ok;
        daysUntilDue = daysDifference;
      }
    }

    return ComplianceStatusInfo(
      requirement: requirement,
      lastEventDate: lastEventDate,
      nextDueDate: nextDueDate,
      status: status,
      daysUntilDue: daysUntilDue,
      daysOverdue: daysOverdue,
    );
  }

  /// Build daily check events for alert engine
  /// Returns list of events that can be evaluated by the alert engine
  static List<Map<String, dynamic>> buildDailyCheckEvents(
    List<ComplianceRequirement> requirements,
    List<ComplianceEvent> events,
  ) {
    final checkEvents = <Map<String, dynamic>>[];

    for (final requirement in requirements) {
      if (!requirement.active) continue;

      final statusInfo = calculateStatus(requirement, events);

      final event = {
        'event_type': 'compliance.daily_check',
        'timestamp': DateTime.now().toIso8601String(),
        'requirement_code': requirement.code,
        'requirement_name': requirement.name,
        'last_date': statusInfo.lastEventDate?.toIso8601String(),
        'due_date': statusInfo.nextDueDate?.toIso8601String(),
        'grace_days': requirement.graceDays,
        'status': statusInfo.status.name, // 'ok', 'dueSoon', 'overdue'
        'days_until_due': statusInfo.daysUntilDue,
        'days_overdue': statusInfo.daysOverdue,
      };

      checkEvents.add(event);
    }

    return checkEvents;
  }

  /// Get status badge color for UI
  static String getStatusColor(ComplianceStatus status) {
    switch (status) {
      case ComplianceStatus.ok:
        return 'green';
      case ComplianceStatus.dueSoon:
        return 'orange';
      case ComplianceStatus.overdue:
        return 'red';
    }
  }
}










