/// NC Wizard Success Screen
/// 
/// Shows success message after NC submission
/// Buttons: Voir la fiche, Exporter PDF, Historique

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bekkapp/core/theme/app_theme.dart';
import 'package:bekkapp/data/repositories/nc_repository.dart';
import 'package:bekkapp/services/nc_pdf_export_service.dart';
import '../widgets/wizard_input_widgets.dart';

void _navigateToHistory(BuildContext context) {
  // Navigation différée pour éviter crash (conflit Navigator.push + GoRouter)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final location = GoRouterState.of(context).matchedLocation;
    final prefix = location.startsWith('/admin') ? '/admin' : '/app';
    GoRouter.of(context).go('$prefix/alerts/nc/history');
  });
}

void _navigateToAlerts(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final location = GoRouterState.of(context).matchedLocation;
    final prefix = location.startsWith('/admin') ? '/admin' : '/app';
    GoRouter.of(context).go('$prefix/alerts');
  });
}

class NcWizardSuccess extends StatelessWidget {
  final String? ncId;

  const NcWizardSuccess({
    super.key,
    this.ncId,
  });

  Future<void> _exportPdf(BuildContext context) async {
    if (ncId == null) return;
    try {
      final nc = await NCRepository().getById(ncId!, includeRelated: true);
      if (nc == null || !context.mounted) return;
      final path = await NcPdfExportService().exportSingleNcToPdf(nc);
      if (context.mounted) {
        await NcPdfExportService().shareExport(path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiche exportée en PDF')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _viewNcDetail(BuildContext context) {
    if (ncId == null) return;
    final location = GoRouterState.of(context).matchedLocation;
    final prefix = location.startsWith('/admin') ? '/admin' : '/app';
    context.push('$prefix/alerts/nc/$ncId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success icon
              Icon(
                Icons.check_circle,
                size: 120,
                color: Colors.green,
              ),
              const SizedBox(height: 32),
              // Success message
              Text(
                'Non-conformité créée avec succès !',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Votre fiche de non-conformité a été enregistrée.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              if (ncId != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ID de la fiche',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ncId!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              if (ncId != null) ...[
                WizardActionButton(
                  label: 'Exporter en PDF',
                  icon: Icons.picture_as_pdf,
                  isPrimary: true,
                  onPressed: () => _exportPdf(context),
                ),
                const SizedBox(height: 12),
                WizardActionButton(
                  label: 'Voir la fiche',
                  icon: Icons.description,
                  isPrimary: false,
                  onPressed: () => _viewNcDetail(context),
                ),
                const SizedBox(height: 12),
              ],
              WizardActionButton(
                label: 'Voir historique NC',
                icon: Icons.history,
                isPrimary: ncId == null,
                onPressed: () => _navigateToHistory(context),
              ),
              const SizedBox(height: 16),
              WizardActionButton(
                label: 'Retour aux alertes',
                icon: Icons.arrow_back,
                isPrimary: false,
                onPressed: () => _navigateToAlerts(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

