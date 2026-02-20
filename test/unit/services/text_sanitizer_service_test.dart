/// Unit tests for TextSanitizerService - ZPL and display sanitization

import 'package:bekkapp/services/text_sanitizer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextSanitizerService sanitizer;

  setUp(() {
    sanitizer = TextSanitizerService();
  });

  group('TextSanitizerService - sanitizeForZpl', () {
    test('returns empty string for empty input', () {
      expect(sanitizer.sanitizeForZpl(''), '');
    });

    test('replaces French accents', () {
      expect(sanitizer.sanitizeForZpl('Café'), 'Cafe');
      expect(sanitizer.sanitizeForZpl('Éléphant'), 'Elephant');
      expect(sanitizer.sanitizeForZpl('àâäéèêë'), 'aaaeeee');
      expect(sanitizer.sanitizeForZpl('Çç'), 'Cc');
    });

    test('replaces ZPL special characters', () {
      expect(sanitizer.sanitizeForZpl('a^b'), contains(' '));
      expect(sanitizer.sanitizeForZpl('x~y'), contains(' '));
      expect(sanitizer.sanitizeForZpl('°C'), contains('deg'));
    });

    test('removes control characters', () {
      final withControl = 'Hello\x00\x01World';
      expect(sanitizer.sanitizeForZpl(withControl), isNot(contains('\x00')));
    });

    test('normalizes whitespace', () {
      expect(
        sanitizer.sanitizeForZpl('  multiple   spaces  ').trim(),
        isNot(contains('  ')),
      );
    });

    test('handles mixed content', () {
      final result = sanitizer.sanitizeForZpl('Crème brûlée 2°C');
      expect(result, isNot(contains('û')));
      expect(result, isNot(contains('è')));
      expect(result, isNot(contains('°')));
    });
  });

  group('TextSanitizerService - sanitizeForDisplay', () {
    test('returns empty string for empty input', () {
      expect(sanitizer.sanitizeForDisplay(''), '');
    });

    test('keeps French accents for display', () {
      expect(sanitizer.sanitizeForDisplay('Café'), 'Café');
      expect(sanitizer.sanitizeForDisplay('Éléphant'), 'Éléphant');
    });

    test('removes control characters', () {
      expect(
        sanitizer.sanitizeForDisplay('Hi\x00There'),
        isNot(contains('\x00')),
      );
    });

    test('normalizes multiple spaces', () {
      expect(sanitizer.sanitizeForDisplay('a    b'), 'a b');
    });
  });

  group('TextSanitizerService - sanitizeForInput', () {
    test('returns empty string for empty input', () {
      expect(sanitizer.sanitizeForInput(''), '');
    });

    test('removes control characters from input', () {
      expect(
        sanitizer.sanitizeForInput('text\x07\x1F'),
        isNot(contains('\x07')),
      );
    });
  });

  group('TextSanitizerService - hasZplProblematicCharacters', () {
    test('returns false for clean text', () {
      expect(sanitizer.hasZplProblematicCharacters('Hello'), false);
      expect(sanitizer.hasZplProblematicCharacters('Café'), false);
    });

    test('returns true for ^ ~ `', () {
      expect(sanitizer.hasZplProblematicCharacters('a^b'), true);
      expect(sanitizer.hasZplProblematicCharacters('x~y'), true);
      expect(sanitizer.hasZplProblematicCharacters('a`b'), true);
    });

    test('returns true for control characters', () {
      expect(sanitizer.hasZplProblematicCharacters('a\x00b'), true);
    });
  });

  group('TextSanitizerService - getProblematicCharacters', () {
    test('returns empty list for clean text', () {
      expect(sanitizer.getProblematicCharacters('Hello'), isEmpty);
    });

    test('returns list of problematic chars', () {
      final chars = sanitizer.getProblematicCharacters('a^b~c');
      expect(chars, contains('^'));
      expect(chars, contains('~'));
    });
  });

  group('TextSanitizerService - getHelpMessage', () {
    test('returns empty string when no problematic chars', () {
      expect(sanitizer.getHelpMessage('Clean'), '');
    });

    test('returns help message when problematic chars exist', () {
      final msg = sanitizer.getHelpMessage('a^b');
      expect(msg, contains('Caractères problématiques'));
      expect(msg, contains('^'));
    });
  });
}
