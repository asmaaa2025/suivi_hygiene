/// Product model
class Produit {
  final String id;
  final String nom;
  final String? description;
  final String? category;
  final String? typeProduit; // 'reçu', 'fini', 'transformé', etc.
  final String? supplierId; // Optional supplier for "reçu" products
  final DateTime createdAt;
  final DateTime? updatedAt;

  Produit({
    required this.id,
    required this.nom,
    this.description,
    this.category,
    this.typeProduit,
    this.supplierId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      id: (json['id'] as String?) ?? '',
      nom: (json['nom'] as String?) ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      typeProduit: json['type_produit'] as String?,
      supplierId: json['supplier_id'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'category': category,
      'type_produit': typeProduit,
      'supplier_id': supplierId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
