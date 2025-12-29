/// Cleaning/Nettoyage record model
class Nettoyage {
  final String id;
  final String tacheId; // Changed from taskId to tacheId
  final bool done;
  final DateTime? doneAt;
  final bool? conforme; // Optional compliance flag
  final String? remarque;
  final String? photoUrl;
  final DateTime createdAt;
  final String? createdBy;

  Nettoyage({
    required this.id,
    required this.tacheId,
    required this.done,
    this.doneAt,
    this.conforme,
    this.remarque,
    this.photoUrl,
    required this.createdAt,
    this.createdBy,
  });

  factory Nettoyage.fromJson(Map<String, dynamic> json) {
    return Nettoyage(
      id: (json['id'] as String?) ?? '',
      tacheId:
          (json['tache_id'] as String?) ?? (json['task_id'] as String?) ?? '',
      done: (json['done'] as bool?) ?? false,
      doneAt: json['done_at'] != null
          ? (DateTime.tryParse(json['done_at'].toString()))
          : null,
      conforme: json['conforme'] as bool?,
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
      'tache_id': tacheId,
      'done': done,
      'done_at': doneAt?.toIso8601String(),
      'conforme': conforme,
      'remarque': remarque,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
