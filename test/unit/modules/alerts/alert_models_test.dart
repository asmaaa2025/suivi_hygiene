/// Unit tests for Alert models (AlertSeverity, AlertStatus)

import 'package:bekkapp/modules/haccp/alerts/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlertSeverity', () {
    test('fromString parses correctly', () {
      expect(AlertSeverity.fromString('INFO'), AlertSeverity.info);
      expect(AlertSeverity.fromString('WARN'), AlertSeverity.warn);
      expect(AlertSeverity.fromString('CRITICAL'), AlertSeverity.critical);
      expect(AlertSeverity.fromString('unknown'), AlertSeverity.info);
    });

    test('toJson serializes correctly', () {
      expect(AlertSeverity.info.toJson(), 'INFO');
      expect(AlertSeverity.warn.toJson(), 'WARN');
      expect(AlertSeverity.critical.toJson(), 'CRITICAL');
    });
  });

  group('AlertStatus', () {
    test('fromString parses correctly', () {
      expect(AlertStatus.fromString('active'), AlertStatus.active);
      expect(AlertStatus.fromString('resolved'), AlertStatus.resolved);
      expect(AlertStatus.fromString('acknowledged'), AlertStatus.acknowledged);
      expect(AlertStatus.fromString('unknown'), AlertStatus.active);
    });

    test('toJson serializes correctly', () {
      expect(AlertStatus.active.toJson(), 'active');
      expect(AlertStatus.resolved.toJson(), 'resolved');
    });
  });
}
