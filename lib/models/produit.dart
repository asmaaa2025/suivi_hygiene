enum TypeProduit {
  fini, // Produit fini vendu aux clients
  prepare, // Produit préparé (farce, etc.) pour créer d'autres produits
  ouverture, // Produit ouvert (bouteille de lait, conserve, etc.)
  decongelation // Produit décongelé
}

extension TypeProduitExtension on TypeProduit {
  /// Retourne la DLC par défaut en jours selon le type de produit
  int get dlcParDefaut {
    switch (this) {
      case TypeProduit.fini:
        return 7; // 7 jours pour les produits finis
      case TypeProduit.prepare:
        return 3; // 3 jours pour les produits préparés (farce, etc.)
      case TypeProduit.ouverture:
        return 1; // 1 jour pour les produits ouverts
      case TypeProduit.decongelation:
        return 2; // 2 jours pour les produits décongelés
    }
  }

  /// Retourne la description de la DLC par défaut
  String get dlcDescription {
    switch (this) {
      case TypeProduit.fini:
        return '7 jours (produit fini)';
      case TypeProduit.prepare:
        return '3 jours (produit préparé)';
      case TypeProduit.ouverture:
        return '1 jour (produit ouvert)';
      case TypeProduit.decongelation:
        return '2 jours (produit décongelé)';
    }
  }

  /// Retourne la couleur associée au type
  String get couleurHex {
    switch (this) {
      case TypeProduit.fini:
        return '#4CAF50'; // Vert
      case TypeProduit.prepare:
        return '#FF9800'; // Orange
      case TypeProduit.ouverture:
        return '#F44336'; // Rouge
      case TypeProduit.decongelation:
        return '#2196F3'; // Bleu
    }
  }
}

class Produit {
  final String id;
  final String nom;
  final TypeProduit typeProduit; // Nouveau: type de produit
  final DateTime? dlc; // Date fixe (pour compatibilité)
  final int? dlcJours; // Nombre de jours pour calculer DLC
  final DateTime? dluo; // Date limite d'utilisation optimale (optionnelle)
  final DateTime dateFabrication; // Date de fabrication/préparation
  final DateTime? heurePreparation; // Heure de préparation (si DLC = jour même)
  final String? lot;
  final double? poids;
  final String? preparateur; // Nom du préparateur ou du poste
  final DateTime dateCreation;
  final DateTime dateModification;
  final String? utilisateurCode; // Code de l'utilisateur qui a créé le produit
  final bool surgelagable; // Nouveau: produit peut-il être surgelé
  final int? dlcSurgelationJours; // Nouveau: DLC en jours pour la surgélation
  final String? ingredients; // Nouveau: liste des ingrédients
  final String? quantite; // Nouveau: quantité par unité
  final String? origineViande; // Nouveau: origine de la viande
  final String? allergenes; // Nouveau: allergènes présents

  Produit({
    required this.id,
    required this.nom,
    required this.typeProduit,
    this.dlc,
    this.dlcJours,
    this.dluo,
    required this.dateFabrication,
    this.heurePreparation,
    this.lot,
    this.poids,
    this.preparateur,
    required this.dateCreation,
    required this.dateModification,
    this.utilisateurCode,
    this.surgelagable = false,
    this.dlcSurgelationJours,
    this.ingredients,
    this.quantite,
    this.origineViande,
    this.allergenes,
  });

  factory Produit.fromMap(Map<String, dynamic> map) {
    return Produit(
      id: map['id'],
      nom: map['nom'],
      typeProduit: TypeProduit.values.firstWhere(
        (e) => e.name == (map['type_produit'] ?? 'fini'),
        orElse: () => TypeProduit.fini,
      ),
      dlc: map['dlc'] != null ? DateTime.parse(map['dlc']) : null,
      dlcJours: map['dlc_jours'],
      dluo: map['dluo'] != null ? DateTime.parse(map['dluo']) : null,
      dateFabrication: DateTime.parse(map['date_fabrication']),
      heurePreparation: map['heure_preparation'] != null
          ? DateTime.parse(map['heure_preparation'])
          : null,
      lot: map['lot'],
      poids: map['poids'],
      preparateur: map['preparateur'],
      dateCreation: DateTime.parse(map['date_creation']),
      dateModification: DateTime.parse(map['date_modification']),
      utilisateurCode: map['utilisateur_code'],
      surgelagable: map['surgelagable'] == 1,
      dlcSurgelationJours: map['dlc_surgelation_jours'],
      ingredients: map['ingredients'],
      quantite: map['quantite'],
      origineViande: map['origine_viande'],
      allergenes: map['allergenes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'type_produit': typeProduit.name,
      'dlc': dlc?.toIso8601String(),
      'dlc_jours': dlcJours,
      'dluo': dluo?.toIso8601String(),
      'date_fabrication': dateFabrication.toIso8601String(),
      'heure_preparation': heurePreparation?.toIso8601String(),
      'lot': lot,
      'poids': poids,
      'preparateur': preparateur,
      'date_creation': dateCreation.toIso8601String(),
      'date_modification': dateModification.toIso8601String(),
      'utilisateur_code': utilisateurCode,
      'surgelagable': surgelagable ? 1 : 0,
      'dlc_surgelation_jours': dlcSurgelationJours,
      'ingredients': ingredients,
      'quantite': quantite,
      'origine_viande': origineViande,
      'allergenes': allergenes,
    };
  }

  // Calcul de la DLC en fonction de la date de fabrication
  DateTime? get dlcCalculee {
    if (dlcJours != null) {
      return dateFabrication.add(Duration(days: dlcJours!));
    }
    return dlc;
  }

  // Nouvelle méthode pour calculer la DLC avec option de surgélation
  DateTime computeDlc(DateTime fabricationDate, {bool surgeler = false}) {
    if (surgeler && surgelagable && dlcSurgelationJours != null) {
      return fabricationDate.add(Duration(days: dlcSurgelationJours!));
    } else if (dlcJours != null) {
      return fabricationDate.add(Duration(days: dlcJours!));
    } else {
      return fabricationDate; // fallback
    }
  }

  // Copie avec nouvelles valeurs
  Produit copyWith({
    String? id,
    String? nom,
    TypeProduit? typeProduit,
    DateTime? dlc,
    int? dlcJours,
    DateTime? dluo,
    DateTime? dateFabrication,
    DateTime? heurePreparation,
    String? lot,
    double? poids,
    String? preparateur,
    DateTime? dateCreation,
    DateTime? dateModification,
    String? utilisateurCode,
    bool? surgelagable,
    int? dlcSurgelationJours,
    String? ingredients,
    String? quantite,
    String? origineViande,
    String? allergenes,
  }) {
    return Produit(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      typeProduit: typeProduit ?? this.typeProduit,
      dlc: dlc ?? this.dlc,
      dlcJours: dlcJours ?? this.dlcJours,
      dluo: dluo ?? this.dluo,
      dateFabrication: dateFabrication ?? this.dateFabrication,
      heurePreparation: heurePreparation ?? this.heurePreparation,
      lot: lot ?? this.lot,
      poids: poids ?? this.poids,
      preparateur: preparateur ?? this.preparateur,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification ?? this.dateModification,
      utilisateurCode: utilisateurCode ?? this.utilisateurCode,
      surgelagable: surgelagable ?? this.surgelagable,
      dlcSurgelationJours: dlcSurgelationJours ?? this.dlcSurgelationJours,
      ingredients: ingredients ?? this.ingredients,
      quantite: quantite ?? this.quantite,
      origineViande: origineViande ?? this.origineViande,
      allergenes: allergenes ?? this.allergenes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Produit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Produit(id: $id, nom: $nom, typeProduit: $typeProduit, dlc: $dlc, dlcJours: $dlcJours, dluo: $dluo, dateFabrication: $dateFabrication, lot: $lot, poids: $poids, preparateur: $preparateur)';
  }
}
