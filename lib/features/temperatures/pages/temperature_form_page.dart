// STUB: Replace with real implementation
// TODO: Implement temperature entry form
// TODO: Add form fields: appareil (dropdown), temperature (numeric), remarque (text)
// TODO: Add date/time picker (default to now)
// TODO: Add photo capture/upload capability
// TODO: Submit to TemperatureRepository or ApiService.createTemperature()
// TODO: Handle validation and error states

import 'package:flutter/material.dart';

/// Form page for temperature entry
class TemperatureFormPage extends StatelessWidget {
  const TemperatureFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relevé de température'),
      ),
      body: const Center(
        child: Text('Formulaire de température'),
      ),
    );
  }
}
