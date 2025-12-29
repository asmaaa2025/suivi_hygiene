/// Reception model
class Reception {
  final String id;
  final String produitId;
  final String? fournisseur;
  final String? lot;
  final DateTime? dluo;
  final double? temperature;
  final String? remarque;
  final String? photoUrl;
  final DateTime receivedAt;
  final DateTime createdAt;
  final String? createdBy;

  Reception({
    required this.id,
    required this.produitId,
    this.fournisseur,
    this.lot,
    this.dluo,
    this.temperature,
    this.remarque,
    this.photoUrl,
    required this.receivedAt,
    required this.createdAt,
    this.createdBy,
  });

  factory Reception.fromJson(Map<String, dynamic> json) {
    return Reception(
      id: (json['id'] as String?) ?? '',
      produitId: (json['produit_id'] as String?) ?? '',
      fournisseur: json['fournisseur'] as String?,
      lot: json['lot'] as String?,
      dluo: json['dluo'] != null
          ? (DateTime.tryParse(json['dluo'].toString()))
          : null,
      temperature: json['temperature'] != null
          ? ((json['temperature'] as num?)?.toDouble())
          : null,
      remarque: json['remarque'] as String?,
      photoUrl: json['photo_url'] as String?,
      receivedAt: json['received_at'] != null
          ? (DateTime.tryParse(json['received_at'].toString()) ??
              DateTime.now())
          : (json['created_at'] != null
              ? (DateTime.tryParse(json['created_at'].toString()) ??
                  DateTime.now())
              : DateTime.now()),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'produit_id': produitId,
      'fournisseur': fournisseur,
      'lot': lot,
      'dluo': dluo?.toIso8601String(),
      'temperature': temperature,
      'remarque': remarque,
      'photo_url': photoUrl,
      'received_at': receivedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
