/// Non-Conformity (NC) Models
/// Complete models for the 8-section NC form structure

import 'package:flutter/foundation.dart';

// ============================================
// ENUMS
// ============================================

enum NCStatus {
  draft,
  open,
  inProgress,
  closed;

  String get value {
    switch (this) {
      case NCStatus.draft:
        return 'draft';
      case NCStatus.open:
        return 'open';
      case NCStatus.inProgress:
        return 'in_progress';
      case NCStatus.closed:
        return 'closed';
    }
  }

  static NCStatus fromString(String? value) {
    switch (value) {
      case 'draft':
        return NCStatus.draft;
      case 'open':
        return NCStatus.open;
      case 'in_progress':
        return NCStatus.inProgress;
      case 'closed':
        return NCStatus.closed;
      default:
        return NCStatus.draft;
    }
  }
}

enum NCObjectCategory {
  nuisibles,
  maintenance,
  nettoyageDesinfection,
  chaineDuFroid,
  prpo,
  ccp,
  reclamationClient,
  autre;

  String get value {
    switch (this) {
      case NCObjectCategory.nuisibles:
        return 'nuisibles';
      case NCObjectCategory.maintenance:
        return 'maintenance';
      case NCObjectCategory.nettoyageDesinfection:
        return 'nettoyage_desinfection';
      case NCObjectCategory.chaineDuFroid:
        return 'chaine_du_froid';
      case NCObjectCategory.prpo:
        return 'prpo';
      case NCObjectCategory.ccp:
        return 'ccp';
      case NCObjectCategory.reclamationClient:
        return 'reclamation_client';
      case NCObjectCategory.autre:
        return 'autre';
    }
  }

  String get displayName {
    switch (this) {
      case NCObjectCategory.nuisibles:
        return 'Nuisibles';
      case NCObjectCategory.maintenance:
        return 'Maintenance';
      case NCObjectCategory.nettoyageDesinfection:
        return 'Nettoyage/Désinfection';
      case NCObjectCategory.chaineDuFroid:
        return 'Chaîne du froid';
      case NCObjectCategory.prpo:
        return 'PRPO';
      case NCObjectCategory.ccp:
        return 'CCP';
      case NCObjectCategory.reclamationClient:
        return 'Réclamation client';
      case NCObjectCategory.autre:
        return 'Autre';
    }
  }

  static NCObjectCategory fromString(String? value) {
    switch (value) {
      case 'nuisibles':
        return NCObjectCategory.nuisibles;
      case 'maintenance':
        return NCObjectCategory.maintenance;
      case 'nettoyage_desinfection':
        return NCObjectCategory.nettoyageDesinfection;
      case 'chaine_du_froid':
        return NCObjectCategory.chaineDuFroid;
      case 'prpo':
        return NCObjectCategory.prpo;
      case 'ccp':
        return NCObjectCategory.ccp;
      case 'reclamation_client':
        return NCObjectCategory.reclamationClient;
      case 'autre':
        return NCObjectCategory.autre;
      default:
        return NCObjectCategory.autre;
    }
  }
}

enum NCSourceType {
  temperature,
  reception,
  oil,
  cleaning;

  String get value {
    switch (this) {
      case NCSourceType.temperature:
        return 'temperature';
      case NCSourceType.reception:
        return 'reception';
      case NCSourceType.oil:
        return 'oil';
      case NCSourceType.cleaning:
        return 'cleaning';
    }
  }

  static NCSourceType fromString(String? value) {
    switch (value) {
      case 'temperature':
        return NCSourceType.temperature;
      case 'reception':
        return NCSourceType.reception;
      case 'oil':
        return NCSourceType.oil;
      case 'cleaning':
        return NCSourceType.cleaning;
      default:
        return NCSourceType.temperature;
    }
  }
}

enum NCCauseCategory {
  methode,
  materiel,
  mainOeuvre,
  matiere,
  milieu;

  String get value {
    switch (this) {
      case NCCauseCategory.methode:
        return 'methode';
      case NCCauseCategory.materiel:
        return 'materiel';
      case NCCauseCategory.mainOeuvre:
        return 'main_oeuvre';
      case NCCauseCategory.matiere:
        return 'matiere';
      case NCCauseCategory.milieu:
        return 'milieu';
    }
  }

  String get displayName {
    switch (this) {
      case NCCauseCategory.methode:
        return 'Méthode';
      case NCCauseCategory.materiel:
        return 'Matériel';
      case NCCauseCategory.mainOeuvre:
        return 'Main d\'œuvre';
      case NCCauseCategory.matiere:
        return 'Matière';
      case NCCauseCategory.milieu:
        return 'Milieu';
    }
  }

  static NCCauseCategory fromString(String? value) {
    switch (value) {
      case 'methode':
        return NCCauseCategory.methode;
      case 'materiel':
        return NCCauseCategory.materiel;
      case 'main_oeuvre':
        return NCCauseCategory.mainOeuvre;
      case 'matiere':
        return NCCauseCategory.matiere;
      case 'milieu':
        return NCCauseCategory.milieu;
      default:
        return NCCauseCategory.methode;
    }
  }
}

enum NCActionStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  String get value {
    switch (this) {
      case NCActionStatus.pending:
        return 'pending';
      case NCActionStatus.inProgress:
        return 'in_progress';
      case NCActionStatus.completed:
        return 'completed';
      case NCActionStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case NCActionStatus.pending:
        return 'En attente';
      case NCActionStatus.inProgress:
        return 'En cours';
      case NCActionStatus.completed:
        return 'Terminé';
      case NCActionStatus.cancelled:
        return 'Annulé';
    }
  }

  static NCActionStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return NCActionStatus.pending;
      case 'in_progress':
        return NCActionStatus.inProgress;
      case 'completed':
        return NCActionStatus.completed;
      case 'cancelled':
        return NCActionStatus.cancelled;
      default:
        return NCActionStatus.pending;
    }
  }
}

// ============================================
// MAIN NON_CONFORMITY MODEL
// ============================================

class NonConformity {
  final String id;
  final String organizationId;

  // Status and identification
  final NCStatus status;
  final String? ficheNumber;
  final DateTime detectionDate;

  // Section 1: Identification
  final String? openedByEmployeeId;
  final String? openedByRoleService;
  final NCObjectCategory objectCategory;
  final String? objectOther;

  // Section 2: Description
  final String? productId;
  final String? productName;
  final String? step;
  final String description;
  final String? sanitaryImpact;

  // Section 3: Immediate action
  final bool immediateActionDone;
  final String? immediateActionDetail;
  final String? immediateActionDoneBy;
  final DateTime? immediateActionDoneAt;

  // Section 4: Evaluation RQ
  final DateTime? rqDate;
  final String? rqClassification;
  final bool rqActionCorrectiveRequired;

  // Source tracking
  final NCSourceType? sourceType;
  final String? sourceTable;
  final String? sourceId;
  final Map<String, dynamic> sourcePayload; // JSONB snapshot

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  // Related data (loaded separately)
  final List<NCCause>? causes;
  final List<NCSolution>? solutions;
  final List<NCAction>? actions;
  final List<NCVerification>? verifications;
  final List<NCAttachment>? attachments;

  NonConformity({
    required this.id,
    required this.organizationId,
    this.status = NCStatus.draft,
    this.ficheNumber,
    required this.detectionDate,
    this.openedByEmployeeId,
    this.openedByRoleService,
    required this.objectCategory,
    this.objectOther,
    this.productId,
    this.productName,
    this.step,
    required this.description,
    this.sanitaryImpact,
    this.immediateActionDone = false,
    this.immediateActionDetail,
    this.immediateActionDoneBy,
    this.immediateActionDoneAt,
    this.rqDate,
    this.rqClassification,
    this.rqActionCorrectiveRequired = false,
    this.sourceType,
    this.sourceTable,
    this.sourceId,
    Map<String, dynamic>? sourcePayload,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.causes,
    this.solutions,
    this.actions,
    this.verifications,
    this.attachments,
  }) : sourcePayload = sourcePayload ?? {};

  factory NonConformity.fromJson(Map<String, dynamic> json) {
    return NonConformity(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      status: NCStatus.fromString(json['status'] as String?),
      ficheNumber: json['fiche_number'] as String?,
      detectionDate: DateTime.parse(json['detection_date'] as String),
      openedByEmployeeId: json['opened_by_employee_id'] as String?,
      openedByRoleService: json['opened_by_role_service'] as String?,
      objectCategory: NCObjectCategory.fromString(
        json['object_category'] as String?,
      ),
      objectOther: json['object_other'] as String?,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String?,
      step: json['step'] as String?,
      description: json['description'] as String? ?? '',
      sanitaryImpact: json['sanitary_impact'] as String?,
      immediateActionDone: (json['immediate_action_done'] as bool?) ?? false,
      immediateActionDetail: json['immediate_action_detail'] as String?,
      immediateActionDoneBy: json['immediate_action_done_by'] as String?,
      immediateActionDoneAt: json['immediate_action_done_at'] != null
          ? DateTime.parse(json['immediate_action_done_at'] as String)
          : null,
      rqDate: json['rq_date'] != null
          ? DateTime.parse(json['rq_date'] as String)
          : null,
      rqClassification: json['rq_classification'] as String?,
      rqActionCorrectiveRequired:
          (json['rq_action_corrective_required'] as bool?) ?? false,
      sourceType: json['source_type'] != null
          ? NCSourceType.fromString(json['source_type'] as String)
          : null,
      sourceTable: json['source_table'] as String?,
      sourceId: json['source_id'] as String?,
      sourcePayload: json['source_payload'] != null
          ? Map<String, dynamic>.from(json['source_payload'] as Map)
          : {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'status': status.value,
      'fiche_number': ficheNumber,
      'detection_date': detectionDate.toIso8601String(),
      'opened_by_employee_id': openedByEmployeeId,
      'opened_by_role_service': openedByRoleService,
      'object_category': objectCategory.value,
      'object_other': objectOther,
      'product_id': productId,
      'product_name': productName,
      'step': step,
      'description': description,
      'sanitary_impact': sanitaryImpact,
      'immediate_action_done': immediateActionDone,
      'immediate_action_detail': immediateActionDetail,
      'immediate_action_done_by': immediateActionDoneBy,
      'immediate_action_done_at': immediateActionDoneAt?.toIso8601String(),
      'rq_date': rqDate?.toIso8601String(),
      'rq_classification': rqClassification,
      'rq_action_corrective_required': rqActionCorrectiveRequired,
      'source_type': sourceType?.value,
      'source_table': sourceTable,
      'source_id': sourceId,
      'source_payload': sourcePayload,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  NonConformity copyWith({
    String? id,
    String? organizationId,
    NCStatus? status,
    String? ficheNumber,
    DateTime? detectionDate,
    String? openedByEmployeeId,
    String? openedByRoleService,
    NCObjectCategory? objectCategory,
    String? objectOther,
    String? productId,
    String? productName,
    String? step,
    String? description,
    String? sanitaryImpact,
    bool? immediateActionDone,
    String? immediateActionDetail,
    String? immediateActionDoneBy,
    DateTime? immediateActionDoneAt,
    DateTime? rqDate,
    String? rqClassification,
    bool? rqActionCorrectiveRequired,
    NCSourceType? sourceType,
    String? sourceTable,
    String? sourceId,
    Map<String, dynamic>? sourcePayload,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<NCCause>? causes,
    List<NCSolution>? solutions,
    List<NCAction>? actions,
    List<NCVerification>? verifications,
    List<NCAttachment>? attachments,
  }) {
    return NonConformity(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      status: status ?? this.status,
      ficheNumber: ficheNumber ?? this.ficheNumber,
      detectionDate: detectionDate ?? this.detectionDate,
      openedByEmployeeId: openedByEmployeeId ?? this.openedByEmployeeId,
      openedByRoleService: openedByRoleService ?? this.openedByRoleService,
      objectCategory: objectCategory ?? this.objectCategory,
      objectOther: objectOther ?? this.objectOther,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      step: step ?? this.step,
      description: description ?? this.description,
      sanitaryImpact: sanitaryImpact ?? this.sanitaryImpact,
      immediateActionDone: immediateActionDone ?? this.immediateActionDone,
      immediateActionDetail:
          immediateActionDetail ?? this.immediateActionDetail,
      immediateActionDoneBy:
          immediateActionDoneBy ?? this.immediateActionDoneBy,
      immediateActionDoneAt:
          immediateActionDoneAt ?? this.immediateActionDoneAt,
      rqDate: rqDate ?? this.rqDate,
      rqClassification: rqClassification ?? this.rqClassification,
      rqActionCorrectiveRequired:
          rqActionCorrectiveRequired ?? this.rqActionCorrectiveRequired,
      sourceType: sourceType ?? this.sourceType,
      sourceTable: sourceTable ?? this.sourceTable,
      sourceId: sourceId ?? this.sourceId,
      sourcePayload: sourcePayload ?? this.sourcePayload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      causes: causes ?? this.causes,
      solutions: solutions ?? this.solutions,
      actions: actions ?? this.actions,
      verifications: verifications ?? this.verifications,
      attachments: attachments ?? this.attachments,
    );
  }
}

// ============================================
// CHILD MODELS
// ============================================

class NCCause {
  final String id;
  final String nonConformityId;
  final NCCauseCategory category;
  final String causeText;
  final bool isMostProbable;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderIndex;

  NCCause({
    required this.id,
    required this.nonConformityId,
    required this.category,
    required this.causeText,
    this.isMostProbable = false,
    required this.createdAt,
    required this.updatedAt,
    this.orderIndex = 0,
  });

  factory NCCause.fromJson(Map<String, dynamic> json) {
    return NCCause(
      id: json['id'] as String,
      nonConformityId: json['non_conformity_id'] as String,
      category: NCCauseCategory.fromString(json['category'] as String?),
      causeText: json['cause_text'] as String,
      isMostProbable: (json['is_most_probable'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'non_conformity_id': nonConformityId,
      'category': category.value,
      'cause_text': causeText,
      'is_most_probable': isMostProbable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_index': orderIndex,
    };
  }
}

class NCSolution {
  final String id;
  final String nonConformityId;
  final String solutionText;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderIndex;

  NCSolution({
    required this.id,
    required this.nonConformityId,
    required this.solutionText,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
    this.orderIndex = 0,
  });

  factory NCSolution.fromJson(Map<String, dynamic> json) {
    return NCSolution(
      id: json['id'] as String,
      nonConformityId: json['non_conformity_id'] as String,
      solutionText: json['solution_text'] as String,
      priority: (json['priority'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'non_conformity_id': nonConformityId,
      'solution_text': solutionText,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_index': orderIndex,
    };
  }
}

class NCAction {
  final String id;
  final String nonConformityId;
  final String actionText;
  final String? responsibleEmployeeId;
  final DateTime? targetDate;
  final NCActionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderIndex;

  NCAction({
    required this.id,
    required this.nonConformityId,
    required this.actionText,
    this.responsibleEmployeeId,
    this.targetDate,
    this.status = NCActionStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.orderIndex = 0,
  });

  factory NCAction.fromJson(Map<String, dynamic> json) {
    return NCAction(
      id: json['id'] as String,
      nonConformityId: json['non_conformity_id'] as String,
      actionText: json['action_text'] as String,
      responsibleEmployeeId: json['responsible_employee_id'] as String?,
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      status: NCActionStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'non_conformity_id': nonConformityId,
      'action_text': actionText,
      'responsible_employee_id': responsibleEmployeeId,
      'target_date': targetDate?.toIso8601String(),
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_index': orderIndex,
    };
  }
}

class NCVerification {
  final String id;
  final String nonConformityId;
  final String? actionVerified;
  final String? responsibleEmployeeId;
  final String? result;
  final DateTime? verificationDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderIndex;

  NCVerification({
    required this.id,
    required this.nonConformityId,
    this.actionVerified,
    this.responsibleEmployeeId,
    this.result,
    this.verificationDate,
    required this.createdAt,
    required this.updatedAt,
    this.orderIndex = 0,
  });

  factory NCVerification.fromJson(Map<String, dynamic> json) {
    return NCVerification(
      id: json['id'] as String,
      nonConformityId: json['non_conformity_id'] as String,
      actionVerified: json['action_verified'] as String?,
      responsibleEmployeeId: json['responsible_employee_id'] as String?,
      result: json['result'] as String?,
      verificationDate: json['verification_date'] != null
          ? DateTime.parse(json['verification_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'non_conformity_id': nonConformityId,
      'action_verified': actionVerified,
      'responsible_employee_id': responsibleEmployeeId,
      'result': result,
      'verification_date': verificationDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_index': orderIndex,
    };
  }
}

class NCAttachment {
  final String id;
  final String nonConformityId;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;
  final String? uploadedBy;
  final DateTime createdAt;

  NCAttachment({
    required this.id,
    required this.nonConformityId,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
    this.fileSize,
    this.uploadedBy,
    required this.createdAt,
  });

  factory NCAttachment.fromJson(Map<String, dynamic> json) {
    return NCAttachment(
      id: json['id'] as String,
      nonConformityId: json['non_conformity_id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String?,
      fileSize: json['file_size'] as int?,
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'non_conformity_id': nonConformityId,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
