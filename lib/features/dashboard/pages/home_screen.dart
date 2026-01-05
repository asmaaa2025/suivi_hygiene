import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temp Contrôle Boucherie'),
      ),
      body: const Center(
        child: Text('Bienvenue sur l\'écran d\'accueil'),
      ),
    );
  }
}
