import 'package:flutter/material.dart';
import 'reception_form_page.dart';

/// Receptions list page - Shows the enhanced reception form directly
class ReceptionsListPage extends StatelessWidget {
  const ReceptionsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Show the enhanced reception form directly
    // This includes: fixed 10:00 time, supplier/product selection, 
    // non-conformity checks, photo upload, and quick-add supplier
    return const ReceptionFormPage();
  }
}
