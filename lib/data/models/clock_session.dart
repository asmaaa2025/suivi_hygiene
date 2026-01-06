/// Clock session model - represents a clock-in/clock-out session
/// Business model: ONE auth account per organization, multiple employees per org
/// Clock sessions are per EMPLOYEE (employee_id), not per auth user
class ClockSession {
  final String id;
  final String employeeId; // Employee ID (references employees.id, NOT auth.users.id)
  final String organizationId; // Organization ID (references organizations.id)
  final DateTime startAt;
  final DateTime? endAt;
  final String? deviceId; // Optional device identifier
  final DateTime createdAt;
  final DateTime? updatedAt;

  ClockSession({
    required this.id,
    required this.employeeId,
    required this.organizationId,
    required this.startAt,
    this.endAt,
    this.deviceId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if session is currently open (not clocked out)
  bool get isOpen => endAt == null;

  /// Calculate duration if session is closed
  Duration? get duration {
    if (endAt == null) return null;
    return endAt!.difference(startAt);
  }

  /// Get duration as formatted string (e.g., "2h 30m")
  String get durationFormatted {
    final dur = duration;
    if (dur == null) return 'En cours';
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  factory ClockSession.fromJson(Map<String, dynamic> json) {
    // Support both old (user_id) and new (employee_id) column names for migration
    final employeeId = json['employee_id'] as String? ?? json['user_id'] as String;
    final organizationId = json['organization_id'] as String? ?? '';
    
    return ClockSession(
      id: json['id'] as String,
      employeeId: employeeId,
      organizationId: organizationId,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String)
          : null,
      deviceId: json['device_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'organization_id': organizationId,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ClockSession copyWith({
    String? id,
    String? employeeId,
    String? organizationId,
    DateTime? startAt,
    DateTime? endAt,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClockSession(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      organizationId: organizationId ?? this.organizationId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

