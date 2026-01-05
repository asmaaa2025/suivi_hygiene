import 'package:flutter/material.dart';
import 'parametres_page.dart';

/// Settings page - redirects to existing ParametresPage
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing ParametresPage from screens
    return const ParametresPage();
  }
}
