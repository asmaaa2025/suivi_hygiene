/// HACCP Documents & Compliance Models

import 'package:flutter/material.dart';

enum DocumentCategory {
  microBio,
  pestControl,
  complianceAudit,
  other;

  String get displayName {
    switch (this) {
      case DocumentCategory.microBio:
        return 'Contrôles Microbiologiques';
      case DocumentCategory.pestControl:
        return 'Dératisation / Anti-nuisibles';
      case DocumentCategory.complianceAudit:
        return 'Audits de Conformité';
      case DocumentCategory.other:
        return 'Autre';
    }
  }

  bool get isComplianceCategory =>
      this == microBio || this == pestControl || this == complianceAudit;

  IconData get icon {
    switch (this) {
      case DocumentCategory.microBio:
        return Icons.biotech;
      case DocumentCategory.pestControl:
        return Icons.pest_control;
      case DocumentCategory.complianceAudit:
        return Icons.verified;
      case DocumentCategory.other:
        return Icons.insert_drive_file;
    }
  }

  static DocumentCategory fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'microbio':
      case 'micro_bio':
        return DocumentCategory.microBio;
      case 'pestcontrol':
      case 'pest_control':
        return DocumentCategory.pestControl;
      case 'complianceaudit':
      case 'compliance_audit':
        return DocumentCategory.complianceAudit;
      default:
        return DocumentCategory.other;
    }
  }
}

class Document {
  final String id;
  final String nom;
  final String? title;
  final DocumentCategory category;
  final DateTime? documentDate;
  final String? storageUrl;
  final int? taille;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Document({
    required this.id,
    required this.nom,
    this.title,
    this.category = DocumentCategory.other,
    this.documentDate,
    this.storageUrl,
    this.taille,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  String get displayTitle => title ?? nom;

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      nom: json['nom'] as String? ?? 'Document',
      title: json['titre'] as String?,
      category: DocumentCategory.fromString(json['categorie'] as String?),
      documentDate: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
      storageUrl: json['chemin'] as String? ?? json['fichier_url'] as String?,
      taille: json['taille'] as int?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(
            json['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'titre': title,
      'categorie': category.name,
      'date': documentDate?.toIso8601String(),
      'chemin': storageUrl,
      'taille': taille,
      'notes': notes,
    };
  }
}

class ComplianceRequirement {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final int frequencyDays;
  final int graceDays;
  final bool active;

  ComplianceRequirement({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    required this.frequencyDays,
    required this.graceDays,
    this.active = true,
  });

  factory ComplianceRequirement.fromJson(Map<String, dynamic> json) {
    return ComplianceRequirement(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      frequencyDays: json['frequency_days'] as int,
      graceDays: json['grace_days'] as int,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'code': code,
      'name': name,
      'frequency_days': frequencyDays,
      'grace_days': graceDays,
      'active': active,
    };
  }
}

class ComplianceEvent {
  final String id;
  final String organizationId;
  final String requirementId;
  final DateTime eventDate;
  final String? documentId;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  ComplianceEvent({
    required this.id,
    required this.organizationId,
    required this.requirementId,
    required this.eventDate,
    this.documentId,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  factory ComplianceEvent.fromJson(Map<String, dynamic> json) {
    return ComplianceEvent(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      requirementId: json['requirement_id'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      documentId: json['document_id'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'requirement_id': requirementId,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'document_id': documentId,
      'notes': notes,
      'created_by': createdBy,
    };
  }
}

enum ComplianceStatus {
  ok,
  dueSoon,
  overdue;

  String get displayName {
    switch (this) {
      case ComplianceStatus.ok:
        return 'À jour';
      case ComplianceStatus.dueSoon:
        return 'Bientôt dû';
      case ComplianceStatus.overdue:
        return 'En retard';
    }
  }

  Color get color {
    switch (this) {
      case ComplianceStatus.ok:
        return Colors.green;
      case ComplianceStatus.dueSoon:
        return Colors.orange;
      case ComplianceStatus.overdue:
        return Colors.red;
    }
  }
}

class ComplianceStatusInfo {
  final ComplianceRequirement requirement;
  final DateTime? lastEventDate;
  final DateTime? nextDueDate;
  final ComplianceStatus status;
  final int? daysUntilDue;
  final int? daysOverdue;

  ComplianceStatusInfo({
    required this.requirement,
    this.lastEventDate,
    this.nextDueDate,
    required this.status,
    this.daysUntilDue,
    this.daysOverdue,
  });
}
