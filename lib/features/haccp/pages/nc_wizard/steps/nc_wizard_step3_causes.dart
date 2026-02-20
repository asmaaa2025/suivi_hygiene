/// NC Wizard Step 3/7 - Causes probables
/// 
/// Step 3: Catégorie cause, Cause détaillée, NC répétée

import 'package:flutter/material.dart';
import '../models/nc_draft_model.dart';
import '../widgets/wizard_input_widgets.dart';

class NcWizardStep3Causes extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final NcDraft draft;
  final ValueChanged<NcDraft Function(NcDraft)> onDraftChanged;

  const NcWizardStep3Causes({
    super.key,
    required this.formKey,
    required this.draft,
    required this.onDraftChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step title
            Text(
              'Causes probables',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyse des causes de la non-conformité',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            // Catégorie cause
            WizardDropdown<String>(
              label: 'Catégorie de cause',
              helperText: 'Méthode 5M : sélectionnez la catégorie principale',
              value: draft.causeCategory,
              required: true,
              hintText: 'Sélectionner une catégorie',
              items: const [
                DropdownMenuItem(value: 'Matériel', child: Text('Matériel')),
                DropdownMenuItem(value: 'Humain', child: Text('Humain')),
                DropdownMenuItem(value: 'Méthode', child: Text('Méthode')),
                DropdownMenuItem(value: 'Matière', child: Text('Matière')),
                DropdownMenuItem(value: 'Milieu', child: Text('Milieu')),
                DropdownMenuItem(value: 'Mesure', child: Text('Mesure')),
              ],
              onChanged: (value) {
                onDraftChanged((d) => d.copyWith(causeCategory: value));
              },
            ),
            const SizedBox(height: 24),
            // Cause détaillée
            WizardTextInput(
              label: 'Cause détaillée',
              helperText: 'Description précise de la cause identifiée',
              value: draft.causeDetail,
              onChanged: (value) {
                onDraftChanged((d) => d.copyWith(causeDetail: value.isEmpty ? null : value));
              },
              required: true,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            // NC répétée
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Non-conformité répétée ?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Oui'),
                          value: true,
                          groupValue: draft.isRepeated,
                          onChanged: (value) {
                            onDraftChanged((d) => d.copyWith(isRepeated: value));
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Non'),
                          value: false,
                          groupValue: draft.isRepeated,
                          onChanged: (value) {
                            onDraftChanged((d) => d.copyWith(isRepeated: value));
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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



