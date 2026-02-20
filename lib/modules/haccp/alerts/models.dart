/// HACCP Alert System Models
///
/// This file contains all data models for the unified HACCP alert system
/// for "100% Crousty Sevran".

enum AlertSeverity {
  info,
  warn,
  critical;

  static AlertSeverity fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INFO':
        return AlertSeverity.info;
      case 'WARN':
        return AlertSeverity.warn;
      case 'CRITICAL':
        return AlertSeverity.critical;
      default:
        return AlertSeverity.info;
    }
  }

  String toJson() {
    switch (this) {
      case AlertSeverity.info:
        return 'INFO';
      case AlertSeverity.warn:
        return 'WARN';
      case AlertSeverity.critical:
        return 'CRITICAL';
    }
  }
}

enum AlertStatus {
  active,
  resolved,
  acknowledged;

  static AlertStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return AlertStatus.active;
      case 'resolved':
        return AlertStatus.resolved;
      case 'acknowledged':
        return AlertStatus.acknowledged;
      default:
        return AlertStatus.active;
    }
  }

  String toJson() {
    switch (this) {
      case AlertStatus.active:
        return 'active';
      case AlertStatus.resolved:
        return 'resolved';
      case AlertStatus.acknowledged:
        return 'acknowledged';
    }
  }
}

/// Alert model representing a single HACCP alert
class Alert {
  final String id;
  final String alertCode;
  final String module; // 'temperature', 'reception', 'oil', 'cleaning'
  final AlertSeverity severity;
  final bool blocking;
  final String title;
  final String message;
  final List<String> recommendedActions;
  final String? dedupeKey;
  final Map<String, dynamic> eventSnapshot; // Original event data
  final String? organizationId;
  final String? employeeId;
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? correctiveActionId; // Link to corrective action record

  Alert({
    required this.id,
    required this.alertCode,
    required this.module,
    required this.severity,
    required this.blocking,
    required this.title,
    required this.message,
    required this.recommendedActions,
    this.dedupeKey,
    required this.eventSnapshot,
    this.organizationId,
    this.employeeId,
    this.status = AlertStatus.active,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.correctiveActionId,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id']?.toString() ?? '',
      alertCode: json['alert_code'] as String,
      module: json['module'] as String,
      severity: AlertSeverity.fromString(json['severity'] as String? ?? 'INFO'),
      blocking: json['blocking'] as bool? ?? false,
      title: json['title'] as String,
      message: json['message'] as String,
      recommendedActions:
          (json['recommended_actions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dedupeKey: json['dedupe_key'] as String?,
      eventSnapshot: json['event_snapshot'] as Map<String, dynamic>? ?? {},
      organizationId: json['organization_id'] as String?,
      employeeId: json['employee_id'] as String?,
      status: AlertStatus.fromString(json['status'] as String? ?? 'active'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      resolvedBy: json['resolved_by'] as String?,
      correctiveActionId: json['corrective_action_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alert_code': alertCode,
      'module': module,
      'severity': severity.toJson(),
      'blocking': blocking,
      'title': title,
      'message': message,
      'recommended_actions': recommendedActions,
      'dedupe_key': dedupeKey,
      'event_snapshot': eventSnapshot,
      'organization_id': organizationId,
      'employee_id': employeeId,
      'status': status.toJson(),
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
      'corrective_action_id': correctiveActionId,
    };
  }

  Alert copyWith({
    String? id,
    String? alertCode,
    String? module,
    AlertSeverity? severity,
    bool? blocking,
    String? title,
    String? message,
    List<String>? recommendedActions,
    String? dedupeKey,
    Map<String, dynamic>? eventSnapshot,
    String? organizationId,
    String? employeeId,
    AlertStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? correctiveActionId,
  }) {
    return Alert(
      id: id ?? this.id,
      alertCode: alertCode ?? this.alertCode,
      module: module ?? this.module,
      severity: severity ?? this.severity,
      blocking: blocking ?? this.blocking,
      title: title ?? this.title,
      message: message ?? this.message,
      recommendedActions: recommendedActions ?? this.recommendedActions,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      eventSnapshot: eventSnapshot ?? this.eventSnapshot,
      organizationId: organizationId ?? this.organizationId,
      employeeId: employeeId ?? this.employeeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      correctiveActionId: correctiveActionId ?? this.correctiveActionId,
    );
  }
}

/// Alert event representing an event that triggers alert evaluation
class AlertEvent {
  final String eventType; // e.g., "temperature.logged", "reception.checked"
  final Map<String, dynamic> payload; // Event data
  final String? organizationId;
  final String? employeeId;
  final DateTime timestamp;

  AlertEvent({
    required this.eventType,
    required this.payload,
    this.organizationId,
    this.employeeId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'payload': payload,
      'organization_id': organizationId,
      'employee_id': employeeId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Alert rule condition for evaluating events
class AlertRuleCondition {
  final String
  path; // JSON path to value (e.g., "temperature_c", "packaging.issue")
  final String
  op; // Operator: eq, ne, lt, lte, gt, gte, in, not_in, contains, exists, between, regex
  final dynamic value; // Comparison value

  AlertRuleCondition({
    required this.path,
    required this.op,
    required this.value,
  });

  factory AlertRuleCondition.fromJson(Map<String, dynamic> json) {
    return AlertRuleCondition(
      path: json['path'] as String,
      op: json['op'] as String,
      value: json['value'],
    );
  }
}

/// Alert rule definition from JSON
class AlertRule {
  final String id;
  final String eventType;
  final List<AlertRuleCondition> conditions;
  final List<String> alertCodes; // Alert codes to emit when conditions match

  AlertRule({
    required this.id,
    required this.eventType,
    required this.conditions,
    required this.alertCodes,
  });

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    final emitList = json['emit'] as List<dynamic>? ?? [];
    return AlertRule(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      conditions:
          (json['when'] as List<dynamic>?)
              ?.map(
                (e) => AlertRuleCondition.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      alertCodes: emitList
          .map((e) => (e as Map<String, dynamic>)['alert_code'] as String)
          .toList(),
    );
  }
}

/// Alert type definition from JSON (metadata about alert codes)
class AlertType {
  final String code;
  final String module;
  final AlertSeverity severity;
  final bool blocking;
  final String title;
  final String messageTemplate;
  final List<String> recommendedActions;
  final String? dedupeKeyTemplate;

  AlertType({
    required this.code,
    required this.module,
    required this.severity,
    required this.blocking,
    required this.title,
    required this.messageTemplate,
    required this.recommendedActions,
    this.dedupeKeyTemplate,
  });

  factory AlertType.fromJson(Map<String, dynamic> json) {
    return AlertType(
      code: json['code'] as String,
      module: json['module'] as String,
      severity: AlertSeverity.fromString(json['severity'] as String? ?? 'INFO'),
      blocking: json['blocking'] as bool? ?? false,
      title: json['title'] as String,
      messageTemplate: json['message_template'] as String,
      recommendedActions:
          (json['recommended_actions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dedupeKeyTemplate: json['dedupe_key_template'] as String?,
    );
  }
}
