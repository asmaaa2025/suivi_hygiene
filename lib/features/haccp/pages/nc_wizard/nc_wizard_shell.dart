/// NC Wizard Shell
/// 
/// Main container for multi-step NC form wizard
/// Manages state, navigation, and autosave

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bekkapp/core/theme/app_theme.dart';
import 'package:bekkapp/data/repositories/organization_repository.dart';
import 'package:bekkapp/data/repositories/nc_repository.dart';
import 'package:bekkapp/data/models/nc_models.dart';
import 'package:bekkapp/services/employee_session_service.dart';
import 'models/nc_draft_model.dart';
import 'services/nc_draft_repository.dart';
import 'steps/nc_wizard_step1_identification.dart';
import 'steps/nc_wizard_step2_constat.dart';
import 'steps/nc_wizard_step3_causes.dart';
import 'steps/nc_wizard_step4_actions_immediates.dart';
import 'steps/nc_wizard_step5_actions_preventives.dart';
import 'steps/nc_wizard_step6_preuves.dart';
import 'steps/nc_wizard_step7_signature.dart';
import 'steps/nc_wizard_review.dart';

class NcWizardShell extends StatefulWidget {
  final Map<String, dynamic>? prefillData;

  const NcWizardShell({
    super.key,
    this.prefillData,
  });

  @override
  State<NcWizardShell> createState() => _NcWizardShellState();
}

class _NcWizardShellState extends State<NcWizardShell> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final NcDraftRepository _draftRepo = NcDraftRepository();
  final NCRepository _ncRepo = NCRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final EmployeeSessionService _employeeSession = EmployeeSessionService();
  
  NcDraft? _draft;
  String? _supabaseNcId; // Track Supabase NC ID for draft updates
  int _currentStep = 0;
  final int _totalSteps = 7;
  bool _isLoading = true;
  bool _isCheckingDraft = true; // Show dialog to resume or create new
  String? _organizationId;
  String? _employeeId;
  
  // Form keys for each step
  final List<GlobalKey<FormState>> _formKeys = List.generate(7, (_) => GlobalKey<FormState>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _autosave();
    }
  }

  Future<void> _initializeDraft({bool createNew = false}) async {
    setState(() => _isLoading = true);
    
    try {
      _organizationId = await _orgRepo.getOrCreateOrganization();
      _employeeId = await _employeeSession.getCurrentEmployeeId();
      
      // Try to load existing draft (unless creating new)
      NcDraft? existingDraft;
      if (!createNew) {
        existingDraft = await _draftRepo.loadDraft(_organizationId!, _employeeId);
      }
      
      if (existingDraft != null && !createNew) {
        // Show dialog to resume or create new
        if (mounted && existingDraft.hasData) {
          final shouldResume = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Brouillon trouvé'),
              content: const Text('Un brouillon de non-conformité existe. Voulez-vous le reprendre ou créer un nouveau formulaire ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Nouveau formulaire'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reprendre le brouillon'),
                ),
              ],
            ),
          );
          
          if (shouldResume == true) {
            _draft = existingDraft;
            debugPrint('[NcWizard] Resuming existing draft');
          } else {
            // Create new draft - clear everything
            await _draftRepo.clearDrafts(_organizationId!, _employeeId);
            
            // Find and delete Supabase draft if it exists
            try {
              final draftNCs = await _ncRepo.listNonConformities(
                status: NCStatus.draft,
              );
              
              // Find draft created by current employee (most recent first)
              final employeeDrafts = draftNCs.where(
                (nc) => nc.createdBy == _employeeId,
              ).toList();
              
              if (employeeDrafts.isNotEmpty) {
                // Delete the most recent draft (or all if multiple)
                for (final draft in employeeDrafts) {
                  await _ncRepo.deleteNonConformity(draft.id);
                  debugPrint('[NcWizard] Deleted Supabase draft: ${draft.id}');
                }
              }
            } catch (e) {
              // No draft found or error - that's okay, continue
              debugPrint('[NcWizard] No Supabase draft to delete: $e');
            }
            
            // Reset wizard state
            _currentStep = 0;
            _supabaseNcId = null;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
            
            // Create fresh draft
            _draft = NcDraft(
              organizationId: _organizationId!,
              employeeId: _employeeId,
              detectionDate: DateTime.now(),
            );
            
            setState(() {
              _isLoading = false;
              _isCheckingDraft = false;
            });
            
            debugPrint('[NcWizard] Created new draft (ignoring existing)');
          }
        } else {
          _draft = existingDraft;
          debugPrint('[NcWizard] Loaded existing draft');
        }
      } else {
        // Create new draft
        _draft = NcDraft(
          organizationId: _organizationId!,
          employeeId: _employeeId,
          detectionDate: DateTime.now(),
        );
        debugPrint('[NcWizard] Created new draft');
      }
      
      // Apply prefill data if provided
      if (widget.prefillData != null) {
        _applyPrefillData(widget.prefillData!);
      }
      
      setState(() {
        _isLoading = false;
        _isCheckingDraft = false;
      });
    } catch (e) {
      debugPrint('[NcWizard] Error initializing: $e');
      setState(() {
        _isLoading = false;
        _isCheckingDraft = false;
      });
    }
  }

  void _applyPrefillData(Map<String, dynamic> prefill) {
    if (_draft == null) return;

    // Map source_type (technical: "temperature", "reception"...) to ncType (display: "Température", "Réception"...)
    // Dropdown expects display values, otherwise Flutter throws "no matching DropdownMenuItem"
    final sourceType = prefill['source_type']?.toString();
    final ncType = _sourceTypeToNcTypeDisplay(sourceType);

    // Parse detection date from source_payload if available
    DateTime? detectionDate;
    final payload = prefill['source_payload'] as Map<String, dynamic>?;
    if (payload != null && payload['reading_date'] != null) {
      detectionDate = DateTime.tryParse(payload['reading_date'].toString());
    }

    setState(() {
      _draft = _draft!.copyWith(
        ncType: ncType ?? _draft!.ncType,
        shortDescription: prefill['description']?.toString() ?? _draft!.shortDescription,
        detailedDescription: prefill['description']?.toString() ?? _draft!.detailedDescription,
        detectionDate: detectionDate ?? _draft!.detectionDate,
      );
    });
  }

  /// Map technical source_type to display label for dropdown
  String? _sourceTypeToNcTypeDisplay(String? sourceType) {
    if (sourceType == null) return null;
    switch (sourceType.toLowerCase()) {
      case 'temperature':
        return 'Température';
      case 'reception':
        return 'Réception';
      case 'oil':
        return 'Huile';
      case 'cleaning':
        return 'Nettoyage';
      default:
        return null;
    }
  }

  Future<void> _autosave() async {
    if (_draft == null || _organizationId == null || _employeeId == null) return;
    
    try {
      // Save to local SQLite
      await _draftRepo.saveDraft(_draft!);
      
      // Also save to Supabase (for history visibility)
      // Convert draft to Supabase format
      final draftData = <String, dynamic>{
        'detection_date': _draft!.detectionDate.toIso8601String(),
        'description': _draft!.shortDescription ?? _draft!.detailedDescription ?? 'Brouillon de non-conformité',
        'object_category': _mapNcTypeToObjectCategory(_draft!.ncType),
      };
      
      if (_draft!.ncType != null) {
        draftData['source_type'] = _mapNcTypeToSourceType(_draft!.ncType);
      }
      
      final supabaseId = await _ncRepo.saveDraftToSupabase(
        organizationId: _organizationId!,
        employeeId: _employeeId!,
        draftData: draftData,
        existingNcId: _supabaseNcId,
      );
      
      if (supabaseId != null) {
        _supabaseNcId = supabaseId;
      }
      
      debugPrint('[NcWizard] ✅ Autosaved draft (local + Supabase)');
    } catch (e) {
      debugPrint('[NcWizard] ❌ Error autosaving: $e');
    }
  }
  
  String _mapNcTypeToObjectCategory(String? ncType) {
    // Map NC type to object category
    switch (ncType) {
      case 'Température':
        return NCObjectCategory.chaineDuFroid.value;
      case 'Réception':
        return NCObjectCategory.reclamationClient.value;
      case 'Nettoyage':
        return NCObjectCategory.nettoyageDesinfection.value;
      case 'Huile':
        return NCObjectCategory.maintenance.value;
      default:
        return NCObjectCategory.autre.value;
    }
  }
  
  String? _mapNcTypeToSourceType(String? ncType) {
    switch (ncType) {
      case 'Température':
        return NCSourceType.temperature.value;
      case 'Réception':
        return NCSourceType.reception.value;
      case 'Nettoyage':
        return NCSourceType.cleaning.value;
      case 'Huile':
        return NCSourceType.oil.value;
      default:
        return null;
    }
  }

  void _updateDraft(NcDraft Function(NcDraft) updater) {
    if (_draft == null) return;
    setState(() {
      _draft = updater(_draft!);
    });
    // Autosave asynchronously to not block UI
    _autosave();
  }

  Future<void> _goToNextStep() async {
    // Validate current step
    if (_currentStep < _formKeys.length) {
      final formKey = _formKeys[_currentStep];
      if (formKey.currentState != null && !formKey.currentState!.validate()) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez remplir tous les champs requis'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Don't proceed if validation fails
      }
    }
    
    // Special validation for step 7
    if (_currentStep == 6 && _draft != null) {
      if (_draft!.status == 'Clôturée') {
        final hasFinalComment = _draft!.finalComment != null && _draft!.finalComment!.isNotEmpty;
        final hasImmediateAction = _draft!.immediateAction != null && _draft!.immediateAction!.isNotEmpty;
        if (!hasFinalComment && !hasImmediateAction) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pour clôturer, veuillez remplir le commentaire final ou au moins une action corrective'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    }
    
    // Autosave before moving
    await _autosave();
    
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      // Last step - go to review
      _navigateToReview();
    }
  }

  void _navigateToHaccpHub() {
    final isAdminRoute = GoRouterState.of(context).matchedLocation.startsWith('/admin');
    final prefix = isAdminRoute ? '/admin' : '/app';
    context.go('$prefix/haccp-hub');
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      _navigateToHaccpHub();
    }
  }

  void _navigateToReview() {
    final prefix = GoRouterState.of(context).matchedLocation.startsWith('/admin') ? '/admin' : '/app';
    context.push('$prefix/alerts/nc/review', extra: _draft!);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isCheckingDraft || _draft == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Formulaire non-conformité'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            // Autosave before leaving
            await _autosave();
            
            // Show confirmation if draft has data
            if (_draft!.hasData) {
              if (!mounted) return;
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Quitter le formulaire ?'),
                  content: const Text('Vos modifications seront sauvegardées automatiquement. Vous pourrez reprendre ce brouillon plus tard.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Quitter'),
                    ),
                  ],
                ),
              );
              if (shouldLeave == true && mounted) {
                _navigateToHaccpHub();
              }
            } else {
              _navigateToHaccpHub();
            }
          },
        ),
        title: const Text('Formulaire non-conformité'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Étape ${_currentStep + 1}/$_totalSteps',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${((_currentStep + 1) / _totalSteps * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  minHeight: 8,
                ),
              ],
            ),
          ),
          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                // Step 1: Identification
                NcWizardStep1Identification(
                  formKey: _formKeys[0],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
                // Step 2: Constat
                NcWizardStep2Constat(
                  formKey: _formKeys[1],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
                // Step 3: Causes
                NcWizardStep3Causes(
                  formKey: _formKeys[2],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
                // Step 4: Actions immédiates
                NcWizardStep4ActionsImmediates(
                  formKey: _formKeys[3],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
                // Step 5: Actions préventives
                NcWizardStep5ActionsPreventives(
                  formKey: _formKeys[4],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
                // Step 6: Preuves
                NcWizardStep6Preuves(
                  formKey: _formKeys[5],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
                // Step 7: Signature
                NcWizardStep7Signature(
                  formKey: _formKeys[6],
                  draft: _draft!,
                  onDraftChanged: _updateDraft,
                ),
              ],
            ),
          ),
          // Navigation buttons
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentStep > 0 ? _goToPreviousStep : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Précédent'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _goToNextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_currentStep == _totalSteps - 1 ? 'Révision' : 'Suivant'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

