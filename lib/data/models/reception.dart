/// Reception model
class Reception {
  final String id;
  /// Null if the catalogue product was deleted (history kept via [produitLegacy]/[articleLegacy]).
  final String? produitId;
  final String? produitLegacy;
  final String? articleLegacy;
  final String? supplierId; // Link to supplier
  final String? fournisseur; // Legacy text field
  final String? lot;
  final DateTime? dluo;
  final double? temperature;
  final String? remarque;
  final String? photoUrl;
  final String? statut;
  final int? conforme;
  final DateTime receivedAt;
  final DateTime createdAt;
  final String? createdBy;
  final String? nonConformityId;
  final String? performedByEmployeeId;
  final String? employeeFirstName;
  final String? employeeLastName;

  Reception({
    required this.id,
    this.produitId,
    this.produitLegacy,
    this.articleLegacy,
    this.supplierId,
    this.fournisseur,
    this.lot,
    this.dluo,
    this.temperature,
    this.remarque,
    this.photoUrl,
    this.statut,
    this.conforme,
    required this.receivedAt,
    required this.createdAt,
    this.createdBy,
    this.nonConformityId,
    this.performedByEmployeeId,
    this.employeeFirstName,
    this.employeeLastName,
  });

  /// Name kept in DB when the product row is removed or for legacy rows.
  String get archivedProductNameLabel {
    final p = produitLegacy?.trim();
    if (p != null && p.isNotEmpty) return p;
    final a = articleLegacy?.trim();
    if (a != null && a.isNotEmpty) return a;
    return '';
  }

  /// Prefer live catalogue name, then archived text from receptions.produit/article.
  String displayProductName(String? catalogueProductNom) {
    final live = catalogueProductNom?.trim();
    if (live != null && live.isNotEmpty) return live;
    final arch = archivedProductNameLabel;
    if (arch.isNotEmpty) return arch;
    return 'Produit inconnu';
  }

  factory Reception.fromJson(Map<String, dynamic> json) {
    final rawPid = json['produit_id']?.toString();
    final pid = (rawPid != null && rawPid.isNotEmpty) ? rawPid : null;
    return Reception(
      id: json['id']?.toString() ?? '',
      produitId: pid,
      produitLegacy: json['produit'] as String?,
      articleLegacy: json['article'] as String?,
      supplierId:
          json['supplier_id'] as String? ?? json['fournisseur_id'] as String?,
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
      statut: json['statut'] as String?,
      conforme: (json['conforme'] as num?)?.toInt(),
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
      nonConformityId: json['non_conformity_id'] as String?,
      performedByEmployeeId: json['performed_by_employee_id'] as String?,
      employeeFirstName: json['employee_first_name'] as String?,
      employeeLastName: json['employee_last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (produitId != null) 'produit_id': produitId,
      'supplier_id': supplierId,
      'fournisseur': fournisseur,
      'lot': lot,
      'dluo': dluo?.toIso8601String(),
      'temperature': temperature,
      'remarque': remarque,
      'photo_url': photoUrl,
      'statut': statut,
      'conforme': conforme,
      'received_at': receivedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'non_conformity_id': nonConformityId,
      'performed_by_employee_id': performedByEmployeeId,
    };
  }
}
