/// Audit log entry model (central history)
class AuditLogEntry {
  final String id;
  final String organizationId;
  final String operationType; // 'reception', 'temperature', 'oil_change', 'cleaning', 'non_conformity'
  final String? operationId; // ID of the related record
  final String action; // 'create', 'update', 'delete', 'complete'
  final String? actorUserId; // Admin who performed action
  final String? actorEmployeeId; // Employee if action was assigned
  final String? description; // Human-readable description
  final Map<String, dynamic>? metadata; // Additional context
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    required this.organizationId,
    required this.operationType,
    this.operationId,
    required this.action,
    this.actorUserId,
    this.actorEmployeeId,
    this.description,
    this.metadata,
    required this.createdAt,
  });

  /// Get actor name (user email or employee name)
  String getActorName() {
    if (actorEmployeeId != null) {
      return 'Employee $actorEmployeeId'; // Will be resolved with employee name
    }
    if (actorUserId != null) {
      return 'User $actorUserId'; // Will be resolved with user email
    }
    return 'System';
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: (json['id'] as String?) ?? '',
      organizationId: (json['organization_id'] as String?) ?? '',
      operationType: (json['operation_type'] as String?) ?? '',
      operationId: json['operation_id'] as String?,
      action: (json['action'] as String?) ?? '',
      actorUserId: json['actor_user_id'] as String?,
      actorEmployeeId: json['actor_employee_id'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'operation_type': operationType,
      'operation_id': operationId,
      'action': action,
      'actor_user_id': actorUserId,
      'actor_employee_id': actorEmployeeId,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}



