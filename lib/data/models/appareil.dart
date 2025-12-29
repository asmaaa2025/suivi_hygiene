/// Device/Appareil model
class Appareil {
  final String id;
  final String nom;
  final double? tempMin;
  final double? tempMax;
  final DateTime createdAt;

  Appareil({
    required this.id,
    required this.nom,
    this.tempMin,
    this.tempMax,
    required this.createdAt,
  });

  factory Appareil.fromJson(Map<String, dynamic> json) {
    return Appareil(
      id: (json['id'] as String?) ?? '',
      nom: (json['nom'] as String?) ?? '',
      tempMin: json['temp_min'] != null
          ? ((json['temp_min'] as num?)?.toDouble())
          : null,
      tempMax: json['temp_max'] != null
          ? ((json['temp_max'] as num?)?.toDouble())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'temp_min': tempMin,
      'temp_max': tempMax,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
