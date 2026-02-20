import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/module_cube_with_menu.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../shared/utils/module_action_menu.dart';
import '../../../services/haccp_export_service.dart';

/// HACCP Hub - 8 tiles for all HACCP modules
class HaccpHubPage extends StatefulWidget {
  const HaccpHubPage({super.key});

  @override
  State<HaccpHubPage> createState() => _HaccpHubPageState();
}

class _HaccpHubPageState extends State<HaccpHubPage> {
  final _exportService = HaccpExportService();
  bool _isExporting = false;

  Future<void> _exportModule(BuildContext context, List<String>? modules) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      // PDF = format officiel pour contrôle (non modifiable)
      final filePath = await _exportService.exportToPdf(modules: modules);
      if (!context.mounted) return;
      await _exportService.shareExport(filePath, isPdf: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registre PDF créé. Utilisez Partager pour l\'envoyer (format contrôle officiel).'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[HaccpHub] Export error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(context).matchedLocation.startsWith('/admin');
    final prefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHome(context),
          tooltip: 'Retour',
        ),
        title: const Text('HACCP'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Modules HACCP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: GridView.count(
                    crossAxisCount: 4, // 4 columns for 2 rows
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4, // Increased to make cubes less tall (wider relative to height)
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                    // Temperature cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.thermostat,
                      title: 'Températures',
                      subtitle: 'Relevés de température',
                      color: AppTheme.statusInfo,
                      menuTitle: 'Températures',
                      actions: [
                        ModuleAction(
                          label: 'Nouvelle valeur',
                          icon: Icons.add,
                          onTap: () => context.go('$prefix/temperatures/new'),
                        ),
                        ModuleAction(
                          label: 'Historique',
                          icon: Icons.history,
                          onTap: () => context.go('$prefix/temperatures-history'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, [HaccpExportService.kTemperatures]),
                        ),
                      ],
                    ),
                    // Réceptions cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.inventory_2,
                      title: 'Réceptions',
                      subtitle: 'Réception de marchandises',
                      color: AppTheme.primaryBlue,
                      menuTitle: 'Réceptions',
                      actions: [
                        ModuleAction(
                          label: 'Nouvelle réception',
                          icon: Icons.add,
                          onTap: () => context.go('$prefix/receptions/new'),
                        ),
                        ModuleAction(
                          label: 'Historique',
                          icon: Icons.history,
                          onTap: () => context.go('$prefix/receptions-history'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, [HaccpExportService.kReceptions]),
                        ),
                      ],
                    ),
                    // Nettoyage cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.cleaning_services,
                      title: 'Nettoyage',
                      subtitle: 'Tâches de nettoyage',
                      color: AppTheme.statusOk,
                      menuTitle: 'Nettoyage',
                      actions: [
                        ModuleAction(
                          label: 'Nouvelle tâche',
                          icon: Icons.add,
                          onTap: () => context.go('$prefix/cleaning/taches/new'),
                        ),
                        ModuleAction(
                          label: 'Historique',
                          icon: Icons.history,
                          onTap: () => context.go('$prefix/cleaning-history'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, [HaccpExportService.kCleaning]),
                        ),
                      ],
                    ),
                    // Huile cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.oil_barrel,
                      title: 'Huile',
                      subtitle: 'Changements d\'huile',
                      color: AppTheme.statusWarn,
                      menuTitle: 'Huile',
                      actions: [
                        ModuleAction(
                          label: 'Suivi huile',
                          icon: Icons.oil_barrel,
                          onTap: () => context.go('$prefix/oil'),
                        ),
                        ModuleAction(
                          label: 'Historique',
                          icon: Icons.history,
                          onTap: () => context.go('$prefix/oil-history'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, [HaccpExportService.kOil]),
                        ),
                      ],
                    ),
                    // Fournisseurs cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.local_shipping,
                      title: 'Fournisseurs',
                      subtitle: 'Gérer les fournisseurs',
                      color: Colors.blue.shade300,
                      menuTitle: 'Fournisseurs',
                      actions: [
                        ModuleAction(
                          label: 'Nouveau fournisseur',
                          icon: Icons.add,
                          onTap: () => context.go('/suppliers/new'),
                        ),
                        ModuleAction(
                          label: 'Liste',
                          icon: Icons.list,
                          onTap: () => context.go('/suppliers'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, null),
                        ),
                      ],
                    ),
                    // Produits cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.shopping_basket,
                      title: 'Produits',
                      subtitle: 'Gérer les produits',
                      color: Colors.green.shade300,
                      menuTitle: 'Produits',
                      actions: [
                        ModuleAction(
                          label: 'Nouveau produit',
                          icon: Icons.add,
                          onTap: () => context.go('/products/new'),
                        ),
                        ModuleAction(
                          label: 'Liste',
                          icon: Icons.list,
                          onTap: () => context.go('/products'),
                        ),
                        ModuleAction(
                          label: 'Étiquettes',
                          icon: Icons.label,
                          onTap: () => context.go('/labels'),
                        ),
                        ModuleAction(
                          label: 'Tableau allergènes',
                          icon: Icons.no_food,
                          onTap: () => context.go('$prefix/tableau-allergenes'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, null),
                        ),
                      ],
                    ),
                    // Alertes cube
                    ModuleCubeWithMenu(
                      icon: Icons.notifications_active,
                      title: 'Alertes',
                      subtitle: 'Alertes HACCP',
                      color: Colors.red.shade300,
                      menuTitle: 'Alertes',
                      actions: [
                        ModuleAction(
                          label: 'Voir alertes',
                          icon: Icons.notifications_active,
                          onTap: () => context.go('$prefix/alerts/list'),
                        ),
                        ModuleAction(
                          label: 'Formulaire NC',
                          icon: Icons.assignment,
                          onTap: () => context.go('$prefix/alerts/nc/wizard'),
                        ),
                        ModuleAction(
                          label: 'Historique NC',
                          icon: Icons.history,
                          onTap: () => context.go('$prefix/alerts/nc/history'),
                        ),
                        ModuleAction(
                          label: 'Plan de rappel',
                          icon: Icons.warning,
                          onTap: () => context.go('$prefix/plan-rappel'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, [HaccpExportService.kNc]),
                        ),
                      ],
                    ),
                    // Documents cube with context menu
                    ModuleCubeWithMenu(
                      icon: Icons.folder,
                      title: 'Documents',
                      subtitle: 'Conformité HACCP',
                      color: Colors.purple.shade300,
                      menuTitle: 'Documents',
                      actions: [
                          ModuleAction(
                            label: 'Ajouter un document',
                            icon: Icons.upload,
                            onTap: () => context.go('$prefix/documents/upload'),
                          ),
                        ModuleAction(
                          label: 'Voir documents',
                          icon: Icons.folder_open,
                          onTap: () => context.go('$prefix/documents'),
                        ),
                        ModuleAction(
                          label: 'Exporter',
                          icon: Icons.download,
                          onTap: () => _exportModule(context, null),
                        ),
                        ModuleAction(
                          label: 'Classeur hebdomadaire',
                          icon: Icons.calendar_month,
                          onTap: () => context.go('$prefix/synthese-hebdomadaire'),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

