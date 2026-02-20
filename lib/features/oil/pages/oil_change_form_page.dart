// STUB: Replace with real implementation
// TODO: Implement oil change entry form
// TODO: Add form fields: friteuse (dropdown), quantite (numeric), type_huile, responsable, remarque
// TODO: Add date/time picker (default to now)
// TODO: Add photo upload capability
// TODO: Submit to OilChangeRepository.createOilChange()
// TODO: Handle validation and error states

import 'package:flutter/material.dart';

/// Form page for oil change entry
class OilChangeFormPage extends StatelessWidget {
  const OilChangeFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changement d\'huile')),
      body: const Center(child: Text('Formulaire de changement d\'huile')),
    );
  }
}
