/// Oil change model
class OilChange {
  final String id;
  final String friteuseId;
  final DateTime changedAt;
  final String? remarque;
  final String? photoUrl;
  final DateTime createdAt;
  final String? createdBy;

  OilChange({
    required this.id,
    required this.friteuseId,
    required this.changedAt,
    this.remarque,
    this.photoUrl,
    required this.createdAt,
    this.createdBy,
  });

  factory OilChange.fromJson(Map<String, dynamic> json) {
    return OilChange(
      id: (json['id'] as String?) ?? '',
      friteuseId: (json['friteuse_id'] as String?) ?? '',
      changedAt: json['changed_at'] != null
          ? (DateTime.tryParse(json['changed_at'].toString()) ?? DateTime.now())
          : (json['created_at'] != null
              ? (DateTime.tryParse(json['created_at'].toString()) ??
                  DateTime.now())
              : DateTime.now()),
      remarque: json['remarque'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friteuse_id': friteuseId,
      'changed_at': changedAt.toIso8601String(),
      'remarque': remarque,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
