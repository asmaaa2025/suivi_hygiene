import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';

/// History page showing unified feed of all actions
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement unified feed querying temperatures, receptions, nettoyages, oil_changes
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
      ),
      body: const EmptyState(
        title: 'Aucun historique',
        message: 'Vos actions récentes apparaîtront ici',
        icon: Icons.history,
      ),
    );
  }
}
