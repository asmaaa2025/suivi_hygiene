/// Non-conformity model (refusal declaration)
class NonConformity {
  final String id;
  final String? receptionId;
  // 4 refusal criteria
  final bool temperatureNonCompliant; // >6-7°C fresh OR >-18°C frozen
  final bool packagingOpened; // Opened carton
  final bool packagingWet; // Wet carton
  final bool labelMissing; // Missing label on carton
  // Details
  final String? declarationText;
  final List<String> photoUrls;
  final DateTime createdAt;
  final String? createdBy;
  final String? performedByEmployeeId;

  NonConformity({
    required this.id,
    this.receptionId,
    this.temperatureNonCompliant = false,
    this.packagingOpened = false,
    this.packagingWet = false,
    this.labelMissing = false,
    this.declarationText,
    this.photoUrls = const [],
    required this.createdAt,
    this.createdBy,
    this.performedByEmployeeId,
  });

  /// Check if any refusal criteria is met
  bool get hasAnyRefusal => 
      temperatureNonCompliant || 
      packagingOpened || 
      packagingWet || 
      labelMissing;

  factory NonConformity.fromJson(Map<String, dynamic> json) {
    return NonConformity(
      id: (json['id'] as String?) ?? '',
      receptionId: json['reception_id'] as String?,
      temperatureNonCompliant: (json['temperature_non_compliant'] as bool?) ?? false,
      packagingOpened: (json['packaging_opened'] as bool?) ?? false,
      packagingWet: (json['packaging_wet'] as bool?) ?? false,
      labelMissing: (json['label_missing'] as bool?) ?? false,
      declarationText: json['declaration_text'] as String?,
      photoUrls: json['photo_urls'] != null
          ? List<String>.from(json['photo_urls'] as List)
          : [],
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
      performedByEmployeeId: json['performed_by_employee_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reception_id': receptionId,
      'temperature_non_compliant': temperatureNonCompliant,
      'packaging_opened': packagingOpened,
      'packaging_wet': packagingWet,
      'label_missing': labelMissing,
      'declaration_text': declarationText,
      'photo_urls': photoUrls,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'performed_by_employee_id': performedByEmployeeId,
    };
  }
}



