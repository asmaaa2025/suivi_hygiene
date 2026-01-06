import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';

/// Quick entry page with action buttons
class EntryPage extends StatelessWidget {
  const EntryPage({super.key});

  String _getRoutePrefix(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return location.startsWith('/admin') ? '/admin' : '/app';
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(context).matchedLocation.startsWith('/admin');
    final routePrefix = _getRoutePrefix(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie rapide'),
        leading: isAdminRoute
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/home'),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            onTap: () => context.push('$routePrefix/temperatures/new'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusInfo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.thermostat,
                      color: AppTheme.statusInfo, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajouter une température',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enregistrer une mesure de température',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
          SectionCard(
            onTap: () => context.push('$routePrefix/receptions/new'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory_2,
                      color: AppTheme.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nouvelle réception',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enregistrer une réception de produit',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
          SectionCard(
            onTap: () => context.push('$routePrefix/cleaning'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusOk.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.cleaning_services,
                      color: AppTheme.statusOk, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marquer un nettoyage',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Valider une tâche de nettoyage',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
          SectionCard(
            onTap: () => context.push('$routePrefix/oil'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusWarn.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.oil_barrel,
                      color: AppTheme.statusWarn, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Changement d\'huile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enregistrer un changement d\'huile',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
