/// NC Wizard Step 1/7 - Identification
/// 
/// Step 1: Date/heure, Site/zone, Type de NC, Gravité, Détectée par

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bekkapp/services/employee_session_service.dart';
import '../models/nc_draft_model.dart';
import '../widgets/wizard_input_widgets.dart';

class NcWizardStep1Identification extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final NcDraft draft;
  final ValueChanged<NcDraft Function(NcDraft)> onDraftChanged;

  const NcWizardStep1Identification({
    super.key,
    required this.formKey,
    required this.draft,
    required this.onDraftChanged,
  });

  @override
  Widget build(BuildContext context) {
    final employeeSession = EmployeeSessionService();
    final currentEmployee = employeeSession.currentEmployee;
    final detectedByName = currentEmployee?.fullName ?? 'Non défini';

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step title
            Text(
              'Identification',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Informations de base sur la non-conformité',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            // Date/heure de détection
            WizardDateTimePicker(
              label: 'Date et heure de détection',
              helperText: 'Quand la non-conformité a-t-elle été détectée ?',
              value: draft.detectionDate, // Non-nullable, always has a value
              onChanged: (date) {
                onDraftChanged((d) => d.copyWith(detectionDate: date));
              },
              required: true,
            ),
            const SizedBox(height: 24),
            // Site / Zone
            WizardTextInput(
              label: 'Site / Zone',
              helperText: 'Lieu où la non-conformité a été détectée',
              value: draft.siteZone,
              onChanged: (value) {
                onDraftChanged((d) => d.copyWith(siteZone: value.isEmpty ? null : value));
              },
            ),
            const SizedBox(height: 24),
            // Type de NC
            WizardDropdown<String>(
              label: 'Type de non-conformité',
              helperText: 'Catégorie de la non-conformité',
              value: draft.ncType,
              required: true,
              hintText: 'Sélectionner un type',
              items: const [
                DropdownMenuItem(value: 'Température', child: Text('Température')),
                DropdownMenuItem(value: 'Réception', child: Text('Réception')),
                DropdownMenuItem(value: 'Nettoyage', child: Text('Nettoyage')),
                DropdownMenuItem(value: 'Huile', child: Text('Huile')),
                DropdownMenuItem(value: 'Document', child: Text('Document')),
                DropdownMenuItem(value: 'Autre', child: Text('Autre')),
              ],
              onChanged: (value) {
                onDraftChanged((d) => d.copyWith(ncType: value));
              },
            ),
            const SizedBox(height: 24),
            // Gravité
            WizardDropdown<String>(
              label: 'Gravité',
              helperText: 'Niveau de gravité de la non-conformité',
              value: draft.severity,
              required: true,
              hintText: 'Sélectionner la gravité',
              items: const [
                DropdownMenuItem(value: 'Mineure', child: Text('Mineure')),
                DropdownMenuItem(value: 'Majeure', child: Text('Majeure')),
                DropdownMenuItem(value: 'Critique', child: Text('Critique')),
              ],
              onChanged: (value) {
                onDraftChanged((d) => d.copyWith(severity: value));
              },
            ),
            const SizedBox(height: 24),
            // Détectée par
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détectée par',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        detectedByName,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  if (currentEmployee != null)
                    Text(
                      'ID: ${currentEmployee!.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

