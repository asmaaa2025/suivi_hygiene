/// Temperature reading model
class Temperature {
  final String id;
  final String appareilId;
  final double temperature;
  final String? remarque;
  final String? photoUrl;
  final DateTime createdAt;
  final String? createdBy;

  Temperature({
    required this.id,
    required this.appareilId,
    required this.temperature,
    this.remarque,
    this.photoUrl,
    required this.createdAt,
    this.createdBy,
  });

  factory Temperature.fromJson(Map<String, dynamic> json) {
    // Handle appareil_id - can be null or empty
    final appareilIdValue = json['appareil_id'];
    final appareilId = appareilIdValue != null
        ? (appareilIdValue is String
            ? appareilIdValue
            : appareilIdValue.toString())
        : '';

    return Temperature(
      id: (json['id'] as String?) ?? '',
      appareilId: appareilId,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
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
      'appareil_id': appareilId,
      'temperature': temperature,
      'remarque': remarque,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
