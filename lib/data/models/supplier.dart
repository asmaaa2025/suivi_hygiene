/// Supplier model
class Supplier {
  final String id;
  final String organizationId;
  final String name;
  final String? contactInfo;
  final bool isOccasional;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Supplier({
    required this.id,
    required this.organizationId,
    required this.name,
    this.contactInfo,
    this.isOccasional = false,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: (json['id'] as String?) ?? '',
      organizationId: (json['organization_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      contactInfo: json['contact_info'] as String?,
      isOccasional: (json['is_occasional'] as bool?) ?? false,
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
      'name': name,
      'contact_info': contactInfo,
      'is_occasional': isOccasional,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
