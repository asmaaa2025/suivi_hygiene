/// Oil change model
class OilChange {
  final String id;
  final String friteuseId;
  final String? friteuseNom;
  final DateTime changedAt;
  final double? quantite;
  final String? remarque;
  final String? photoUrl;
  final DateTime createdAt;
  final String? createdBy;
  final String? employeeFirstName;
  final String? employeeLastName;

  OilChange({
    required this.id,
    required this.friteuseId,
    this.friteuseNom,
    required this.changedAt,
    this.quantite,
    this.remarque,
    this.photoUrl,
    required this.createdAt,
    this.createdBy,
    this.employeeFirstName,
    this.employeeLastName,
  });

  factory OilChange.fromJson(Map<String, dynamic> json) {
    double? _parseQuantite(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return OilChange(
      id: json['id']?.toString() ?? '',
      friteuseId: json['friteuse_id']?.toString() ?? '',
      friteuseNom: json['friteuse_nom'] as String?,
      changedAt: json['changed_at'] != null
          ? (DateTime.tryParse(json['changed_at'].toString()) ?? DateTime.now())
          : (json['created_at'] != null
                ? (DateTime.tryParse(json['created_at'].toString()) ??
                      DateTime.now())
                : DateTime.now()),
      quantite: _parseQuantite(json['quantite']),
      remarque: json['remarque'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
      employeeFirstName: json['employee_first_name'] as String?,
      employeeLastName: json['employee_last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friteuse_id': friteuseId,
      'changed_at': changedAt.toIso8601String(),
      'quantite': quantite,
      'remarque': remarque,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'employee_first_name': employeeFirstName,
      'employee_last_name': employeeLastName,
    };
  }
}
