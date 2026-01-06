/// Personnel model - HR registry for employees
/// This is separate from Employee model and is used for HR management
class Personnel {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime startDate;
  final DateTime? endDate;
  final ContractType contractType;
  final bool isForeignWorker;
  final String? foreignWorkPermitType;
  final String? foreignWorkPermitNumber;
  final String? userId; // Optional link to UserAccount (Supabase auth user)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Personnel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.startDate,
    this.endDate,
    required this.contractType,
    this.isForeignWorker = false,
    this.foreignWorkPermitType,
    this.foreignWorkPermitNumber,
    this.userId,
    required this.createdAt,
    this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  /// Check if personnel is currently active
  bool get isActive {
    if (endDate == null) return true;
    return endDate!.isAfter(DateTime.now());
  }

  factory Personnel.fromJson(Map<String, dynamic> json) {
    return Personnel(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      contractType: ContractType.fromString(
          json['contract_type'] as String? ?? 'CDI'),
      isForeignWorker: json['is_foreign_worker'] as bool? ?? false,
      foreignWorkPermitType: json['foreign_work_permit_type'] as String?,
      foreignWorkPermitNumber: json['foreign_work_permit_number'] as String?,
      userId: json['user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'contract_type': contractType.toValue(),
      'is_foreign_worker': isForeignWorker,
      'foreign_work_permit_type': foreignWorkPermitType,
      'foreign_work_permit_number': foreignWorkPermitNumber,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Personnel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? startDate,
    DateTime? endDate,
    ContractType? contractType,
    bool? isForeignWorker,
    String? foreignWorkPermitType,
    String? foreignWorkPermitNumber,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Personnel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      contractType: contractType ?? this.contractType,
      isForeignWorker: isForeignWorker ?? this.isForeignWorker,
      foreignWorkPermitType: foreignWorkPermitType ?? this.foreignWorkPermitType,
      foreignWorkPermitNumber:
          foreignWorkPermitNumber ?? this.foreignWorkPermitNumber,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Contract type enum
enum ContractType {
  cdi, // Contrat à durée indéterminée
  cdd, // Contrat à durée déterminée
  alternance, // Alternance
  interime, // Intérim
  extra, // Extra
  stagiaire, // Stagiaire
  autre, // Autre

  cdiEn, // English variants for display
  cddEn,
  alternanceEn,
  interimeEn,
  extraEn,
  stagiaireEn,
  autreEn;

  static ContractType fromString(String? value) {
    if (value == null) return ContractType.cdi;
    switch (value.toLowerCase()) {
      case 'cdi':
        return ContractType.cdi;
      case 'cdd':
        return ContractType.cdd;
      case 'alternance':
        return ContractType.alternance;
      case 'interime':
      case 'intérim':
        return ContractType.interime;
      case 'extra':
        return ContractType.extra;
      case 'stagiaire':
        return ContractType.stagiaire;
      case 'autre':
        return ContractType.autre;
      default:
        return ContractType.cdi;
    }
  }

  String toValue() {
    switch (this) {
      case ContractType.cdi:
      case ContractType.cdiEn:
        return 'CDI';
      case ContractType.cdd:
      case ContractType.cddEn:
        return 'CDD';
      case ContractType.alternance:
      case ContractType.alternanceEn:
        return 'Alternance';
      case ContractType.interime:
      case ContractType.interimeEn:
        return 'Intérim';
      case ContractType.extra:
      case ContractType.extraEn:
        return 'Extra';
      case ContractType.stagiaire:
      case ContractType.stagiaireEn:
        return 'Stagiaire';
      case ContractType.autre:
      case ContractType.autreEn:
        return 'Autre';
    }
  }

  String get displayName {
    switch (this) {
      case ContractType.cdi:
      case ContractType.cdiEn:
        return 'CDI';
      case ContractType.cdd:
      case ContractType.cddEn:
        return 'CDD';
      case ContractType.alternance:
      case ContractType.alternanceEn:
        return 'Alternance';
      case ContractType.interime:
      case ContractType.interimeEn:
        return 'Intérim';
      case ContractType.extra:
      case ContractType.extraEn:
        return 'Extra';
      case ContractType.stagiaire:
      case ContractType.stagiaireEn:
        return 'Stagiaire';
      case ContractType.autre:
      case ContractType.autreEn:
        return 'Autre';
    }
  }
}

