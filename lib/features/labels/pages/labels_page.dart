import 'package:flutter/material.dart';
import 'etiquette_page.dart';

/// Labels page - redirects to existing EtiquettePage
class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing EtiquettePage from screens
    return const EtiquettePage();
  }
}
