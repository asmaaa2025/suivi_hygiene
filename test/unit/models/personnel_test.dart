/// Unit tests for Personnel model

import 'package:bekkapp/data/models/personnel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Personnel model', () {
    test('fromJson creates valid Personnel', () {
      final json = {
        'id': 'p1',
        'first_name': 'Jean',
        'last_name': 'Dupont',
        'start_date': '2024-01-01',
        'contract_type': 'CDI',
        'is_foreign_worker': false,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final p = Personnel.fromJson(json);

      expect(p.id, 'p1');
      expect(p.firstName, 'Jean');
      expect(p.lastName, 'Dupont');
      expect(p.contractType, ContractType.cdi);
      expect(p.isForeignWorker, false);
    });

    test('isActive returns true when endDate is null', () {
      final p = Personnel(
        id: 'p1',
        firstName: 'A',
        lastName: 'B',
        startDate: DateTime.now().subtract(const Duration(days: 100)),
        contractType: ContractType.cdi,
        createdAt: DateTime.now(),
      );
      expect(p.isActive, true);
    });

    test('isActive returns false when endDate passed', () {
      final p = Personnel(
        id: 'p1',
        firstName: 'A',
        lastName: 'B',
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2023, 12, 31),
        contractType: ContractType.cdi,
        createdAt: DateTime.now(),
      );
      expect(p.isActive, false);
    });

    test('ContractType.fromString handles CDI CDD', () {
      expect(ContractType.fromString('CDI'), ContractType.cdi);
      expect(ContractType.fromString('CDD'), ContractType.cdd);
      expect(ContractType.fromString('Alternance'), ContractType.alternance);
      expect(ContractType.fromString(null), ContractType.cdi);
    });
  });
}
