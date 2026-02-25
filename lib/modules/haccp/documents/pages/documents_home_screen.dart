import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import '../../../../repositories/documents_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../services/employee_session_service.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../models.dart';
import '../../compliance/compliance_repository.dart';
import '../../compliance/compliance_service.dart';
import '../widgets/compliance_status_panel.dart';

class DocumentsHomeScreen extends StatefulWidget {
  const DocumentsHomeScreen({super.key});

  @override
  State<DocumentsHomeScreen> createState() => _DocumentsHomeScreenState();
}

class _DocumentsHomeScreenState extends State<DocumentsHomeScreen> {
  final _documentsRepo = DocumentsRepository();
  final _complianceRepo = ComplianceRepository();
  final _networkService = NetworkService();
  final _employeeSession = EmployeeSessionService();
  final _orgRepo = OrganizationRepository();
  final ImagePicker _picker = ImagePicker();

  List<Document> _documents = [];
  List<ComplianceStatusInfo> _complianceStatuses = [];
  bool _isLoading = true;
  bool _isOnline = true;
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkNetwork();
    await _resolveOrganizationId();
    await Future.wait([_loadDocuments(), _loadComplianceStatuses()]);
  }

  Future<void> _checkNetwork() async {
    final isOnline = await _networkService.hasConnection();
    if (mounted) setState(() => _isOnline = isOnline);
  }

  Future<void> _resolveOrganizationId() async {
    try {
      await _employeeSession.initialize();
      final employee = _employeeSession.currentEmployee;
      if (employee != null) {
        _organizationId = employee.organizationId;
      } else {
        _organizationId = await _orgRepo.getOrCreateOrganization();
      }
    } catch (e) {
      debugPrint('[DocumentsHome] Error resolving org ID: $e');
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final raw = await _documentsRepo.getAll();
      if (mounted) {
        setState(() {
          _documents = raw.map((json) => Document.fromJson(json)).toList();
          _documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadComplianceStatuses() async {
    if (_organizationId == null) return;
    try {
      final requirements = await _complianceRepo.getRequirements(
        _organizationId!,
      );
      final events = await _complianceRepo.getEvents(_organizationId!);

      final statuses = requirements.map((req) {
        return ComplianceService.calculateStatus(req, events);
      }).toList();

      if (mounted) {
        setState(() => _complianceStatuses = statuses);
      }
    } catch (e) {
      debugPrint('[DocumentsHome] Error loading compliance: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _checkNetwork();
    await Future.wait([_loadDocuments(), _loadComplianceStatuses()]);
  }

  void _onComplianceUpload(ComplianceStatusInfo status) {
    _showAddMenu(preselectedCategory: status.requirement.code);
  }

  /// Ask the user for the document date
  Future<DateTime?> _pickDocumentDate() async {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date du document',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
  }

  /// Create a compliance event after uploading a document for a compliance category
  Future<void> _createComplianceEvent(String requirementCode, {DateTime? eventDate}) async {
    if (_organizationId == null) return;
    try {
      // Find the matching requirement
      final match = _complianceStatuses
          .where((s) => s.requirement.code == requirementCode)
          .toList();
      if (match.isEmpty) return;

      await _complianceRepo.createEvent(
        organizationId: _organizationId!,
        requirementId: match.first.requirement.id,
        eventDate: eventDate ?? DateTime.now(),
      );
      debugPrint('[DocumentsHome] Compliance event created for $requirementCode');
    } catch (e) {
      debugPrint('[DocumentsHome] Error creating compliance event: $e');
    }
  }

  Future<void> _ajouterFichier({String? preselectedCategory}) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion réseau requise')),
      );
      return;
    }

    // Ask for document date first
    final documentDate = await _pickDocumentDate();
    if (documentDate == null || !mounted) return;

    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        final pickedFile = File(result.files.single.path!);
        final fileName =
            '${const Uuid().v4()}_${path.basename(pickedFile.path)}';

        final storageUrl = await _documentsRepo.uploadFile(
          pickedFile,
          fileName,
        );

        final categorie = preselectedCategory ??
            _getCategoryFromExtension(path.extension(pickedFile.path));

        await _documentsRepo.createDocument(
          nom: path.basename(pickedFile.path),
          categorie: categorie,
          storageUrl: storageUrl,
          taille: await pickedFile.length(),
          documentDate: documentDate,
        );

        // Create compliance event if it's a compliance category
        if (preselectedCategory != null) {
          await _createComplianceEvent(preselectedCategory, eventDate: documentDate);
        }

        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier ajouté avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: ${e is AppException ? e.message : e.toString()}',
              ),
            ),
          );
        }
      }
    }
  }

  String _getCategoryFromExtension(String ext) {
    final imageExts = ['.jpg', '.jpeg', '.png', '.gif'];
    final pdfExts = ['.pdf'];
    if (imageExts.contains(ext.toLowerCase())) return 'Image';
    if (pdfExts.contains(ext.toLowerCase())) return 'PDF';
    return 'other';
  }

  Future<void> _ajouterPhoto({
    required ImageSource source,
    String? preselectedCategory,
  }) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion réseau requise')),
      );
      return;
    }

    // Ask for document date first
    final documentDate = await _pickDocumentDate();
    if (documentDate == null || !mounted) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (photo != null) {
        setState(() => _isLoading = true);
        try {
          final File imageFile = File(photo.path);
          final fileName =
              '${const Uuid().v4()}_photo${path.extension(photo.path)}';

          final storageUrl = await _documentsRepo.uploadFile(
            imageFile,
            fileName,
          );

          await _documentsRepo.createDocument(
            nom: path.basename(photo.path),
            categorie: preselectedCategory ?? 'Image',
            storageUrl: storageUrl,
            taille: await imageFile.length(),
            documentDate: documentDate,
          );

          // Create compliance event if it's a compliance category
          if (preselectedCategory != null) {
            await _createComplianceEvent(preselectedCategory, eventDate: documentDate);
          }

          await _refresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo ajoutée avec succès')),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erreur: ${e is AppException ? e.message : e.toString()}',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout de la photo: $e'),
          ),
        );
      }
    }
  }

  void _showAddMenu({String? preselectedCategory}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (preselectedCategory != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ajouter un document: $preselectedCategory',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Ajouter un fichier'),
              onTap: () {
                Navigator.pop(ctx);
                _ajouterFichier(preselectedCategory: preselectedCategory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _ajouterPhoto(
                  source: ImageSource.camera,
                  preselectedCategory: preselectedCategory,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _ajouterPhoto(
                  source: ImageSource.gallery,
                  preselectedCategory: preselectedCategory,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDocument(Document doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Supprimer ce document ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _documentsRepo.deleteDocument(doc.id, doc.storageUrl);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document supprimé')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents HACCP'),
        backgroundColor: Colors.purple.shade300,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('$routePrefix/haccp'),
          tooltip: 'Retour',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isOnline ? () => _showAddMenu() : null,
        tooltip: _isOnline ? 'Ajouter' : 'Connexion requise',
        backgroundColor: _isOnline ? Colors.purple.shade300 : Colors.grey,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Compliance status panel (3 cards)
                  if (_complianceStatuses.isNotEmpty)
                    ComplianceStatusPanel(
                      statuses: _complianceStatuses,
                      onUpload: _onComplianceUpload,
                    ),

                  if (_complianceStatuses.isNotEmpty)
                    const SizedBox(height: 24),

                  // Documents list header
                  Text(
                    'Documents (${_documents.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_documents.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun document',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isOnline
                                  ? 'Appuyez sur + pour ajouter'
                                  : 'Connexion requise',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._documents.map(
                      (doc) => _buildDocumentItem(context, doc, routePrefix),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context,
    Document doc,
    String routePrefix,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getFileColor(doc.nom).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFileIcon(doc.nom),
            color: _getFileColor(doc.nom),
            size: 22,
          ),
        ),
        title: Text(
          doc.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${doc.category.displayName} • ${_formatDate(doc.createdAt)}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _deleteDocument(doc),
          color: Colors.red.shade300,
        ),
        onTap: () => context.push('$routePrefix/documents/${doc.id}'),
      ),
    );
  }

  IconData _getFileIcon(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) return Icons.photo;
    if (['.pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['.doc', '.docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) return Colors.green;
    if (['.pdf'].contains(ext)) return Colors.red;
    if (['.doc', '.docx'].contains(ext)) return Colors.blue;
    return Colors.blueGrey;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
