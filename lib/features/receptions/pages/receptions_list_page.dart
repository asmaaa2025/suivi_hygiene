import 'package:flutter/material.dart';
import '../../../../screens/reception_page.dart';

/// Receptions list page - redirects to existing ReceptionPage
class ReceptionsListPage extends StatelessWidget {
  const ReceptionsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing ReceptionPage from screens
    return const ReceptionPage();
  }
}
