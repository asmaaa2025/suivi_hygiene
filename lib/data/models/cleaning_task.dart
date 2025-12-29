/// Cleaning task model
class CleaningTask {
  final String id;
  final String nom;
  final bool actif;
  final DateTime createdAt;

  CleaningTask({
    required this.id,
    required this.nom,
    this.actif = true,
    required this.createdAt,
  });

  factory CleaningTask.fromJson(Map<String, dynamic> json) {
    return CleaningTask(
      id: (json['id'] as String?) ?? '',
      nom: (json['nom'] as String?) ?? '',
      actif: (json['actif'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'actif': actif,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
