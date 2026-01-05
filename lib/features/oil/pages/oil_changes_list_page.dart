import 'package:flutter/material.dart';
import 'suivi_huile_page.dart';

/// Oil changes list page - redirects to existing SuiviHuilePage
class OilChangesListPage extends StatelessWidget {
  const OilChangesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing SuiviHuilePage from screens
    return const SuiviHuilePage();
  }
}
