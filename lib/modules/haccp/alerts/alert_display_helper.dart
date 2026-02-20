/// Helper pour un affichage simplifié des alertes (user-friendly)
/// Réduit 18+ types techniques à 5 catégories et 2 niveaux de priorité

import 'models.dart';

/// Catégorie simplifiée pour l'affichage (5 au lieu de codes techniques)
enum AlertCategory {
  temperature,
  reception,
  huile,
  nettoyage,
  documents;

  String get label {
    switch (this) {
      case AlertCategory.temperature: return 'Température';
      case AlertCategory.reception: return 'Réception';
      case AlertCategory.huile: return 'Huile';
      case AlertCategory.nettoyage: return 'Nettoyage';
      case AlertCategory.documents: return 'Documents';
    }
  }

  String get shortLabel {
    switch (this) {
      case AlertCategory.temperature: return 'Temp.';
      case AlertCategory.reception: return 'Récept.';
      case AlertCategory.huile: return 'Huile';
      case AlertCategory.nettoyage: return 'Nettoy.';
      case AlertCategory.documents: return 'Docs';
    }
  }
}

/// Priorité simplifiée : 2 niveaux au lieu de 3 (INFO, WARN, CRITICAL)
enum AlertPriority {
  urgent,   // Critique, bloquant
  attention; // Info ou avertissement

  String get label {
    switch (this) {
      case AlertPriority.urgent: return 'Urgent';
      case AlertPriority.attention: return 'Attention';
    }
  }
}

class AlertDisplayHelper {
  /// Retourne la catégorie d'affichage à partir du module
  static AlertCategory getCategory(Alert alert) {
    switch (alert.module.toLowerCase()) {
      case 'temperature': return AlertCategory.temperature;
      case 'reception': return AlertCategory.reception;
      case 'oil': return AlertCategory.huile;
      case 'cleaning': return AlertCategory.nettoyage;
      case 'documents': return AlertCategory.documents;
      default: return AlertCategory.temperature;
    }
  }

  /// Priorité simplifiée : urgent = critique, attention = le reste
  static AlertPriority getPriority(Alert alert) {
    if (alert.severity == AlertSeverity.critical || alert.blocking) {
      return AlertPriority.urgent;
    }
    return AlertPriority.attention;
  }

  /// Titre court et lisible (évite les codes techniques)
  static String getShortTitle(Alert alert) {
    final code = alert.alertCode.toUpperCase();
    if (code.startsWith('TEMP.')) {
      if (code.contains('CRITICAL') || code.contains('CONSECUTIVE')) return 'Température critique';
      if (code.contains('NO_DEVICE')) return 'Appareil non sélectionné';
      if (code.contains('THRESHOLD')) return 'Seuils manquants';
      return 'Température à surveiller';
    }
    if (code.startsWith('RECEPT.')) {
      if (code.contains('CRITICAL') || code.contains('SEAL') || code.contains('TEMP_')) return 'Réception non conforme';
      if (code.contains('WET') || code.contains('PACKAGING')) return 'Problème emballage';
      return 'Étiquette incomplète';
    }
    if (code.startsWith('OIL.')) {
      if (code.contains('CRITICAL') || code.contains('QUALITY')) return 'Huile à changer immédiatement';
      return 'Huile à changer';
    }
    if (code.startsWith('CLEAN.')) {
      if (code.contains('MULTIPLE') || code.contains('CRITICAL')) return 'Nettoyages manqués';
      return 'Nettoyage à faire';
    }
    if (code.startsWith('DOCS.')) {
      if (code.contains('OVERDUE')) return 'Document en retard';
      return 'Document à prévoir';
    }
    return alert.title;
  }
}
