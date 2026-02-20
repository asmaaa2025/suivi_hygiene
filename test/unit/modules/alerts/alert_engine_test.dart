/// Unit tests for AlertEngine - temperature threshold detection, rule evaluation

import 'package:bekkapp/modules/haccp/alerts/alert_engine.dart';
import 'package:bekkapp/modules/haccp/alerts/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlertEngine engine;

  setUp(() async {
    engine = AlertEngine();
    // Minimal rules - format must match AlertRule.fromJson (id, event_type, when, emit)
    const rulesJson = '''
    {
      "defaults": {
        "dedupe_window_minutes": 180,
        "temperature": {
          "fallback_min_c": 0.0,
          "fallback_max_c": 4.0,
          "critical_margin_c": 2.0
        }
      },
      "alert_types": [
        {
          "code": "TEMP.OUT_OF_RANGE_WARN",
          "module": "temperature",
          "severity": "WARN",
          "blocking": false,
          "title": "Temp hors plage",
          "message_template": "Temp {temperature_c}°C hors plage ({temp_min}°C-{temp_max}°C).",
          "recommended_actions": ["Vérifier"],
          "dedupe_key_template": "temp|oor|{device_id}|{date}"
        },
        {
          "code": "TEMP.OUT_OF_RANGE_CRITICAL",
          "module": "temperature",
          "severity": "CRITICAL",
          "blocking": true,
          "title": "Temp critique",
          "message_template": "Temp critique {value}°C.",
          "recommended_actions": ["Action corrective"]
        }
      ],
      "rules": [
        {
          "id": "temp_oor_warn",
          "event_type": "temperature.logged",
          "when": [
            {"path": "temp_out_of_range", "op": "eq", "value": true}
          ],
          "emit": [{"alert_code": "TEMP.OUT_OF_RANGE_WARN"}]
        },
        {
          "id": "temp_oor_critical",
          "event_type": "temperature.logged",
          "when": [
            {"path": "temp_is_critical", "op": "eq", "value": true}
          ],
          "emit": [{"alert_code": "TEMP.OUT_OF_RANGE_CRITICAL"}]
        }
      ]
    }
    ''';
    await engine.loadRules(rulesJson);
  });

  group('AlertEngine - temperature.logged', () {
    test('generates no alert when temperature in range', () async {
      final event = AlertEvent(
        eventType: 'temperature.logged',
        payload: {
          'temperature_c': 3.0,
          'device_id': 'dev-1',
          'device_temp_min': 2.0,
          'device_temp_max': 4.0,
        },
        organizationId: 'org-1',
        employeeId: 'emp-1',
        timestamp: DateTime.now(),
      );

      final alerts = await engine.evaluate(event);
      expect(alerts, isEmpty);
    });

    test('generates OUT_OF_RANGE_WARN when temperature above max', () async {
      final event = AlertEvent(
        eventType: 'temperature.logged',
        payload: {
          'temperature_c': 8.0,
          'device_id': 'dev-1',
          'device_temp_min': 2.0,
          'device_temp_max': 4.0,
        },
        organizationId: 'org-1',
        employeeId: 'emp-1',
        timestamp: DateTime.now(),
      );

      final alerts = await engine.evaluate(event);
      expect(alerts.length, greaterThanOrEqualTo(1));
      expect(alerts.any((a) => a.alertCode == 'TEMP.OUT_OF_RANGE_WARN'), true);
      expect(alerts.first.severity, AlertSeverity.warn);
    });

    test('generates OUT_OF_RANGE_WARN when temperature below min', () async {
      final event = AlertEvent(
        eventType: 'temperature.logged',
        payload: {
          'temperature_c': 0.5,
          'device_id': 'dev-1',
          'device_temp_min': 2.0,
          'device_temp_max': 4.0,
        },
        organizationId: 'org-1',
        employeeId: 'emp-1',
        timestamp: DateTime.now(),
      );

      final alerts = await engine.evaluate(event);
      expect(alerts.length, greaterThanOrEqualTo(1));
      expect(alerts.any((a) => a.alertCode == 'TEMP.OUT_OF_RANGE_WARN'), true);
    });

    test('uses fallback thresholds when device thresholds missing', () async {
      final event = AlertEvent(
        eventType: 'temperature.logged',
        payload: {
          'temperature_c': 10.0,
          'device_id': 'dev-1',
        },
        organizationId: 'org-1',
        employeeId: 'emp-1',
        timestamp: DateTime.now(),
      );

      final alerts = await engine.evaluate(event);
      expect(alerts, isNotEmpty);
      expect(alerts.first.message, contains('10')); // temperature 10°C in message
    });
  });

  group('AlertEngine - invalid inputs', () {
    test('returns empty list for unknown event type', () async {
      final event = AlertEvent(
        eventType: 'unknown.event',
        payload: {},
        organizationId: 'org-1',
        employeeId: 'emp-1',
        timestamp: DateTime.now(),
      );

      final alerts = await engine.evaluate(event);
      expect(alerts, isEmpty);
    });

    test('loadRules throws on invalid JSON', () async {
      final badEngine = AlertEngine();
      await expectLater(
        badEngine.loadRules('{ invalid }'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
