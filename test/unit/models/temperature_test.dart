/// Unit tests for Temperature model

import 'package:bekkapp/data/models/temperature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Temperature model', () {
    test('fromJson creates valid Temperature', () {
      final json = {
        'id': 'temp-1',
        'appareil_id': 'app-1',
        'temperature': 4.5,
        'remarque': 'OK',
        'created_at': '2024-01-15T10:30:00.000Z',
      };

      final temp = Temperature.fromJson(json);

      expect(temp.id, 'temp-1');
      expect(temp.appareilId, 'app-1');
      expect(temp.temperature, 4.5);
      expect(temp.remarque, 'OK');
      expect(temp.createdAt, DateTime.utc(2024, 1, 15, 10, 30));
    });

    test('fromJson handles legacy appareil key', () {
      final json = {
        'id': 't1',
        'appareil': 'legacy-id',
        'temperature': 2.0,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final temp = Temperature.fromJson(json);
      expect(temp.appareilId, 'legacy-id');
    });

    test('fromJson defaults temperature to 0 when null', () {
      final json = {
        'id': 't1',
        'appareil_id': 'a1',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final temp = Temperature.fromJson(json);
      expect(temp.temperature, 0.0);
    });

    test('fromJson handles photo_url and photo_path', () {
      final json = {
        'id': 't1',
        'appareil_id': 'a1',
        'temperature': 3.0,
        'photo_url': 'https://example.com/photo.jpg',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final temp = Temperature.fromJson(json);
      expect(temp.photoUrl, 'https://example.com/photo.jpg');
    });

    test('toJson produces valid Map', () {
      final temp = Temperature(
        id: 't1',
        appareilId: 'a1',
        temperature: 3.5,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      final json = temp.toJson();

      expect(json['id'], 't1');
      expect(json['appareil_id'], 'a1');
      expect(json['temperature'], 3.5);
      expect(json['created_at'], isNotNull);
    });

    test('fromJson then toJson roundtrip', () {
      final original = {
        'id': 't1',
        'appareil_id': 'a1',
        'temperature': -2.5,
        'remarque': 'Surgelé',
        'created_at': '2024-01-15T12:00:00.000Z',
      };

      final temp = Temperature.fromJson(original);
      final json = temp.toJson();

      expect(json['id'], original['id']);
      expect(json['appareil_id'], original['appareil_id']);
      expect(json['temperature'], original['temperature']);
      expect(json['remarque'], original['remarque']);
    });
  });
}
