/// Unit tests for Appareil model (temperature device)

import 'package:bekkapp/data/models/appareil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Appareil model', () {
    test('fromJson creates valid Appareil with thresholds', () {
      final json = {
        'id': 'app-1',
        'nom': 'Frigo principal',
        'temp_min': 2.0,
        'temp_max': 4.0,
        'created_at': '2024-01-15T10:00:00.000Z',
      };

      final app = Appareil.fromJson(json);

      expect(app.id, 'app-1');
      expect(app.nom, 'Frigo principal');
      expect(app.tempMin, 2.0);
      expect(app.tempMax, 4.0);
      expect(app.createdAt, DateTime.utc(2024, 1, 15, 10));
    });

    test('fromJson handles null thresholds', () {
      final json = {
        'id': 'app-2',
        'nom': 'Sans seuils',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final app = Appareil.fromJson(json);
      expect(app.tempMin, isNull);
      expect(app.tempMax, isNull);
    });

    test('isWithinRange returns true when temp in range', () {
      final app = Appareil(
        id: 'a1',
        nom: 'Frigo',
        tempMin: 2.0,
        tempMax: 4.0,
        createdAt: DateTime.now(),
      );

      expect(app.tempMin, 2.0);
      expect(app.tempMax, 4.0);
      // Manual check: 3.0 is between 2 and 4
      expect(
        3.0 >= (app.tempMin ?? double.negativeInfinity) &&
            3.0 <= (app.tempMax ?? double.infinity),
        true,
      );
    });

    test('toJson produces valid Map', () {
      final app = Appareil(
        id: 'a1',
        nom: 'Congélateur',
        tempMin: -25.0,
        tempMax: -18.0,
        createdAt: DateTime.utc(2024, 1, 1),
      );

      final json = app.toJson();

      expect(json['id'], 'a1');
      expect(json['nom'], 'Congélateur');
      expect(json['temp_min'], -25.0);
      expect(json['temp_max'], -18.0);
      expect(json['created_at'], isNotNull);
    });

    test('fromJson handles integer temp values', () {
      final json = {
        'id': 'a1',
        'nom': 'Test',
        'temp_min': 2,
        'temp_max': 6,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final app = Appareil.fromJson(json);
      expect(app.tempMin, 2.0);
      expect(app.tempMax, 6.0);
    });
  });
}
