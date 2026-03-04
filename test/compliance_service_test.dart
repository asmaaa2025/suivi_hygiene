/// Unit tests for ComplianceService

import 'package:flutter_test/flutter_test.dart';
import 'package:bekkapp/modules/haccp/compliance/compliance_service.dart';
import 'package:bekkapp/modules/haccp/documents/models.dart';

void main() {
  group('ComplianceService', () {
    late ComplianceRequirement requirement;
    late List<ComplianceEvent> events;

    setUp(() {
      requirement = ComplianceRequirement(
        id: 'req-1',
        organizationId: 'org-1',
        code: 'MICROBIO',
        name: 'Contrôles Microbiologiques',
        frequencyDays: 180,
        graceDays: 15,
        active: true,
      );
      events = [];
    });

    test('getLastEventDate returns null when no events', () {
      final lastDate = ComplianceService.getLastEventDate(requirement, events);
      expect(lastDate, isNull);
    });

    test('getLastEventDate returns most recent event date', () {
      final event1 = ComplianceEvent(
        id: 'event-1',
        organizationId: 'org-1',
        requirementId: 'req-1',
        eventDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now(),
      );
      final event2 = ComplianceEvent(
        id: 'event-2',
        organizationId: 'org-1',
        requirementId: 'req-1',
        eventDate: DateTime(2024, 6, 1),
        createdAt: DateTime.now(),
      );
      events = [event1, event2];

      final lastDate = ComplianceService.getLastEventDate(requirement, events);
      expect(lastDate, equals(DateTime(2024, 6, 1)));
    });

    test('computeDueDate returns today when no last event', () {
      final dueDate = ComplianceService.computeDueDate(requirement, null);
      expect(dueDate, isNotNull);
      // Should be today (within 1 day tolerance)
      expect(dueDate!.difference(DateTime.now()).inDays, lessThanOrEqualTo(1));
    });

    test('computeDueDate adds frequency days to last event', () {
      final lastEvent = DateTime.utc(2024, 1, 1);
      final dueDate = ComplianceService.computeDueDate(requirement, lastEvent);
      expect(dueDate, isNotNull);
      expect(dueDate!.year, 2024);
      expect(dueDate.month, 6);
      expect(dueDate.day, 29); // 180 days from Jan 1
    });

    test('calculateStatus returns OK when not due yet', () {
      final lastEvent = DateTime.now().subtract(const Duration(days: 100));
      events = [
        ComplianceEvent(
          id: 'event-1',
          organizationId: 'org-1',
          requirementId: 'req-1',
          eventDate: lastEvent,
          createdAt: DateTime.now(),
        ),
      ];

      final status = ComplianceService.calculateStatus(requirement, events);
      expect(status.status, equals(ComplianceStatus.ok));
      expect(status.daysUntilDue, greaterThan(14));
    });

    test('calculateStatus returns DUE_SOON when within warning threshold', () {
      final lastEvent = DateTime.now().subtract(const Duration(days: 170));
      events = [
        ComplianceEvent(
          id: 'event-1',
          organizationId: 'org-1',
          requirementId: 'req-1',
          eventDate: lastEvent,
          createdAt: DateTime.now(),
        ),
      ];

      final status = ComplianceService.calculateStatus(requirement, events);
      expect(status.status, equals(ComplianceStatus.dueSoon));
      expect(status.daysUntilDue, lessThanOrEqualTo(14));
      expect(status.daysUntilDue, greaterThan(0));
    });

    test('calculateStatus returns OVERDUE when past due date', () {
      final lastEvent = DateTime.now().subtract(const Duration(days: 200));
      events = [
        ComplianceEvent(
          id: 'event-1',
          organizationId: 'org-1',
          requirementId: 'req-1',
          eventDate: lastEvent,
          createdAt: DateTime.now(),
        ),
      ];

      final status = ComplianceService.calculateStatus(requirement, events);
      expect(status.status, equals(ComplianceStatus.overdue));
      expect(status.daysOverdue, greaterThan(0));
    });

    test('calculateStatus returns OVERDUE when past grace period', () {
      final lastEvent = DateTime.now().subtract(const Duration(days: 200));
      events = [
        ComplianceEvent(
          id: 'event-1',
          organizationId: 'org-1',
          requirementId: 'req-1',
          eventDate: lastEvent,
          createdAt: DateTime.now(),
        ),
      ];

      final status = ComplianceService.calculateStatus(requirement, events);
      expect(status.status, equals(ComplianceStatus.overdue));
      // daysOverdue = days past due date (when past grace: -daysDifference - graceDays)
      expect(status.daysOverdue, isNotNull);
      expect(status.daysOverdue!, greaterThan(0));
    });

    test('buildDailyCheckEvents generates events for all requirements', () {
      final req1 = ComplianceRequirement(
        id: 'req-1',
        organizationId: 'org-1',
        code: 'MICROBIO',
        name: 'Microbio',
        frequencyDays: 180,
        graceDays: 15,
        active: true,
      );
      final req2 = ComplianceRequirement(
        id: 'req-2',
        organizationId: 'org-1',
        code: 'PEST_CONTROL',
        name: 'Pest Control',
        frequencyDays: 180,
        graceDays: 15,
        active: true,
      );

      final requirements = [req1, req2];
      final events = <ComplianceEvent>[];

      final checkEvents = ComplianceService.buildDailyCheckEvents(
        requirements,
        events,
      );

      expect(checkEvents.length, equals(2));
      expect(checkEvents[0]['event_type'], equals('compliance.daily_check'));
      expect(checkEvents[0]['requirement_code'], equals('MICROBIO'));
      expect(checkEvents[1]['requirement_code'], equals('PEST_CONTROL'));
    });

    test('buildDailyCheckEvents includes status information', () {
      final lastEvent = DateTime.now().subtract(const Duration(days: 100));
      events = [
        ComplianceEvent(
          id: 'event-1',
          organizationId: 'org-1',
          requirementId: 'req-1',
          eventDate: lastEvent,
          createdAt: DateTime.now(),
        ),
      ];

      final checkEvents = ComplianceService.buildDailyCheckEvents([
        requirement,
      ], events);

      expect(checkEvents.length, equals(1));
      expect(checkEvents[0]['status'], isNotNull);
      expect(checkEvents[0]['last_date'], isNotNull);
      expect(checkEvents[0]['due_date'], isNotNull);
    });

    test('buildDailyCheckEvents skips inactive requirements', () {
      final inactiveReq = ComplianceRequirement(
        id: 'req-2',
        organizationId: 'org-1',
        code: 'PEST_CONTROL',
        name: 'Pest Control',
        frequencyDays: 180,
        graceDays: 15,
        active: false, // Inactive
      );

      final checkEvents = ComplianceService.buildDailyCheckEvents([
        inactiveReq,
      ], events);

      expect(checkEvents.length, equals(0));
    });
  });
}
