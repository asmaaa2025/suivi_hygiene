import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_module_tile.dart';
import '../../../shared/utils/navigation_helpers.dart';

/// RH Hub - 2 tiles for Personnel and Clock History
class RhHubPage extends StatelessWidget {
  const RhHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHome(context),
          tooltip: 'Retour',
        ),
        title: const Text('RH'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gestion RH',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    AppModuleTile(
                      icon: Icons.access_time,
                      title: 'Pointage',
                      subtitle: 'Pointer entrée / sortie',
                      onTap: () => context.go('/admin/clock'),
                      color: Colors.green,
                    ),
                    AppModuleTile(
                      icon: Icons.history,
                      title: 'Historique Pointage',
                      subtitle: 'Historique des pointages',
                      onTap: () => context.go('/admin/clock-history'),
                      color: Colors.orange,
                    ),
                    AppModuleTile(
                      icon: Icons.people,
                      title: 'Relevé employés',
                      subtitle: 'Registre du personnel',
                      onTap: () => context.go('/admin/rh'),
                      color: AppTheme.primaryBlue,
                    ),
                    AppModuleTile(
                      icon: Icons.tablet_android,
                      title: 'Comptes tablette',
                      subtitle: 'Comptes utilisateurs de l\'app',
                      onTap: () => context.go('/admin/employees'),
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
