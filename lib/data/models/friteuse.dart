/// Fryer/Friteuse model
class Friteuse {
  final String id;
  final String nom;
  final DateTime createdAt;

  Friteuse({
    required this.id,
    required this.nom,
    required this.createdAt,
  });

  factory Friteuse.fromJson(Map<String, dynamic> json) {
    return Friteuse(
      id: (json['id'] as String?) ?? '',
      nom: (json['nom'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
