/// HACCP Alert Service
///
/// Centralized service for alert evaluation and management
/// Initializes the engine and provides high-level API for modules

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'alert_engine.dart';
import 'alert_repository.dart';

class AlertService {
  static AlertService? _instance;
  static AlertService get instance => _instance ??= AlertService._();

  AlertService._();

  final AlertEngine _engine = AlertEngine();
  final AlertRepository _repository = AlertRepository();
  bool _initialized = false;

  /// Initialize the alert service by loading rules from JSON
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[AlertService] Already initialized');
      return;
    }

    try {
      debugPrint('[AlertService] Loading alert rules...');
      final rulesJson = await rootBundle.loadString(
        'lib/modules/haccp/alerts/alert_rules.json',
      );
      await _engine.loadRules(rulesJson);
      _initialized = true;
      debugPrint('[AlertService] ✅ Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[AlertService] ❌ Error initializing: $e');
      debugPrint('[AlertService] Stack trace: $stackTrace');
      // Don't throw - allow app to continue without alerts
    }
  }

  /// Evaluate an event and store generated alerts
  /// Returns list of alerts that were created (after deduplication)
  Future<List<Alert>> evaluateAndStore(AlertEvent event) async {
    if (!_initialized) {
      debugPrint('[AlertService] Not initialized, skipping alert evaluation');
      return [];
    }

    try {
      // Evaluate event
      final alerts = await _engine.evaluate(event);

      if (alerts.isEmpty) {
        return [];
      }

      // Store alerts (with deduplication)
      final storedAlerts = <Alert>[];
      for (final alert in alerts) {
        // Check for duplicates
        if (alert.dedupeKey != null && alert.dedupeKey!.isNotEmpty) {
          final isDuplicate = await _repository.hasDuplicate(
            alert.dedupeKey!,
            _engine.dedupeWindowMinutes,
          );

          if (isDuplicate) {
            debugPrint(
              '[AlertService] Skipping duplicate alert: ${alert.dedupeKey}',
            );
            continue;
          }
        }

        // Store alert
        try {
          final stored = await _repository.create(alert);
          storedAlerts.add(stored);
          debugPrint('[AlertService] ✅ Stored alert: ${alert.alertCode}');
        } catch (e) {
          debugPrint('[AlertService] Error storing alert: $e');
          // Continue with other alerts
        }
      }

      return storedAlerts;
    } catch (e, stackTrace) {
      debugPrint('[AlertService] Error evaluating event: $e');
      debugPrint('[AlertService] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get active alerts
  Future<List<Alert>> getActiveAlerts({
    String? module,
    AlertSeverity? severity,
  }) async {
    return _repository.getActive(module: module, severity: severity);
  }

  /// Get blocking alerts (critical alerts that block validation)
  Future<List<Alert>> getBlockingAlerts() async {
    return _repository.getBlockingAlerts();
  }

  /// Resolve an alert
  Future<void> resolveAlert(String alertId, {String? resolvedBy}) async {
    await _repository.resolve(alertId, resolvedBy: resolvedBy);
  }

  /// Acknowledge an alert
  Future<void> acknowledgeAlert(String alertId) async {
    await _repository.acknowledge(alertId);
  }

  /// Link alert to corrective action
  Future<void> linkCorrectiveAction(
    String alertId,
    String correctiveActionId,
  ) async {
    await _repository.linkCorrectiveAction(alertId, correctiveActionId);
  }
}
