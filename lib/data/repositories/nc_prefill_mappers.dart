/// NC Prefill Mappers
/// Functions to map source event data to NC form prefill

import '../models/nc_models.dart';
import '../models/temperature.dart';
import '../models/reception.dart';
import '../models/oil_change.dart';
import '../models/tache_nettoyage.dart';
import '../models/appareil.dart';
import '../models/employee.dart';

/// Map temperature reading to NC prefill
Map<String, dynamic> mapTemperatureToNC({
  required Temperature releve,
  required Appareil device,
  double? tempMin,
  double? tempMax,
  Employee? employee,
}) {
  // Determine object category based on device type
  final deviceNameLower = device.nom.toLowerCase();
  NCObjectCategory objectCategory;
  if (deviceNameLower.contains('congélateur') || 
      deviceNameLower.contains('congelateur') ||
      deviceNameLower.contains('frigo') ||
      deviceNameLower.contains('réfrigérateur')) {
    objectCategory = NCObjectCategory.chaineDuFroid;
  } else if (deviceNameLower.contains('ccp') || 
             deviceNameLower.contains('prpo')) {
    objectCategory = NCObjectCategory.ccp;
  } else {
    objectCategory = NCObjectCategory.chaineDuFroid; // Default
  }

  // Build description
  final description = 'Température hors plage détectée: ${releve.temperature}°C '
      '(Plage recommandée: ${tempMin != null ? '$tempMin' : 'N/A'}°C - '
      '${tempMax != null ? '$tempMax' : 'N/A'}°C) '
      'Appareil: ${device.nom}';

  // Build source payload
  final sourcePayload = {
    'device_id': device.id,
    'device_name': device.nom,
    'temperature': releve.temperature,
    'temp_min': tempMin,
    'temp_max': tempMax,
    'reading_date': releve.createdAt.toIso8601String(),
    'employee_id': releve.createdBy,
    'photo_url': releve.photoUrl,
  };

  return {
    'object_category': objectCategory.value,
    'description': description,
    'step': 'Mesure de température',
    'sanitary_impact': 'Risque de rupture de la chaîne du froid',
    'opened_by_employee_id': releve.createdBy,
    'source_payload': sourcePayload,
  };
}

/// Map reception to NC prefill
Map<String, dynamic> mapReceptionToNC({
  required Reception reception,
  String? supplierName,
  String? productName,
  String? productId,
  Employee? employee,
  String? objectCategoryOverride, // 'reclamation_client' or 'autre'
}) {
  // Determine object category
  NCObjectCategory objectCategory;
  if (objectCategoryOverride == 'reclamation_client') {
    objectCategory = NCObjectCategory.reclamationClient;
  } else {
    objectCategory = NCObjectCategory.autre;
  }

  // Build description
  final descriptionParts = <String>[];
  if (productName != null) {
    descriptionParts.add('Produit: $productName');
  }
  if (supplierName != null) {
    descriptionParts.add('Fournisseur: $supplierName');
  }
  if (reception.lot != null) {
    descriptionParts.add('Lot: ${reception.lot}');
  }
  if (reception.temperature != null) {
    descriptionParts.add('Température: ${reception.temperature}°C');
  }
  final description = descriptionParts.join(', ');

  // Build source payload
  final sourcePayload = <String, dynamic>{
    'reception_id': reception.id,
    'product_id': productId,
    'product_name': productName,
    'supplier_name': supplierName,
    'lot': reception.lot,
    'temperature': reception.temperature,
    'dluo': reception.dluo?.toIso8601String(),
    'received_at': reception.receivedAt.toIso8601String(),
    'performed_by_employee_id': reception.performedByEmployeeId,
  };

  return {
    'object_category': objectCategory.value,
    'object_other': objectCategory == NCObjectCategory.autre 
        ? 'Réception non conforme' 
        : null,
    'product_id': productId,
    'product_name': productName,
    'description': description,
    'step': 'Réception de marchandises',
    'opened_by_employee_id': reception.performedByEmployeeId,
    'source_payload': sourcePayload,
  };
}

/// Map oil change alert to NC prefill
Map<String, dynamic> mapOilToNC({
  required String fryerId,
  required String fryerName,
  DateTime? lastChangeDate,
  int? targetIntervalDays,
  DateTime? alertDate,
  Employee? employee,
  String? objectCategoryOverride, // 'maintenance' or 'nettoyage'
}) {
  // Determine object category
  NCObjectCategory objectCategory;
  if (objectCategoryOverride == 'nettoyage') {
    objectCategory = NCObjectCategory.nettoyageDesinfection;
  } else {
    objectCategory = NCObjectCategory.maintenance;
  }

  // Build description
  final descriptionParts = <String>[
    'Friteuse: $fryerName',
  ];
  if (lastChangeDate != null) {
    descriptionParts.add('Dernier changement: ${lastChangeDate.toLocal().toString().split(' ')[0]}');
  }
  if (targetIntervalDays != null) {
    descriptionParts.add('Intervalle cible: $targetIntervalDays jours');
  }
  if (alertDate != null) {
    final daysOverdue = alertDate.difference(lastChangeDate ?? alertDate).inDays;
    if (daysOverdue > 0) {
      descriptionParts.add('En retard de $daysOverdue jour(s)');
    }
  }
  final description = descriptionParts.join(', ');

  // Build source payload
  final sourcePayload = <String, dynamic>{
    'fryer_id': fryerId,
    'fryer_name': fryerName,
    'last_change_date': lastChangeDate?.toIso8601String(),
    'target_interval_days': targetIntervalDays,
    'alert_date': alertDate?.toIso8601String(),
  };

  return {
    'object_category': objectCategory.value,
    'description': description,
    'step': 'Changement d\'huile',
    'sanitary_impact': 'Risque de dégradation de la qualité de l\'huile',
    'opened_by_employee_id': employee?.id,
    'source_payload': sourcePayload,
  };
}

/// Map cleaning task alert to NC prefill
Map<String, dynamic> mapCleaningToNC({
  required TacheNettoyage task,
  DateTime? scheduledDate,
  DateTime? missedDate,
  Employee? employee,
}) {
  // Build description
  final descriptionParts = <String>[
    'Tâche: ${task.nom}',
  ];
  if (scheduledDate != null) {
    descriptionParts.add('Date prévue: ${scheduledDate.toLocal().toString().split(' ')[0]}');
  }
  if (missedDate != null) {
    descriptionParts.add('Date manquée: ${missedDate.toLocal().toString().split(' ')[0]}');
  }
  final description = descriptionParts.join(', ');

  // Calculate frequency in days based on recurrence type
  int? frequencyDays;
  if (task.recurrenceType == 'daily') {
    frequencyDays = task.interval;
  } else if (task.recurrenceType == 'weekly') {
    frequencyDays = task.interval * 7;
  } else if (task.recurrenceType == 'monthly') {
    frequencyDays = task.interval * 30; // Approximate
  }

  // Build source payload
  final sourcePayload = <String, dynamic>{
    'task_id': task.id,
    'task_name': task.nom,
    'scheduled_date': scheduledDate?.toIso8601String(),
    'missed_date': missedDate?.toIso8601String(),
    'frequency_days': frequencyDays,
    'recurrence_type': task.recurrenceType,
    'interval': task.interval,
  };

  return {
    'object_category': NCObjectCategory.nettoyageDesinfection.value,
    'description': description,
    'step': 'Nettoyage/Désinfection',
    'sanitary_impact': 'Risque de contamination par manque de nettoyage',
    'opened_by_employee_id': employee?.id,
    'source_payload': sourcePayload,
  };
}

