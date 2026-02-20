/// Compte utilisateur HACCPilot (distinct du registre personnel)
/// Permet à l'admin de créer des comptes de connexion à l'app
class HaccpUserAccount {
  final String id;
  final String email;
  final String? authUserId;
  final String? displayName;
  final String? organizationId;
  final String? personnelId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  HaccpUserAccount({
    required this.id,
    required this.email,
    this.authUserId,
    this.displayName,
    this.organizationId,
    this.personnelId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayLabel =>
      displayName?.isNotEmpty == true ? displayName! : email;

  factory HaccpUserAccount.fromJson(Map<String, dynamic> json) {
    return HaccpUserAccount(
      id: json['id'] as String,
      email: json['email'] as String,
      authUserId: json['auth_user_id'] as String?,
      displayName: json['display_name'] as String?,
      organizationId: json['organization_id'] as String?,
      personnelId: json['personnel_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'auth_user_id': authUserId,
    'display_name': displayName,
    'organization_id': organizationId,
    'personnel_id': personnelId,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
