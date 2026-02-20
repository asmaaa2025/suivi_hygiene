/// Plan de rappel - Gestion des crises sanitaires (PMS)
/// Règlement 178/2002 - Traçabilité et retrait des produits

class Rappel {
  final String id;
  final String produitNom;
  final String? lot;
  final String? fournisseur;
  final String motif;
  final DateTime dateDetection;
  final RappelStatut statut;
  final String? actionsPrises;
  final String? contactDdpp;
  final String? organizationId;
  final DateTime createdAt;
  final String? createdBy;

  Rappel({
    required this.id,
    required this.produitNom,
    this.lot,
    this.fournisseur,
    required this.motif,
    required this.dateDetection,
    this.statut = RappelStatut.ouvert,
    this.actionsPrises,
    this.contactDdpp,
    this.organizationId,
    required this.createdAt,
    this.createdBy,
  });

  factory Rappel.fromJson(Map<String, dynamic> json) {
    return Rappel(
      id: json['id']?.toString() ?? '',
      produitNom: json['produit_nom'] as String? ?? '',
      lot: json['lot'] as String?,
      fournisseur: json['fournisseur'] as String?,
      motif: json['motif'] as String? ?? '',
      dateDetection: json['date_detection'] != null
          ? DateTime.tryParse(json['date_detection'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      statut: RappelStatut.fromString(json['statut'] as String?),
      actionsPrises: json['actions_prises'] as String?,
      contactDdpp: json['contact_ddpp'] as String?,
      organizationId: json['organization_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'produit_nom': produitNom,
      'lot': lot,
      'fournisseur': fournisseur,
      'motif': motif,
      'date_detection': dateDetection.toIso8601String().split('T')[0],
      'statut': statut.value,
      'actions_prises': actionsPrises,
      'contact_ddpp': contactDdpp,
      'organization_id': organizationId,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

enum RappelStatut {
  ouvert,
  enCours,
  clos;

  String get value {
    switch (this) {
      case RappelStatut.ouvert:
        return 'ouvert';
      case RappelStatut.enCours:
        return 'en_cours';
      case RappelStatut.clos:
        return 'clos';
    }
  }

  String get displayName {
    switch (this) {
      case RappelStatut.ouvert:
        return 'Ouvert';
      case RappelStatut.enCours:
        return 'En cours';
      case RappelStatut.clos:
        return 'Clos';
    }
  }

  static RappelStatut fromString(String? value) {
    switch (value) {
      case 'ouvert':
        return RappelStatut.ouvert;
      case 'en_cours':
        return RappelStatut.enCours;
      case 'clos':
        return RappelStatut.clos;
      default:
        return RappelStatut.ouvert;
    }
  }
}
