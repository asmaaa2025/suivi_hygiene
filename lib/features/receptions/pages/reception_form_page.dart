// STUB: Replace with real implementation
// TODO: Implement product reception form
// TODO: Add form fields: fournisseur, produit, quantite, statut, remarque
// TODO: Add date picker (default to now)
// TODO: Submit to ReceptionsRepository or ApiService.createReception()
// TODO: Handle validation and error states
// TODO: Add photo/document upload for reception documents

import 'package:flutter/material.dart';

/// Form page for product reception
class ReceptionFormPage extends StatelessWidget {
  const ReceptionFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réception de produit'),
      ),
      body: const Center(
        child: Text('Formulaire de réception'),
      ),
    );
  }
}
