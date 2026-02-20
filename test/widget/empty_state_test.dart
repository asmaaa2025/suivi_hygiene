/// Widget tests for EmptyState

import 'package:bekkapp/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Aucune donnée',
              message: 'Aucun élément à afficher',
              icon: Icons.inbox,
            ),
          ),
        ),
      );

      expect(find.text('Aucune donnée'), findsOneWidget);
      expect(find.text('Aucun élément à afficher'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Empty',
              message: 'Message',
              icon: Icons.warning,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('contains Center', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(title: 'T', message: 'M', icon: Icons.check),
          ),
        ),
      );

      expect(find.byType(Center), findsAtLeastNWidgets(1));
    });
  });
}
