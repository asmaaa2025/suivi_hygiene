import 'dart:convert';

/// HACCP action model - represents any HACCP-related action performed by a user
class HaccpAction {
  final String id;
  final String userId; // Supabase auth user ID
  final HaccpActionType type;
  final DateTime occurredAt;
  final Map<String, dynamic> payloadJson; // Flexible payload for different action types
  final DateTime createdAt;

  HaccpAction({
    required this.id,
    required this.userId,
    required this.type,
    required this.occurredAt,
    required this.payloadJson,
    required this.createdAt,
  });

  factory HaccpAction.fromJson(Map<String, dynamic> json) {
    // Handle payloadJson as string or map
    Map<String, dynamic> payload;
    if (json['payload_json'] is String) {
      try {
        payload = jsonDecode(json['payload_json'] as String)
            as Map<String, dynamic>;
      } catch (e) {
        payload = {};
      }
    } else {
      payload = (json['payload_json'] as Map<String, dynamic>?) ?? {};
    }

    return HaccpAction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: HaccpActionType.fromString(json['type'] as String? ?? ''),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      payloadJson: payload,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.toValue(),
      'occurred_at': occurredAt.toIso8601String(),
      'payload_json': jsonEncode(payloadJson),
      'created_at': createdAt.toIso8601String(),
    };
  }

  HaccpAction copyWith({
    String? id,
    String? userId,
    HaccpActionType? type,
    DateTime? occurredAt,
    Map<String, dynamic>? payloadJson,
    DateTime? createdAt,
  }) {
    return HaccpAction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// HACCP action type enum
enum HaccpActionType {
  temperature, // Temperature measurement
  reception, // Reception/Receipt
  cleaning, // Cleaning task
  correctiveAction, // Corrective action
  docUpload, // Document upload
  oilChange, // Oil change
  other, // Other actions

  temperatureEn, // English variants
  receptionEn,
  cleaningEn,
  correctiveActionEn,
  docUploadEn,
  oilChangeEn,
  otherEn;

  static HaccpActionType fromString(String? value) {
    if (value == null) return HaccpActionType.other;
    switch (value.toLowerCase()) {
      case 'temperature':
      case 'température':
        return HaccpActionType.temperature;
      case 'reception':
      case 'réception':
        return HaccpActionType.reception;
      case 'cleaning':
      case 'nettoyage':
        return HaccpActionType.cleaning;
      case 'corrective_action':
      case 'action_corrective':
        return HaccpActionType.correctiveAction;
      case 'doc_upload':
      case 'upload_document':
        return HaccpActionType.docUpload;
      case 'oil_change':
      case 'changement_huile':
        return HaccpActionType.oilChange;
      default:
        return HaccpActionType.other;
    }
  }

  String toValue() {
    switch (this) {
      case HaccpActionType.temperature:
      case HaccpActionType.temperatureEn:
        return 'temperature';
      case HaccpActionType.reception:
      case HaccpActionType.receptionEn:
        return 'reception';
      case HaccpActionType.cleaning:
      case HaccpActionType.cleaningEn:
        return 'cleaning';
      case HaccpActionType.correctiveAction:
      case HaccpActionType.correctiveActionEn:
        return 'corrective_action';
      case HaccpActionType.docUpload:
      case HaccpActionType.docUploadEn:
        return 'doc_upload';
      case HaccpActionType.oilChange:
      case HaccpActionType.oilChangeEn:
        return 'oil_change';
      case HaccpActionType.other:
      case HaccpActionType.otherEn:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case HaccpActionType.temperature:
      case HaccpActionType.temperatureEn:
        return 'Température';
      case HaccpActionType.reception:
      case HaccpActionType.receptionEn:
        return 'Réception';
      case HaccpActionType.cleaning:
      case HaccpActionType.cleaningEn:
        return 'Nettoyage';
      case HaccpActionType.correctiveAction:
      case HaccpActionType.correctiveActionEn:
        return 'Action corrective';
      case HaccpActionType.docUpload:
      case HaccpActionType.docUploadEn:
        return 'Document';
      case HaccpActionType.oilChange:
      case HaccpActionType.oilChangeEn:
        return 'Changement d\'huile';
      case HaccpActionType.other:
      case HaccpActionType.otherEn:
        return 'Autre';
    }
  }
}

