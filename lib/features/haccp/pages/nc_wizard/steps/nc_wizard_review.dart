/// NC Wizard Review Screen
/// 
/// Shows recap of all fields before submission
/// Buttons: "Enregistrer brouillon", "Soumettre"

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bekkapp/core/theme/app_theme.dart';
import 'package:bekkapp/data/repositories/nc_repository.dart';
import 'package:bekkapp/data/models/nc_models.dart' as nc_models;
import 'package:bekkapp/data/repositories/organization_repository.dart';
import 'package:bekkapp/services/employee_session_service.dart';
import '../models/nc_draft_model.dart';
import '../services/nc_draft_repository.dart';
import '../widgets/wizard_input_widgets.dart';

class NcWizardReview extends StatefulWidget {
  final NcDraft draft;
  final VoidCallback onBack;

  const NcWizardReview({
    super.key,
    required this.draft,
    required this.onBack,
  });

  @override
  State<NcWizardReview> createState() => _NcWizardReviewState();
}

class _NcWizardReviewState extends State<NcWizardReview> {
  final NCRepository _ncRepo = NCRepository();
  final NcDraftRepository _draftRepo = NcDraftRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final EmployeeSessionService _employeeSession = EmployeeSessionService();
  
  bool _isSubmitting = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  Future<void> _saveDraft() async {
    try {
      await _draftRepo.saveDraft(widget.draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brouillon enregistré')),
        );
      }
    } catch (e) {
      debugPrint('[NcWizardReview] Error saving draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      // Convert draft to NC model and submit
      final orgId = await _orgRepo.getOrCreateOrganization();
      final employeeId = await _employeeSession.getCurrentEmployeeId();
      
      // Validate employee ID
      if (employeeId == null) {
        throw Exception('Aucun employé connecté. Veuillez vous reconnecter.');
      }
      
      // Map draft to NC source type
      nc_models.NCSourceType? sourceType;
      switch (widget.draft.ncType) {
        case 'Température':
          sourceType = nc_models.NCSourceType.temperature;
          break;
        case 'Réception':
          sourceType = nc_models.NCSourceType.reception;
          break;
        case 'Nettoyage':
          sourceType = nc_models.NCSourceType.cleaning;
          break;
        case 'Huile':
          sourceType = nc_models.NCSourceType.oil;
          break;
        default:
          sourceType = nc_models.NCSourceType.temperature; // Default
      }
      
      // Map severity to object category
      nc_models.NCObjectCategory objectCategory;
      switch (widget.draft.ncType) {
        case 'Température':
          objectCategory = nc_models.NCObjectCategory.chaineDuFroid;
          break;
        case 'Réception':
          objectCategory = nc_models.NCObjectCategory.reclamationClient;
          break;
        case 'Nettoyage':
          objectCategory = nc_models.NCObjectCategory.nettoyageDesinfection;
          break;
        default:
          objectCategory = nc_models.NCObjectCategory.autre;
      }
      
      // Create NC via repository
      // Note: We'll need to extend NCRepository or create a new method
      // For now, use createDraftFromSource with mapped data
      final ncId = await _ncRepo.createDraftFromSource(
        sourceType: sourceType!,
        sourceTable: 'nc_wizard',
        sourceId: null,
        sourcePayload: widget.draft.toJson(),
        employeeId: employeeId,
        prefillData: {
          'status': _mapStatus(widget.draft.status ?? 'Ouverte'),
          'detection_date': widget.draft.detectionDate.toIso8601String(),
          'description': widget.draft.detailedDescription ?? widget.draft.shortDescription ?? '',
          'object_category': objectCategory.value,
          'opened_by_employee_id': employeeId,
          'opened_by_role_service': widget.draft.siteZone,
          'product_name': widget.draft.productLot,
          'step': widget.draft.siteZone,
          'sanitary_impact': widget.draft.affectedQuantity,
          'immediate_action_done': widget.draft.immediateAction != null,
          'immediate_action_detail': widget.draft.immediateAction,
          'immediate_action_done_by': widget.draft.immediateActionResponsible,
          'immediate_action_done_at': widget.draft.immediateActionDate?.toIso8601String(),
        },
      );
      
      // Retirer le brouillon après création de la NC (ne plus proposer de le rouvrir)
      await _draftRepo.clearDrafts(orgId, employeeId);

      // Téléverser les pièces jointes en arrière-plan (sans bloquer l'UI)
      _uploadAttachmentsInBackground(ncId, employeeId);

      if (mounted) {
        final prefix = GoRouterState.of(context).matchedLocation.startsWith('/admin') ? '/admin' : '/app';
        context.go('$prefix/alerts/nc/success', extra: {'ncId': ncId});
      }
    } catch (e) {
      debugPrint('[NcWizardReview] Error submitting: $e');
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la soumission: $e')),
        );
      }
    }
  }

  /// Envoie photos et documents en arrière-plan sans bloquer l'interface
  void _uploadAttachmentsInBackground(String ncId, String employeeId) {
    final photos = widget.draft.photoPaths;
    final docs = widget.draft.documentPaths;
    if (photos.isEmpty && docs.isEmpty) return;

    Future(() async {
      for (final path in photos) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await _ncRepo.addAttachment(
              ncId: ncId,
              file: file,
              employeeId: employeeId,
            );
          }
        } catch (e) {
          debugPrint('[NcWizardReview] Erreur upload photo: $e');
        }
      }
      for (final path in docs) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await _ncRepo.addAttachment(
              ncId: ncId,
              file: file,
              fileName: path.split('/').last,
              employeeId: employeeId,
            );
          }
        } catch (e) {
          debugPrint('[NcWizardReview] Erreur upload document: $e');
        }
      }
    });
  }

  String _mapStatus(String? status) {
    switch (status) {
      case 'Ouverte':
        return 'open';
      case 'En cours':
        return 'in_progress';
      case 'Clôturée':
        return 'closed';
      default:
        return 'draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Révision'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Récapitulatif',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vérifiez les informations avant de soumettre',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  // Step 1: Identification
                  _buildSection(
                    '1. Identification',
                    [
                      _buildField('Date/heure', _dateTimeFormat.format(widget.draft.detectionDate)),
                      if (widget.draft.siteZone != null)
                        _buildField('Site/Zone', widget.draft.siteZone!),
                      if (widget.draft.ncType != null)
                        _buildField('Type de NC', widget.draft.ncType!),
                      if (widget.draft.severity != null)
                        _buildField('Gravité', widget.draft.severity!),
                    ],
                  ),
                  // Step 2: Constat
                  _buildSection(
                    '2. Constat',
                    [
                      if (widget.draft.shortDescription != null)
                        _buildField('Description courte', widget.draft.shortDescription!),
                      if (widget.draft.detailedDescription != null)
                        _buildField('Description détaillée', widget.draft.detailedDescription!),
                      if (widget.draft.productLot != null)
                        _buildField('Produit/Lot', widget.draft.productLot!),
                      if (widget.draft.affectedQuantity != null)
                        _buildField('Quantité impactée', widget.draft.affectedQuantity!),
                    ],
                  ),
                  // Step 3: Causes
                  _buildSection(
                    '3. Causes probables',
                    [
                      if (widget.draft.causeCategory != null)
                        _buildField('Catégorie', widget.draft.causeCategory!),
                      if (widget.draft.causeDetail != null)
                        _buildField('Cause détaillée', widget.draft.causeDetail!),
                      _buildField('NC répétée', widget.draft.isRepeated == true ? 'Oui' : 'Non'),
                    ],
                  ),
                  // Step 4: Actions immédiates
                  _buildSection(
                    '4. Actions immédiates',
                    [
                      if (widget.draft.immediateAction != null)
                        _buildField('Action', widget.draft.immediateAction!),
                      if (widget.draft.productDisposition != null)
                        _buildField('Disposition produit', widget.draft.productDisposition!),
                      if (widget.draft.immediateActionDate != null)
                        _buildField('Date/heure', _dateTimeFormat.format(widget.draft.immediateActionDate!)),
                    ],
                  ),
                  // Step 5: Actions préventives
                  _buildSection(
                    '5. Actions préventives',
                    [
                      if (widget.draft.preventiveAction != null)
                        _buildField('Action', widget.draft.preventiveAction!),
                      if (widget.draft.preventiveActionDueDate != null)
                        _buildField('Échéance', _dateFormat.format(widget.draft.preventiveActionDueDate!)),
                      _buildField('Validation admin', widget.draft.requiresAdminValidation == true ? 'Oui' : 'Non'),
                    ],
                  ),
                  // Step 6: Preuves
                  _buildSection(
                    '6. Preuves',
                    [
                      _buildField('Photos', '${widget.draft.photoPaths.length} photo(s)'),
                      _buildField('Documents', '${widget.draft.documentPaths.length} document(s)'),
                      if (widget.draft.evidenceComments != null)
                        _buildField('Commentaires', widget.draft.evidenceComments!),
                    ],
                  ),
                  // Step 7: Signature
                  _buildSection(
                    '7. Signature & clôture',
                    [
                      if (widget.draft.status != null)
                        _buildField('Statut', widget.draft.status!),
                      if (widget.draft.finalComment != null)
                        _buildField('Commentaire final', widget.draft.finalComment!),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                WizardActionButton(
                  label: 'Enregistrer brouillon',
                  icon: Icons.save,
                  isPrimary: false,
                  onPressed: _isSubmitting ? null : _saveDraft,
                ),
                const SizedBox(height: 12),
                WizardActionButton(
                  label: 'Soumettre',
                  icon: Icons.check,
                  isPrimary: true,
                  onPressed: _isSubmitting ? null : _submit,
                ),
                if (_isSubmitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> fields) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (fields.isEmpty)
              Text(
                'Non renseigné',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
              )
            else
              ...fields,
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

