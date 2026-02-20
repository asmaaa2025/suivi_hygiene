import 'package:flutter/services.dart';
import '../services/text_sanitizer_service.dart';

/// TextInputFormatter pour nettoyer automatiquement les caractères problématiques
class ZplSafeTextInputFormatter extends TextInputFormatter {
  final TextSanitizerService _sanitizer = TextSanitizerService();
  final bool showWarnings;

  ZplSafeTextInputFormatter({this.showWarnings = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Nettoyer le texte pour l'affichage
    final cleanedText = _sanitizer.sanitizeForInput(newValue.text);

    // Si le texte a été modifié, ajuster la position du curseur
    if (cleanedText != newValue.text) {
      final selection = TextSelection.collapsed(offset: cleanedText.length);
      return TextEditingValue(text: cleanedText, selection: selection);
    }

    return newValue;
  }
}

/// TextInputFormatter pour les noms de produits avec validation stricte
class ProductNameInputFormatter extends TextInputFormatter {
  final TextSanitizerService _sanitizer = TextSanitizerService();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Supprimer les caractères de contrôle et les caractères ZPL problématiques
    String cleanedText = newValue.text;

    // Supprimer les caractères de contrôle
    cleanedText = cleanedText.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Supprimer les caractères ZPL problématiques
    cleanedText = cleanedText.replaceAll(RegExp(r'[\^~`]'), '');

    // Limiter la longueur
    if (cleanedText.length > 100) {
      cleanedText = cleanedText.substring(0, 100);
    }

    // Ajuster la position du curseur
    final selection = TextSelection.collapsed(offset: cleanedText.length);
    return TextEditingValue(text: cleanedText, selection: selection);
  }
}

/// TextInputFormatter pour les descriptions avec nettoyage intelligent
class DescriptionInputFormatter extends TextInputFormatter {
  final TextSanitizerService _sanitizer = TextSanitizerService();
  final int maxLength;

  DescriptionInputFormatter({this.maxLength = 500});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Nettoyer le texte pour l'affichage
    String cleanedText = _sanitizer.sanitizeForInput(newValue.text);

    // Limiter la longueur
    if (cleanedText.length > maxLength) {
      cleanedText = cleanedText.substring(0, maxLength);
    }

    // Ajuster la position du curseur
    final selection = TextSelection.collapsed(offset: cleanedText.length);
    return TextEditingValue(text: cleanedText, selection: selection);
  }
}

/// TextInputFormatter pour les numéros de lot
class LotNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Permettre seulement les lettres, chiffres et tirets
    String cleanedText = newValue.text.replaceAll(
      RegExp(r'[^a-zA-Z0-9\-_]'),
      '',
    );

    // Limiter la longueur
    if (cleanedText.length > 20) {
      cleanedText = cleanedText.substring(0, 20);
    }

    // Convertir en majuscules
    cleanedText = cleanedText.toUpperCase();

    // Ajuster la position du curseur
    final selection = TextSelection.collapsed(offset: cleanedText.length);
    return TextEditingValue(text: cleanedText, selection: selection);
  }
}

/// TextInputFormatter pour les poids (nombres décimaux)
class WeightInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Permettre seulement les chiffres et le point décimal
    String cleanedText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');

    // S'assurer qu'il n'y a qu'un seul point décimal
    final parts = cleanedText.split('.');
    if (parts.length > 2) {
      cleanedText = '${parts[0]}.${parts[1]}';
    }

    // Limiter à 2 décimales
    if (parts.length == 2 && parts[1].length > 2) {
      cleanedText = '${parts[0]}.${parts[1].substring(0, 2)}';
    }

    // Limiter la longueur totale
    if (cleanedText.length > 10) {
      cleanedText = cleanedText.substring(0, 10);
    }

    // Ajuster la position du curseur
    final selection = TextSelection.collapsed(offset: cleanedText.length);
    return TextEditingValue(text: cleanedText, selection: selection);
  }
}

/// TextInputFormatter pour les nombres entiers
class IntegerInputFormatter extends TextInputFormatter {
  final int? maxValue;

  IntegerInputFormatter({this.maxValue});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Permettre seulement les chiffres
    String cleanedText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Vérifier la valeur maximale
    if (maxValue != null && cleanedText.isNotEmpty) {
      final value = int.tryParse(cleanedText);
      if (value != null && value > maxValue!) {
        cleanedText = maxValue.toString();
      }
    }

    // Ajuster la position du curseur
    final selection = TextSelection.collapsed(offset: cleanedText.length);
    return TextEditingValue(text: cleanedText, selection: selection);
  }
}
