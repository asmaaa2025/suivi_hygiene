/// Alerts Home Screen
///
/// Page dédiée Alertes - 4 actions principales en tuiles (user-friendly)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_module_tile.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../services/haccp_export_service.dart';

class AlertsHomeScreen extends StatefulWidget {
  const AlertsHomeScreen({super.key});

  @override
  State<AlertsHomeScreen> createState() => _AlertsHomeScreenState();
}

class _AlertsHomeScreenState extends State<AlertsHomeScreen> {
  final _exportService = HaccpExportService();
  bool _isExporting = false;

  Future<void> _exportNc() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportToPdf(
        modules: [HaccpExportService.kNc, HaccpExportService.kRappels],
      );
      if (!mounted) return;
      await _exportService.shareExport(path, isPdf: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export créé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final prefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
          tooltip: 'Retour',
        ),
        title: const Text('Alertes'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Exporter NC et rappels',
            onPressed: _isExporting ? null : _exportNc,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Que souhaitez-vous faire ?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez une action ci-dessous',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    AppModuleTile(
                      icon: Icons.notifications_active,
                      title: 'Voir les alertes',
                      subtitle: 'Alertes HACCP en cours',
                      onTap: () => context.go('$prefix/alerts/list'),
                      color: Colors.red.shade300,
                    ),
                    AppModuleTile(
                      icon: Icons.edit_note,
                      title: 'Créer une NC',
                      subtitle: 'Déclarer une non-conformité',
                      onTap: () => context.go('$prefix/alerts/nc/new'),
                      color: AppTheme.primaryBlue,
                    ),
                    AppModuleTile(
                      icon: Icons.history,
                      title: 'Historique NC',
                      subtitle: 'Consulter les fiches passées',
                      onTap: () => context.go('$prefix/alerts/nc/history'),
                      color: Colors.orange.shade300,
                    ),
                    AppModuleTile(
                      icon: Icons.warning_amber,
                      title: 'Plan de rappel',
                      subtitle: 'Gestion crise sanitaire',
                      onTap: () => context.go('$prefix/plan-rappel'),
                      color: Colors.amber.shade700,
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
