/// Temperature reading model
class Temperature {
  final String id;
  final String appareilId;
  final double temperature;
  final String? remarque;
  final String? photoUrl;
  final DateTime createdAt;
  final String? createdBy;
  final String? employeeFirstName;
  final String? employeeLastName;

  Temperature({
    required this.id,
    required this.appareilId,
    required this.temperature,
    this.remarque,
    this.photoUrl,
    required this.createdAt,
    this.createdBy,
    this.employeeFirstName,
    this.employeeLastName,
  });

  factory Temperature.fromJson(Map<String, dynamic> json) {
    // Handle appareil_id (UUID) or appareil (TEXT legacy) - can be null or empty
    final appareilIdValue = json['appareil_id'] ?? json['appareil'];
    final appareilId = appareilIdValue != null
        ? (appareilIdValue is String
            ? appareilIdValue
            : appareilIdValue.toString())
        : '';
    
    // Ensure id is never null
    final id = json['id']?.toString() ?? '';

    return Temperature(
      id: id,
      appareilId: appareilId,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      remarque: json['remarque'] as String?,
      photoUrl: (json['photo_url'] as String?) ?? (json['photo_path'] as String?),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? 
             (json['date'] != null 
               ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now())
               : DateTime.now()))
          : (json['date'] != null 
              ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now())
              : DateTime.now()),
      createdBy: json['created_by'] as String?,
      employeeFirstName: json['employee_first_name'] as String?,
      employeeLastName: json['employee_last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appareil_id': appareilId,
      'temperature': temperature,
      'remarque': remarque,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
