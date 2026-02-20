/// HACCP Alert Engine
///
/// Centralized alert evaluation engine that processes events against JSON rules
/// and generates normalized alerts for "100% Crousty Sevran".

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class AlertEngine {
  final Map<String, AlertType> _alertTypes = {};
  final List<AlertRule> _rules = [];
  final Map<String, dynamic> _defaults = {};
  int _dedupeWindowMinutes = 180;

  /// Load rules from JSON string
  Future<void> loadRules(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Load defaults
      _defaults.clear();
      if (json['defaults'] != null) {
        _defaults.addAll(json['defaults'] as Map<String, dynamic>);
        _dedupeWindowMinutes =
            _defaults['dedupe_window_minutes'] as int? ?? 180;
      }

      // Load alert types
      _alertTypes.clear();
      if (json['alert_types'] != null) {
        final alertTypesList = json['alert_types'] as List<dynamic>;
        for (final at in alertTypesList) {
          final alertType = AlertType.fromJson(at as Map<String, dynamic>);
          _alertTypes[alertType.code] = alertType;
        }
      }

      // Load rules
      _rules.clear();
      if (json['rules'] != null) {
        final rulesList = json['rules'] as List<dynamic>;
        for (final r in rulesList) {
          final rule = AlertRule.fromJson(r as Map<String, dynamic>);
          _rules.add(rule);
        }
      }

      debugPrint(
        '[AlertEngine] Loaded ${_alertTypes.length} alert types and ${_rules.length} rules',
      );
    } catch (e, stackTrace) {
      debugPrint('[AlertEngine] Error loading rules: $e');
      debugPrint('[AlertEngine] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Evaluate an event and return list of alerts
  Future<List<Alert>> evaluate(AlertEvent event) async {
    final alerts = <Alert>[];

    try {
      // Find rules matching this event type
      final matchingRules = _rules
          .where((r) => r.eventType == event.eventType)
          .toList();

      if (matchingRules.isEmpty) {
        debugPrint(
          '[AlertEngine] No rules found for event type: ${event.eventType}',
        );
        return alerts;
      }

      // Normalize event payload for easier access
      final normalizedPayload = _normalizePayload(event.payload, event);

      // Evaluate each matching rule
      for (final rule in matchingRules) {
        if (_evaluateRule(rule, normalizedPayload)) {
          // Rule matched - emit alerts
          for (final alertCode in rule.alertCodes) {
            final alertType = _alertTypes[alertCode];
            if (alertType == null) {
              debugPrint(
                '[AlertEngine] Warning: Alert type not found: $alertCode',
              );
              continue;
            }

            // Generate alert message from template
            final message = _interpolateTemplate(
              alertType.messageTemplate,
              normalizedPayload,
            );

            // Generate dedupe key
            final dedupeKey = alertType.dedupeKeyTemplate != null
                ? _interpolateTemplate(
                    alertType.dedupeKeyTemplate!,
                    normalizedPayload,
                  )
                : null;

            // Create alert
            final alert = Alert(
              id: '', // Will be set by repository
              alertCode: alertCode,
              module: alertType.module,
              severity: alertType.severity,
              blocking: alertType.blocking,
              title: alertType.title,
              message: message,
              recommendedActions: alertType.recommendedActions,
              dedupeKey: dedupeKey,
              eventSnapshot: event.payload,
              organizationId: event.organizationId,
              employeeId: event.employeeId,
              createdAt: event.timestamp,
            );

            alerts.add(alert);
          }
        }
      }

      debugPrint(
        '[AlertEngine] Generated ${alerts.length} alerts for event ${event.eventType}',
      );
    } catch (e, stackTrace) {
      debugPrint('[AlertEngine] Error evaluating event: $e');
      debugPrint('[AlertEngine] Stack trace: $stackTrace');
    }

    return alerts;
  }

  /// Normalize event payload to include computed fields
  Map<String, dynamic> _normalizePayload(
    Map<String, dynamic> payload,
    AlertEvent event,
  ) {
    final normalized = Map<String, dynamic>.from(payload);

    // Add common fields
    normalized['event_type'] = event.eventType;
    normalized['organization_id'] = event.organizationId;
    normalized['employee_id'] = event.employeeId;
    normalized['date'] = DateFormat('yyyy-MM-dd').format(event.timestamp);
    normalized['timestamp'] = event.timestamp.toIso8601String();

    // Temperature-specific normalization
    if (event.eventType == 'temperature.logged') {
      final tempC =
          _getValue(payload, 'temperature_c') ??
          _getValue(payload, 'temperature') as num?;
      final deviceId =
          _getValue(payload, 'device_id') ??
          _getValue(payload, 'appareil_id') as String?;
      final tempMin = _getValue(payload, 'device_temp_min') as num?;
      final tempMax = _getValue(payload, 'device_temp_max') as num?;

      normalized['temperature_c'] = tempC;
      normalized['device_id'] = deviceId;
      normalized['device_name'] =
          _getValue(payload, 'device_name') ??
          _getValue(payload, 'appareil_nom') as String?;

      // Check if device_id exists
      normalized['device_id_exists'] =
          deviceId != null && deviceId.toString().isNotEmpty;

      // Check if thresholds are missing
      final thresholdsMissing = (tempMin == null || tempMax == null);
      normalized['device_thresholds_missing'] = thresholdsMissing;

      // Use defaults if thresholds missing
      final min =
          tempMin?.toDouble() ??
          (_defaults['temperature'] as Map<String, dynamic>?)?['fallback_min_c']
              as double? ??
          0.0;
      final max =
          tempMax?.toDouble() ??
          (_defaults['temperature'] as Map<String, dynamic>?)?['fallback_max_c']
              as double? ??
          4.0;

      normalized['temp_min'] = min;
      normalized['temp_max'] = max;

      // Check if temperature is out of range
      if (tempC != null) {
        final temp = tempC.toDouble();
        final outOfRange = temp < min || temp > max;
        normalized['temp_out_of_range'] = outOfRange;

        // Check if critical (beyond critical margin)
        final criticalMargin =
            (_defaults['temperature']
                    as Map<String, dynamic>?)?['critical_margin_c']
                as double? ??
            2.0;
        final isCritical =
            outOfRange &&
            (temp < (min - criticalMargin) || temp > (max + criticalMargin));
        normalized['temp_is_critical'] = isCritical;
        normalized['critical_margin'] = criticalMargin;
      }
    }

    // Reception-specific normalization
    if (event.eventType == 'reception.checked') {
      final packaging =
          _getValue(payload, 'packaging') as Map<String, dynamic>? ?? {};
      final label = _getValue(payload, 'label') as Map<String, dynamic>? ?? {};
      final temp = _getValue(payload, 'temperature') as num?;
      final productName =
          _getValue(payload, 'product_name') ??
          _getValue(payload, 'produit_nom') as String?;
      final supplierId = _getValue(payload, 'supplier_id') as String?;
      final productId =
          _getValue(payload, 'product_id') ??
          _getValue(payload, 'produit_id') as String?;
      final lot = _getValue(payload, 'lot') as String?;

      normalized['packaging'] = packaging;
      normalized['label'] = label;
      normalized['temperature'] = temp;
      normalized['product_name'] = productName;
      normalized['supplier_id'] = supplierId;
      normalized['product_id'] = productId;
      normalized['lot'] = lot;

      // Count missing label fields
      final missingFields = <String>[];
      if (_getValue(label, 'dlc') == null) missingFields.add('DLC');
      if (_getValue(label, 'lot') == null) missingFields.add('Lot');
      if (_getValue(label, 'supplier') == null)
        missingFields.add('Fournisseur');
      if (_getValue(label, 'product_name') == null)
        missingFields.add('Nom produit');

      normalized['label.missing_fields_count'] = missingFields.length;
      normalized['label.missing_fields'] = missingFields.join(', ');
    }

    // Oil-specific normalization
    if (event.eventType == 'oil.check_logged' ||
        event.eventType == 'oil.change_logged') {
      final fryerId =
          _getValue(payload, 'fryer_id') ??
          _getValue(payload, 'friteuse_id') as String?;
      final fryerName =
          _getValue(payload, 'fryer_name') ??
          _getValue(payload, 'friteuse_nom') as String?;
      final oilState = _getValue(payload, 'oil_state') as String?;
      final daysSinceChange = _getValue(payload, 'days_since_change') as int?;
      final cycles = _getValue(payload, 'cycles') as int?;

      normalized['fryer_id'] = fryerId;
      normalized['fryer_name'] = fryerName;
      normalized['oil_state'] = oilState;
      normalized['days_since_change'] = daysSinceChange;
      normalized['cycles'] = cycles;
    }

    // Cleaning-specific normalization
    if (event.eventType == 'cleaning.day_closed') {
      final missedCount = _getValue(payload, 'missed_count') as int? ?? 0;
      normalized['missed_count'] = missedCount;
    }

    // Compliance-specific normalization
    if (event.eventType == 'compliance.daily_check') {
      final requirementCode = _getValue(payload, 'requirement_code') as String?;
      final requirementName = _getValue(payload, 'requirement_name') as String?;
      final lastDate = _getValue(payload, 'last_date') as String?;
      final dueDate = _getValue(payload, 'due_date') as String?;
      final status = _getValue(payload, 'status') as String?;
      final daysUntilDue = _getValue(payload, 'days_until_due') as int?;
      final daysOverdue = _getValue(payload, 'days_overdue') as int?;
      final graceDays = _getValue(payload, 'grace_days') as int?;

      normalized['requirement_code'] = requirementCode;
      normalized['requirement_name'] = requirementName;
      normalized['last_date'] = lastDate;
      normalized['due_date'] = dueDate;
      normalized['status'] = status;
      normalized['days_until_due'] = daysUntilDue;
      normalized['days_overdue'] = daysOverdue;
      normalized['grace_days'] = graceDays;

      // Add date field for deduplication (current date as YYYY-MM-DD)
      final now = DateTime.now();
      normalized['date'] =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    return normalized;
  }

  /// Evaluate a rule against normalized payload
  bool _evaluateRule(AlertRule rule, Map<String, dynamic> payload) {
    // All conditions must be true (AND logic)
    for (final condition in rule.conditions) {
      if (!_evaluateCondition(condition, payload)) {
        return false;
      }
    }
    return true;
  }

  /// Evaluate a single condition
  bool _evaluateCondition(
    AlertRuleCondition condition,
    Map<String, dynamic> payload,
  ) {
    final pathValue = _getValue(payload, condition.path);

    switch (condition.op) {
      case 'eq':
        return pathValue == condition.value;
      case 'ne':
        return pathValue != condition.value;
      case 'lt':
        return _compareNumbers(pathValue, condition.value, (a, b) => a < b);
      case 'lte':
        return _compareNumbers(pathValue, condition.value, (a, b) => a <= b);
      case 'gt':
        return _compareNumbers(pathValue, condition.value, (a, b) => a > b);
      case 'gte':
        return _compareNumbers(pathValue, condition.value, (a, b) => a >= b);
      case 'in':
        if (condition.value is List) {
          return (condition.value as List).contains(pathValue);
        }
        return false;
      case 'not_in':
        if (condition.value is List) {
          return !(condition.value as List).contains(pathValue);
        }
        return true;
      case 'contains':
        if (pathValue is String && condition.value is String) {
          return pathValue.contains(condition.value);
        }
        return false;
      case 'exists':
        final shouldExist = condition.value as bool? ?? true;
        final exists = pathValue != null;
        return shouldExist ? exists : !exists;
      case 'between':
        if (condition.value is List && (condition.value as List).length == 2) {
          final list = condition.value as List;
          final min = list[0] as num;
          final max = list[1] as num;
          if (pathValue is num) {
            return pathValue >= min && pathValue <= max;
          }
        }
        return false;
      case 'regex':
        // Simple regex matching (basic implementation)
        if (pathValue is String && condition.value is String) {
          try {
            final regex = RegExp(condition.value as String);
            return regex.hasMatch(pathValue);
          } catch (e) {
            debugPrint('[AlertEngine] Invalid regex: ${condition.value}');
            return false;
          }
        }
        return false;
      default:
        debugPrint('[AlertEngine] Unknown operator: ${condition.op}');
        return false;
    }
  }

  /// Compare two numbers using a comparator function
  bool _compareNumbers(dynamic a, dynamic b, bool Function(num, num) compare) {
    if (a is num && b is num) {
      return compare(a, b);
    }
    return false;
  }

  /// Get value from nested map using dot notation path
  dynamic _getValue(Map<String, dynamic> map, String path) {
    final parts = path.split('.');
    dynamic current = map;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  /// Interpolate template string with values from payload
  String _interpolateTemplate(String template, Map<String, dynamic> payload) {
    String result = template;

    // Replace {key} with value from payload
    final regex = RegExp(r'\{([^}]+)\}');
    result = result.replaceAllMapped(regex, (match) {
      final key = match.group(1)!;
      final value = _getValue(payload, key) ?? payload[key];
      return value?.toString() ?? '';
    });

    return result;
  }

  /// Get dedupe window in minutes
  int get dedupeWindowMinutes => _dedupeWindowMinutes;
}
