/// Non-Conformity Detail/Edit Page
/// 8-section form with accordion/expansion panels for tablet-friendly UI

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/nc_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/produit_repository.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../data/models/nc_models.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/produit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../shared/widgets/primary_cta_button.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../services/nc_pdf_export_service.dart';

class NCDetailPage extends StatefulWidget {
  final String? ncId;
  final Map<String, dynamic>? prefillData; // For creating from source

  const NCDetailPage({super.key, this.ncId, this.prefillData});

  @override
  State<NCDetailPage> createState() => _NCDetailPageState();
}

class _NCDetailPageState extends State<NCDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _ncRepo = NCRepository();
  final _employeeRepo = EmployeeRepository();
  final _produitRepo = ProduitRepository();

  // Form controllers
  final _descriptionController = TextEditingController();
  final _stepController = TextEditingController();
  final _sanitaryImpactController = TextEditingController();
  final _openedByRoleServiceController = TextEditingController();
  final _objectOtherController = TextEditingController();
  final _immediateActionDetailController = TextEditingController();
  final _rqClassificationController = TextEditingController();

  // Section 5: Causes
  final List<NCCause> _causes = [];
  final Map<String, TextEditingController> _causeControllers = {};

  // Section 6: Solutions
  final List<NCSolution> _solutions = [];
  final Map<String, TextEditingController> _solutionControllers = {};

  // Section 7: Actions
  final List<NCAction> _actions = [];
  final Map<String, TextEditingController> _actionControllers = {};
  final Map<String, String?> _actionResponsibleIds = {};
  final Map<String, DateTime?> _actionTargetDates = {};

  // Section 8: Verifications
  final List<NCVerification> _verifications = [];
  final Map<String, TextEditingController> _verificationControllers = {};
  final Map<String, TextEditingController> _verificationResultControllers = {};

  // State
  NonConformity? _nc;
  List<Employee> _employees = [];
  List<Produit> _products = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Form fields
  String? _openedByEmployeeId;
  String? _productId;
  String? _productName;
  NCObjectCategory _objectCategory = NCObjectCategory.autre;
  NCStatus _status = NCStatus.draft;
  DateTime _detectionDate = DateTime.now();
  bool _immediateActionDone = false;
  String? _immediateActionDoneBy;
  DateTime? _immediateActionDoneAt;
  DateTime? _rqDate;
  bool _rqActionCorrectiveRequired = false;

  // Attachments
  final List<NCAttachment> _attachments = [];
  final List<File> _newAttachmentFiles = [];

  // Expansion panel state
  final Map<int, bool> _expandedSections = {
    0: true, // Section 1 expanded by default
    1: false,
    2: false,
    3: false,
    4: false,
    5: false,
    6: false,
    7: false,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load employees and products
      final employees = await _employeeRepo.getAll();
      final products = await _produitRepo.getAll();

      if (widget.ncId != null) {
        // Load existing NC
        final nc = await _ncRepo.getById(widget.ncId!, includeRelated: true);
        if (nc != null) {
          _loadNCData(nc);
        }
      } else if (widget.prefillData != null) {
        // Apply prefill data
        _applyPrefillData(widget.prefillData!);
      }

      setState(() {
        _employees = employees;
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[NCDetail] Error loading data: $e');
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
      setState(() => _isLoading = false);
    }
  }

  void _loadNCData(NonConformity nc) {
    setState(() {
      _nc = nc;
      _status = nc.status;
      _openedByEmployeeId = nc.openedByEmployeeId;
      _openedByRoleServiceController.text = nc.openedByRoleService ?? '';
      _objectCategory = nc.objectCategory;
      _objectOtherController.text = nc.objectOther ?? '';
      _productId = nc.productId;
      _productName = nc.productName;
      _stepController.text = nc.step ?? '';
      _descriptionController.text = nc.description;
      _sanitaryImpactController.text = nc.sanitaryImpact ?? '';
      _detectionDate = nc.detectionDate;
      _immediateActionDone = nc.immediateActionDone;
      _immediateActionDetailController.text = nc.immediateActionDetail ?? '';
      _immediateActionDoneBy = nc.immediateActionDoneBy;
      _immediateActionDoneAt = nc.immediateActionDoneAt;
      _rqDate = nc.rqDate;
      _rqClassificationController.text = nc.rqClassification ?? '';
      _rqActionCorrectiveRequired = nc.rqActionCorrectiveRequired;

      // Load related data
      _causes.clear();
      _causes.addAll(nc.causes ?? []);
      for (final cause in _causes) {
        _causeControllers[cause.id] = TextEditingController(
          text: cause.causeText,
        );
      }

      _solutions.clear();
      _solutions.addAll(nc.solutions ?? []);
      for (final solution in _solutions) {
        _solutionControllers[solution.id] = TextEditingController(
          text: solution.solutionText,
        );
      }

      _actions.clear();
      _actions.addAll(nc.actions ?? []);
      for (final action in _actions) {
        _actionControllers[action.id] = TextEditingController(
          text: action.actionText,
        );
        _actionResponsibleIds[action.id] = action.responsibleEmployeeId;
        _actionTargetDates[action.id] = action.targetDate;
      }

      _verifications.clear();
      _verifications.addAll(nc.verifications ?? []);
      for (final verification in _verifications) {
        _verificationControllers[verification.id] = TextEditingController(
          text: verification.actionVerified ?? '',
        );
        _verificationResultControllers[verification.id] = TextEditingController(
          text: verification.result ?? '',
        );
      }

      _attachments.clear();
      _attachments.addAll(nc.attachments ?? []);
    });
  }

  void _applyPrefillData(Map<String, dynamic> prefill) {
    if (prefill['object_category'] != null) {
      _objectCategory = NCObjectCategory.fromString(
        prefill['object_category'] as String,
      );
    }
    if (prefill['description'] != null) {
      _descriptionController.text = prefill['description'] as String;
    }
    if (prefill['step'] != null) {
      _stepController.text = prefill['step'] as String;
    }
    if (prefill['sanitary_impact'] != null) {
      _sanitaryImpactController.text = prefill['sanitary_impact'] as String;
    }
    if (prefill['opened_by_employee_id'] != null) {
      _openedByEmployeeId = prefill['opened_by_employee_id'] as String;
    }
    if (prefill['product_id'] != null) {
      _productId = prefill['product_id'] as String;
    }
    if (prefill['product_name'] != null) {
      _productName = prefill['product_name'] as String;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _stepController.dispose();
    _sanitaryImpactController.dispose();
    _openedByRoleServiceController.dispose();
    _objectOtherController.dispose();
    _immediateActionDetailController.dispose();
    _rqClassificationController.dispose();
    for (final controller in _causeControllers.values) {
      controller.dispose();
    }
    for (final controller in _solutionControllers.values) {
      controller.dispose();
    }
    for (final controller in _actionControllers.values) {
      controller.dispose();
    }
    for (final controller in _verificationControllers.values) {
      controller.dispose();
    }
    for (final controller in _verificationResultControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      String ncId;

      if (_nc == null) {
        // Create new NC
        final orgRepo = OrganizationRepository();
        final orgId = await orgRepo.getOrCreateOrganization();

        // Build source payload from prefill or empty
        final sourcePayload =
            widget.prefillData?['source_payload'] as Map<String, dynamic>? ??
            {};
        final sourceType = widget.prefillData?['source_type'] != null
            ? NCSourceType.fromString(
                widget.prefillData!['source_type'] as String,
              )
            : null;
        final sourceTable = widget.prefillData?['source_table'] as String?;
        final sourceId = widget.prefillData?['source_id'] as String?;

        ncId = await _ncRepo.createDraftFromSource(
          sourceType: sourceType ?? NCSourceType.temperature,
          sourceTable: sourceTable ?? 'unknown',
          sourceId: sourceId,
          sourcePayload: sourcePayload,
          employeeId: _openedByEmployeeId,
          prefillData: {
            'status': _status.value,
            'detection_date': _detectionDate.toIso8601String(),
            'opened_by_employee_id': _openedByEmployeeId,
            'opened_by_role_service':
                _openedByRoleServiceController.text.isEmpty
                ? null
                : _openedByRoleServiceController.text,
            'object_category': _objectCategory.value,
            'object_other': _objectCategory == NCObjectCategory.autre
                ? _objectOtherController.text.isEmpty
                      ? null
                      : _objectOtherController.text
                : null,
            'product_id': _productId,
            'product_name': _productName,
            'step': _stepController.text.isEmpty ? null : _stepController.text,
            'description': _descriptionController.text,
            'sanitary_impact': _sanitaryImpactController.text.isEmpty
                ? null
                : _sanitaryImpactController.text,
            'immediate_action_done': _immediateActionDone,
            'immediate_action_detail':
                _immediateActionDetailController.text.isEmpty
                ? null
                : _immediateActionDetailController.text,
            'immediate_action_done_by': _immediateActionDoneBy,
            'immediate_action_done_at': _immediateActionDoneAt
                ?.toIso8601String(),
            'rq_date': _rqDate?.toIso8601String(),
            'rq_classification': _rqClassificationController.text.isEmpty
                ? null
                : _rqClassificationController.text,
            'rq_action_corrective_required': _rqActionCorrectiveRequired,
          },
        );
      } else {
        // Update existing NC
        ncId = _nc!.id;
        final updated = _nc!.copyWith(
          status: _status,
          openedByEmployeeId: _openedByEmployeeId,
          openedByRoleService: _openedByRoleServiceController.text.isEmpty
              ? null
              : _openedByRoleServiceController.text,
          objectCategory: _objectCategory,
          objectOther: _objectCategory == NCObjectCategory.autre
              ? _objectOtherController.text.isEmpty
                    ? null
                    : _objectOtherController.text
              : null,
          productId: _productId,
          productName: _productName,
          step: _stepController.text.isEmpty ? null : _stepController.text,
          description: _descriptionController.text,
          sanitaryImpact: _sanitaryImpactController.text.isEmpty
              ? null
              : _sanitaryImpactController.text,
          immediateActionDone: _immediateActionDone,
          immediateActionDetail: _immediateActionDetailController.text.isEmpty
              ? null
              : _immediateActionDetailController.text,
          immediateActionDoneBy: _immediateActionDoneBy,
          immediateActionDoneAt: _immediateActionDoneAt,
          rqDate: _rqDate,
          rqClassification: _rqClassificationController.text.isEmpty
              ? null
              : _rqClassificationController.text,
          rqActionCorrectiveRequired: _rqActionCorrectiveRequired,
        );

        await _ncRepo.updateNonConformity(updated);
      }

      // Save causes
      for (final cause in _causes) {
        final controller = _causeControllers[cause.id];
        if (controller != null && controller.text.isNotEmpty) {
          try {
            // Try to update existing cause
            // For new causes, we need to add them first
            if (!cause.id.startsWith('temp_')) {
              // Existing cause - would need update method in repository
              // For now, delete and recreate if text changed
              if (controller.text != cause.causeText) {
                await _ncRepo.deleteCause(cause.id);
                await _ncRepo.addCause(
                  ncId: ncId,
                  category: cause.category,
                  causeText: controller.text,
                  isMostProbable: cause.isMostProbable,
                );
              }
            } else {
              // New cause
              await _ncRepo.addCause(
                ncId: ncId,
                category: cause.category,
                causeText: controller.text,
                isMostProbable: cause.isMostProbable,
              );
            }
          } catch (e) {
            debugPrint('[NCDetail] Error saving cause: $e');
          }
        }
      }

      // Save solutions
      for (final solution in _solutions) {
        final controller = _solutionControllers[solution.id];
        if (controller != null && controller.text.isNotEmpty) {
          try {
            if (!solution.id.startsWith('temp_')) {
              // Existing solution - delete and recreate if changed
              if (controller.text != solution.solutionText) {
                await _ncRepo.deleteSolution(solution.id);
                await _ncRepo.addSolution(
                  ncId: ncId,
                  solutionText: controller.text,
                  priority: solution.priority,
                );
              }
            } else {
              // New solution
              await _ncRepo.addSolution(
                ncId: ncId,
                solutionText: controller.text,
                priority: solution.priority,
              );
            }
          } catch (e) {
            debugPrint('[NCDetail] Error saving solution: $e');
          }
        }
      }

      // Save actions
      for (final action in _actions) {
        final controller = _actionControllers[action.id];
        if (controller != null && controller.text.isNotEmpty) {
          try {
            if (!action.id.startsWith('temp_')) {
              // Existing action - update
              final updatedAction = NCAction(
                id: action.id,
                nonConformityId: action.nonConformityId,
                actionText: controller.text,
                responsibleEmployeeId: _actionResponsibleIds[action.id],
                targetDate: _actionTargetDates[action.id],
                status: action.status,
                createdAt: action.createdAt,
                updatedAt: DateTime.now(),
                orderIndex: action.orderIndex,
              );
              await _ncRepo.updateAction(updatedAction);
            } else {
              // New action
              await _ncRepo.addAction(
                ncId: ncId,
                actionText: controller.text,
                responsibleEmployeeId: _actionResponsibleIds[action.id],
                targetDate: _actionTargetDates[action.id],
                status: action.status,
              );
            }
          } catch (e) {
            debugPrint('[NCDetail] Error saving action: $e');
          }
        }
      }

      // Save verifications
      for (final verification in _verifications) {
        final actionController = _verificationControllers[verification.id];
        final resultController =
            _verificationResultControllers[verification.id];
        if (actionController != null && actionController.text.isNotEmpty) {
          try {
            if (!verification.id.startsWith('temp_')) {
              // Existing verification - delete and recreate if changed
              await _ncRepo.deleteVerification(verification.id);
              await _ncRepo.addVerification(
                ncId: ncId,
                actionVerified: actionController.text,
                responsibleEmployeeId: verification.responsibleEmployeeId,
                result: resultController?.text,
                verificationDate: verification.verificationDate,
              );
            } else {
              // New verification
              await _ncRepo.addVerification(
                ncId: ncId,
                actionVerified: actionController.text,
                responsibleEmployeeId: verification.responsibleEmployeeId,
                result: resultController?.text,
                verificationDate: verification.verificationDate,
              );
            }
          } catch (e) {
            debugPrint('[NCDetail] Error saving verification: $e');
          }
        }
      }

      // Upload new attachments
      for (final file in _newAttachmentFiles) {
        try {
          await _ncRepo.addAttachment(
            ncId: ncId,
            file: file,
            employeeId: _openedByEmployeeId,
          );
        } catch (e) {
          debugPrint('[NCDetail] Error uploading attachment: $e');
        }
      }

      if (mounted) {
        ErrorHandler.showSuccess(
          context,
          _nc == null ? 'NC créée' : 'NC mise à jour',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _exportToPdf() async {
    if (_nc == null) return;
    try {
      final exportService = NcPdfExportService();
      final path = await exportService.exportSingleNcToPdf(_nc!);
      if (mounted) {
        await exportService.shareExport(path);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fiche exportée en PDF')));
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Non-Conformité'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('$routePrefix/alerts/nc/history'),
          tooltip: 'Retour',
        ),
        title: Text(_nc?.ficheNumber ?? 'Nouvelle NC'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_nc != null) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportToPdf,
              tooltip: 'Exporter en PDF',
            ),
            PopupMenuButton<NCStatus>(
              icon: const Icon(Icons.more_vert),
              onSelected: (status) {
                setState(() => _status = status);
                _save();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: NCStatus.draft,
                  child: Text('Brouillon'),
                ),
                const PopupMenuItem(
                  value: NCStatus.open,
                  child: Text('Ouvert'),
                ),
                const PopupMenuItem(
                  value: NCStatus.inProgress,
                  child: Text('En cours'),
                ),
                const PopupMenuItem(
                  value: NCStatus.closed,
                  child: Text('Fermé'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ExpansionPanelList.radio(
                  expandedHeaderPadding: const EdgeInsets.all(16),
                  initialOpenPanelValue: 0,
                  children: [
                    _buildSection1(),
                    _buildSection2(),
                    _buildSection3(),
                    _buildSection4(),
                    _buildSection5(),
                    _buildSection6(),
                    _buildSection7(),
                    _buildSection8(),
                  ],
                ),
              ),
            ),
            // Save button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: PrimaryCTAButton(
                label: _nc == null ? 'Créer la NC' : 'Enregistrer',
                icon: Icons.save,
                onPressed: _save,
                isLoading: _isSaving,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _buildSection1() {
    return ExpansionPanelRadio(
      value: 0,
      headerBuilder: (context, isExpanded) => const ListTile(
        title: Text('1. Identification'),
        leading: Icon(Icons.person),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _openedByEmployeeId,
              decoration: const InputDecoration(
                labelText: 'Ouvert par (employé) *',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sélectionner...'),
                ),
                ..._employees.map(
                  (e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)),
                ),
              ],
              onChanged: (value) => setState(() => _openedByEmployeeId = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _openedByRoleServiceController,
              decoration: const InputDecoration(
                labelText: 'Rôle/Service',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _nc?.ficheNumber ?? 'Auto-généré',
              decoration: const InputDecoration(
                labelText: 'Numéro de fiche',
                border: OutlineInputBorder(),
                enabled: false,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(_detectionDate),
              decoration: const InputDecoration(
                labelText: 'Date de détection',
                border: OutlineInputBorder(),
                enabled: false,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NCObjectCategory>(
              value: _objectCategory,
              decoration: const InputDecoration(
                labelText: 'Catégorie d\'objet *',
                border: OutlineInputBorder(),
              ),
              items: NCObjectCategory.values
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _objectCategory = value);
                }
              },
            ),
            if (_objectCategory == NCObjectCategory.autre) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _objectOtherController,
                decoration: const InputDecoration(
                  labelText: 'Précisez *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_objectCategory == NCObjectCategory.autre &&
                      (value == null || value.isEmpty)) {
                    return 'Veuillez préciser';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _buildSection2() {
    return ExpansionPanelRadio(
      value: 1,
      headerBuilder: (context, isExpanded) => const ListTile(
        title: Text('2. Description'),
        leading: Icon(Icons.description),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _productId,
              decoration: const InputDecoration(
                labelText: 'Produit concerné',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun')),
                ..._products.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.nom)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _productId = value;
                  if (value != null) {
                    final product = _products.firstWhere((p) => p.id == value);
                    _productName = product.nom;
                  } else {
                    _productName = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stepController,
              decoration: const InputDecoration(
                labelText: 'Étape',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir une description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sanitaryImpactController,
              decoration: const InputDecoration(
                labelText: 'Impact sanitaire',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _buildSection3() {
    return ExpansionPanelRadio(
      value: 2,
      headerBuilder: (context, isExpanded) => const ListTile(
        title: Text('3. Action immédiate (correction)'),
        leading: Icon(Icons.flash_on),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('Action immédiate effectuée'),
              value: _immediateActionDone,
              onChanged: (value) =>
                  setState(() => _immediateActionDone = value),
            ),
            if (_immediateActionDone) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _immediateActionDetailController,
                decoration: const InputDecoration(
                  labelText: 'Détail de l\'action',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _immediateActionDoneBy,
                decoration: const InputDecoration(
                  labelText: 'Effectué par',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sélectionner...'),
                  ),
                  ..._employees.map(
                    (e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.fullName)),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _immediateActionDoneBy = value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _buildSection4() {
    return ExpansionPanelRadio(
      value: 3,
      headerBuilder: (context, isExpanded) => const ListTile(
        title: Text('4. Évaluation RQ (RSDA)'),
        leading: Icon(Icons.assessment),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _rqDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _rqDate = date);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _rqDate != null
                    ? DateFormat('dd/MM/yyyy').format(_rqDate!)
                    : 'Sélectionner la date RQ',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rqClassificationController,
              decoration: const InputDecoration(
                labelText: 'Classification RQ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Action corrective requise'),
              value: _rqActionCorrectiveRequired,
              onChanged: (value) =>
                  setState(() => _rqActionCorrectiveRequired = value),
            ),
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _buildSection5() {
    return ExpansionPanelRadio(
      value: 4,
      headerBuilder: (context, isExpanded) => ListTile(
        title: const Text('5. Analyse des causes (5M)'),
        leading: const Icon(Icons.search),
        trailing: IconButton(icon: const Icon(Icons.add), onPressed: _addCause),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _causes.isEmpty
            ? const Center(child: Text('Aucune cause ajoutée'))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _causes.length,
                itemBuilder: (context, index) {
                  final cause = _causes[index];
                  return _buildCauseItem(cause, index);
                },
              ),
      ),
    );
  }

  Widget _buildCauseItem(NCCause cause, int index) {
    final controller =
        _causeControllers[cause.id] ??
        TextEditingController(text: cause.causeText);
    _causeControllers[cause.id] = controller;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<NCCauseCategory>(
                    value: cause.category,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: NCCauseCategory.values
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          final idx = _causes.indexWhere(
                            (c) => c.id == cause.id,
                          );
                          if (idx != -1) {
                            _causes[idx] = NCCause(
                              id: cause.id,
                              nonConformityId: cause.nonConformityId,
                              category: value,
                              causeText: cause.causeText,
                              isMostProbable: cause.isMostProbable,
                              createdAt: cause.createdAt,
                              updatedAt: cause.updatedAt,
                              orderIndex: cause.orderIndex,
                            );
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: cause.isMostProbable,
                  onChanged: (value) {
                    setState(() {
                      final idx = _causes.indexWhere((c) => c.id == cause.id);
                      if (idx != -1) {
                        _causes[idx] = NCCause(
                          id: cause.id,
                          nonConformityId: cause.nonConformityId,
                          category: cause.category,
                          causeText: cause.causeText,
                          isMostProbable: value ?? false,
                          createdAt: cause.createdAt,
                          updatedAt: cause.updatedAt,
                          orderIndex: cause.orderIndex,
                        );
                      }
                    });
                  },
                ),
                const Text('Plus probable'),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeCause(cause.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Cause',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _addCause() {
    final tempId = 'temp_cause_${DateTime.now().millisecondsSinceEpoch}';
    final newCause = NCCause(
      id: tempId,
      nonConformityId: _nc?.id ?? '',
      category: NCCauseCategory.methode,
      causeText: '',
      isMostProbable: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _causes.add(newCause);
      _causeControllers[tempId] = TextEditingController();
    });
  }

  void _removeCause(String causeId) {
    setState(() {
      _causes.removeWhere((c) => c.id == causeId);
      _causeControllers[causeId]?.dispose();
      _causeControllers.remove(causeId);
    });
  }

  ExpansionPanelRadio _buildSection6() {
    return ExpansionPanelRadio(
      value: 5,
      headerBuilder: (context, isExpanded) => ListTile(
        title: const Text('6. Recherche de solutions'),
        leading: const Icon(Icons.lightbulb),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addSolution,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _solutions.isEmpty
            ? const Center(child: Text('Aucune solution ajoutée'))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _solutions.length,
                itemBuilder: (context, index) {
                  final solution = _solutions[index];
                  return _buildSolutionItem(solution, index);
                },
              ),
      ),
    );
  }

  Widget _buildSolutionItem(NCSolution solution, int index) {
    final controller =
        _solutionControllers[solution.id] ??
        TextEditingController(text: solution.solutionText);
    _solutionControllers[solution.id] = controller;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Solution',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: solution.priority.toString(),
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeSolution(solution.id),
            ),
          ],
        ),
      ),
    );
  }

  void _addSolution() {
    final tempId = 'temp_solution_${DateTime.now().millisecondsSinceEpoch}';
    final newSolution = NCSolution(
      id: tempId,
      nonConformityId: _nc?.id ?? '',
      solutionText: '',
      priority: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _solutions.add(newSolution);
      _solutionControllers[tempId] = TextEditingController();
    });
  }

  void _removeSolution(String solutionId) {
    setState(() {
      _solutions.removeWhere((s) => s.id == solutionId);
      _solutionControllers[solutionId]?.dispose();
      _solutionControllers.remove(solutionId);
    });
  }

  ExpansionPanelRadio _buildSection7() {
    return ExpansionPanelRadio(
      value: 6,
      headerBuilder: (context, isExpanded) => ListTile(
        title: const Text('7. Plan d\'action'),
        leading: const Icon(Icons.checklist),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addAction,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _actions.isEmpty
            ? const Center(child: Text('Aucune action ajoutée'))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _actions.length,
                itemBuilder: (context, index) {
                  final action = _actions[index];
                  return _buildActionItem(action, index);
                },
              ),
      ),
    );
  }

  Widget _buildActionItem(NCAction action, int index) {
    final controller =
        _actionControllers[action.id] ??
        TextEditingController(text: action.actionText);
    _actionControllers[action.id] = controller;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _actionResponsibleIds[action.id],
                    decoration: const InputDecoration(
                      labelText: 'Responsable',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sélectionner...'),
                      ),
                      ..._employees.map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.fullName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _actionResponsibleIds[action.id] = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            _actionTargetDates[action.id] ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _actionTargetDates[action.id] = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _actionTargetDates[action.id] != null
                          ? DateFormat(
                              'dd/MM/yyyy',
                            ).format(_actionTargetDates[action.id]!)
                          : 'Date cible',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<NCActionStatus>(
                    value: action.status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: NCActionStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          final idx = _actions.indexWhere(
                            (a) => a.id == action.id,
                          );
                          if (idx != -1) {
                            _actions[idx] = NCAction(
                              id: action.id,
                              nonConformityId: action.nonConformityId,
                              actionText: action.actionText,
                              responsibleEmployeeId:
                                  action.responsibleEmployeeId,
                              targetDate: action.targetDate,
                              status: value,
                              createdAt: action.createdAt,
                              updatedAt: action.updatedAt,
                              orderIndex: action.orderIndex,
                            );
                          }
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeAction(action.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addAction() {
    final tempId = 'temp_action_${DateTime.now().millisecondsSinceEpoch}';
    final newAction = NCAction(
      id: tempId,
      nonConformityId: _nc?.id ?? '',
      actionText: '',
      status: NCActionStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _actions.add(newAction);
      _actionControllers[tempId] = TextEditingController();
      _actionResponsibleIds[tempId] = null;
      _actionTargetDates[tempId] = null;
    });
  }

  void _removeAction(String actionId) {
    setState(() {
      _actions.removeWhere((a) => a.id == actionId);
      _actionControllers[actionId]?.dispose();
      _actionControllers.remove(actionId);
      _actionResponsibleIds.remove(actionId);
      _actionTargetDates.remove(actionId);
    });
  }

  ExpansionPanelRadio _buildSection8() {
    return ExpansionPanelRadio(
      value: 7,
      headerBuilder: (context, isExpanded) => ListTile(
        title: const Text('8. Vérification de mise en œuvre'),
        leading: const Icon(Icons.verified),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addVerification,
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _addAttachment,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_verifications.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _verifications.length,
                itemBuilder: (context, index) {
                  final verification = _verifications[index];
                  return _buildVerificationItem(verification, index);
                },
              ),
            if (_attachments.isNotEmpty || _newAttachmentFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Pièces jointes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._attachments.map(
                (att) => ListTile(
                  leading: const Icon(Icons.attachment),
                  title: Text(att.fileName),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeAttachment(att.id),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationItem(NCVerification verification, int index) {
    final actionController =
        _verificationControllers[verification.id] ??
        TextEditingController(text: verification.actionVerified ?? '');
    _verificationControllers[verification.id] = actionController;

    final resultController =
        _verificationResultControllers[verification.id] ??
        TextEditingController(text: verification.result ?? '');
    _verificationResultControllers[verification.id] = resultController;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: actionController,
              decoration: const InputDecoration(
                labelText: 'Action vérifiée',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: verification.responsibleEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Responsable',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sélectionner...'),
                      ),
                      ..._employees.map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.fullName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        final idx = _verifications.indexWhere(
                          (v) => v.id == verification.id,
                        );
                        if (idx != -1) {
                          _verifications[idx] = NCVerification(
                            id: verification.id,
                            nonConformityId: verification.nonConformityId,
                            actionVerified: verification.actionVerified,
                            responsibleEmployeeId: value,
                            result: verification.result,
                            verificationDate: verification.verificationDate,
                            createdAt: verification.createdAt,
                            updatedAt: verification.updatedAt,
                            orderIndex: verification.orderIndex,
                          );
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            verification.verificationDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          final idx = _verifications.indexWhere(
                            (v) => v.id == verification.id,
                          );
                          if (idx != -1) {
                            _verifications[idx] = NCVerification(
                              id: verification.id,
                              nonConformityId: verification.nonConformityId,
                              actionVerified: verification.actionVerified,
                              responsibleEmployeeId:
                                  verification.responsibleEmployeeId,
                              result: verification.result,
                              verificationDate: date,
                              createdAt: verification.createdAt,
                              updatedAt: verification.updatedAt,
                              orderIndex: verification.orderIndex,
                            );
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      verification.verificationDate != null
                          ? DateFormat(
                              'dd/MM/yyyy',
                            ).format(verification.verificationDate!)
                          : 'Date',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeVerification(verification.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: resultController,
              decoration: const InputDecoration(
                labelText: 'Résultat',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _addVerification() {
    final tempId = 'temp_verification_${DateTime.now().millisecondsSinceEpoch}';
    final newVerification = NCVerification(
      id: tempId,
      nonConformityId: _nc?.id ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _verifications.add(newVerification);
      _verificationControllers[tempId] = TextEditingController();
      _verificationResultControllers[tempId] = TextEditingController();
    });
  }

  void _removeVerification(String verificationId) {
    setState(() {
      _verifications.removeWhere((v) => v.id == verificationId);
      _verificationControllers[verificationId]?.dispose();
      _verificationControllers.remove(verificationId);
      _verificationResultControllers[verificationId]?.dispose();
      _verificationResultControllers.remove(verificationId);
    });
  }

  Future<void> _addAttachment() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newAttachmentFiles.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _removeAttachment(String attachmentId) async {
    try {
      await _ncRepo.deleteAttachment(attachmentId);
      setState(() {
        _attachments.removeWhere((a) => a.id == attachmentId);
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }
}
