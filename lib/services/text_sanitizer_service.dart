import 'package:characters/characters.dart';

/// Service dédié à la normalisation et au nettoyage des textes
/// selon les meilleures pratiques Flutter pour la gestion Unicode
class TextSanitizerService {
  static TextSanitizerService? _instance;
  factory TextSanitizerService() {
    _instance ??= TextSanitizerService._internal();
    return _instance!;
  }
  TextSanitizerService._internal();

  /// Normalise et nettoie le texte pour l'impression ZPL
  /// Utilise des remplacements spécifiques pour les caractères français
  String sanitizeForZpl(String input) {
    if (input.isEmpty) return '';

    // Étape 1: Remplacer les caractères accentués français
    String result = _replaceFrenchAccents(input);

    // Étape 2: Remplacer les caractères spéciaux spécifiques à ZPL
    result = _replaceZplSpecialCharacters(result);

    // Étape 3: Nettoyer les caractères de contrôle et espaces
    result = _cleanControlCharacters(result);

    return result.trim();
  }

  /// Normalise le texte pour l'affichage dans l'UI
  /// Garde les accents mais nettoie les caractères de contrôle
  String sanitizeForDisplay(String input) {
    if (input.isEmpty) return '';

    // Supprimer seulement les caractères de contrôle dangereux
    String cleaned = input.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    // Normaliser les espaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Valide et nettoie le texte en temps réel pour les champs de saisie
  String sanitizeForInput(String input) {
    if (input.isEmpty) return '';

    // Supprimer les caractères de contrôle dangereux
    String cleaned = input.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    return cleaned;
  }

  /// Remplace les caractères accentués français
  String _replaceFrenchAccents(String input) {
    final accentReplacements = {
      // Voyelles minuscules avec accents
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ę': 'e', 'ė': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ų': 'u',
      'ý': 'y', 'ÿ': 'y',

      // Voyelles majuscules avec accents
      'À': 'A', 'Â': 'A', 'Ä': 'A', 'Á': 'A', 'Ã': 'A', 'Å': 'A',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E', 'Ę': 'E', 'Ė': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Ö': 'O', 'Õ': 'O', 'Ø': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U', 'Ų': 'U',
      'Ý': 'Y', 'Ÿ': 'Y',

      // Consonnes avec accents
      'ç': 'c', 'ć': 'c', 'č': 'c',
      'Ç': 'C', 'Ć': 'C', 'Č': 'C',
      'ñ': 'n', 'ń': 'n', 'ň': 'n',
      'Ñ': 'N', 'Ń': 'N', 'Ň': 'N',
      'ś': 's', 'š': 's', 'ş': 's',
      'Ś': 'S', 'Š': 'S', 'Ş': 'S',
      'ź': 'z', 'ż': 'z', 'ž': 'z',
      'Ź': 'Z', 'Ż': 'Z', 'Ž': 'Z',

      // Ligatures
      'œ': 'oe', 'æ': 'ae',
      'Œ': 'OE', 'Æ': 'AE',

      // Caractères spéciaux français
      'ÿ': 'y', 'Ÿ': 'Y',
    };

    String result = input;
    accentReplacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    return result;
  }

  /// Remplace les caractères spéciaux problématiques pour ZPL
  String _replaceZplSpecialCharacters(String input) {
    final replacements = {
      // Caractères de contrôle ZPL à éviter
      '^': ' ', '~': ' ', '`': ' ',

      // Symboles courants
      '°': 'deg', '®': 'R', '™': 'TM', '©': 'C',
      '€': 'EUR', '\$': 'USD', '£': 'GBP',
      '&': 'et', '<': '(', '>': ')', '"': '"', "'": "'",
      '–': '-', '—': '-', '…': '...',
      '×': 'x', '÷': '/', '±': '+/-',

      // Caractères d'espacement problématiques
      '\t': ' ', '\n': ' ', '\r': ' ',

      // Caractères spéciaux supplémentaires
      '°C': 'degres', '°F': 'degres F', '°K': 'degres K',
      'ºC': 'degres', 'ºF': 'degres F',
      '°': 'deg',
    };

    String result = input;
    replacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    return result;
  }

  /// Nettoie les caractères de contrôle et normalise les espaces
  String _cleanControlCharacters(String input) {
    // Supprimer les caractères non imprimables (sauf espaces)
    String cleaned = input.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '');

    // Remplacer les espaces multiples par un seul espace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned;
  }

  /// Vérifie si le texte contient des caractères problématiques pour ZPL
  bool hasZplProblematicCharacters(String input) {
    return input.contains(RegExp(r'[\^~`\x00-\x1F\x7F]'));
  }

  /// Obtient la liste des caractères problématiques dans le texte
  List<String> getProblematicCharacters(String input) {
    final problematic = <String>[];
    final characters = input.characters;

    for (final char in characters) {
      if (char.contains(RegExp(r'[\^~`\x00-\x1F\x7F]'))) {
        problematic.add(char);
      }
    }

    return problematic.toSet().toList(); // Supprimer les doublons
  }

  /// Génère un message d'aide pour les caractères problématiques
  String getHelpMessage(String input) {
    final problematic = getProblematicCharacters(input);
    if (problematic.isEmpty) return '';

    return 'Caractères problématiques détectés: ${problematic.join(', ')}. '
        'Ils seront automatiquement corrigés.';
  }
}
