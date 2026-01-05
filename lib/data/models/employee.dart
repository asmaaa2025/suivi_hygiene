/// Employee model (can be admin or regular employee)
class Employee {
  final String id;
  final String organizationId;
  final String firstName;
  final String lastName;
  final String role; // 'manager', 'cook', 'cleaner', etc.
  final bool isActive;
  final bool isAdmin; // True if employee is an admin
  final String? adminCode; // 4-digit code for admin access (only for admins)
  final String? adminEmail; // Email for admin creation confirmation
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Employee({
    required this.id,
    required this.organizationId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.isActive = true,
    this.isAdmin = false,
    this.adminCode,
    this.adminEmail,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  String get fullName => '$firstName $lastName';

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: (json['id'] as String?) ?? '',
      organizationId: (json['organization_id'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      adminCode: json['admin_code'] as String?,
      adminEmail: json['admin_email'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()))
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'is_active': isActive,
      'is_admin': isAdmin,
      'admin_code': adminCode,
      'admin_email': adminEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }
}



