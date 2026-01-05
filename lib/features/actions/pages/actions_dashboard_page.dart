import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';

/// Actions Dashboard - Landing page with quick actions
/// Users land here first (not history)
class ActionsDashboardPage extends StatelessWidget {
  const ActionsDashboardPage({super.key});

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Text(
              'Actions rapides',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            _buildActionButton(
              context,
              icon: Icons.inventory_2,
              label: 'Réception de marchandise',
              description: 'Enregistrer une réception',
              color: AppTheme.primaryBlue,
              onTap: () {
                Navigator.pop(context);
                context.push('/receptions/new');
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.thermostat,
              label: 'Température',
              description: 'Enregistrer une mesure',
              color: AppTheme.statusInfo,
              onTap: () {
                Navigator.pop(context);
                context.push('/temperatures/new');
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.cleaning_services,
              label: 'Nettoyage',
              description: 'Marquer une tâche comme faite',
              color: AppTheme.statusOk,
              onTap: () {
                Navigator.pop(context);
                context.push('/cleaning');
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.oil_barrel,
              label: 'Changement d\'huile',
              description: 'Enregistrer un changement',
              color: AppTheme.statusWarn,
              onTap: () {
                Navigator.pop(context);
                context.push('/oil-changes/new');
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.print,
              label: 'Imprimer une étiquette',
              description: 'Générer une étiquette',
              color: AppTheme.textSecondary,
              onTap: () {
                Navigator.pop(context);
                context.push('/labels');
              },
              enabled: false, // Future feature
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!enabled)
                Text(
                  'Bientôt',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                )
              else
                Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Welcome section
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez une action rapide ci-dessous ou utilisez le bouton + pour plus d\'options',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions grid
          Text(
            'Actions rapides',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildQuickActionCard(
                context,
                icon: Icons.inventory_2,
                label: 'Réception',
                color: AppTheme.primaryBlue,
                onTap: () => context.push('/receptions/new'),
              ),
              _buildQuickActionCard(
                context,
                icon: Icons.thermostat,
                label: 'Température',
                color: AppTheme.statusInfo,
                onTap: () => context.push('/temperatures/new'),
              ),
              _buildQuickActionCard(
                context,
                icon: Icons.cleaning_services,
                label: 'Nettoyage',
                color: AppTheme.statusOk,
                onTap: () => context.push('/cleaning'),
              ),
              _buildQuickActionCard(
                context,
                icon: Icons.oil_barrel,
                label: 'Huile',
                color: AppTheme.statusWarn,
                onTap: () => context.push('/oil-changes/new'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent activity section (optional, can link to history)
          SectionCard(
            onTap: () => context.push('/history'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundNeutral,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historique',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Voir toutes les opérations',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showActionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Action'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SectionCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}



