import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_document_scanner/flutter_document_scanner.dart';
import '../../../../repositories/documents_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../services/cache_service.dart';
import '../../../../exceptions/app_exceptions.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _documentsRepo = DocumentsRepository();
  final _networkService = NetworkService();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _documents = [];
  bool _isOnline = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadDocuments();
    _networkService.connectivityStream.listen((_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    final isOnline = await _networkService.hasConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      // Try cache first
      final cached = CacheService().get('documents_all');
      if (cached != null) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(cached);
        });
      }

      // Load from Supabase
      final documents = await _documentsRepo.getAll();
      if (mounted) {
        setState(() {
          _documents = documents;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _ajouterFichier() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network required')));
      return;
    }

    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        final pickedFile = File(result.files.single.path!);
        final fileName =
            '${const Uuid().v4()}_${path.basename(pickedFile.path)}';

        // Upload to Supabase Storage
        final storageUrl = await _documentsRepo.uploadFile(
          pickedFile,
          fileName,
        );

        // Create document record
        await _documentsRepo.createDocument(
          nom: path.basename(pickedFile.path),
          categorie: _getCategoryFromExtension(path.extension(pickedFile.path)),
          storageUrl: storageUrl,
          taille: await pickedFile.length(),
        );

        await _loadDocuments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier ajouté avec succès')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _getCategoryFromExtension(String ext) {
    final imageExts = ['.jpg', '.jpeg', '.png', '.gif'];
    final pdfExts = ['.pdf'];
    if (imageExts.contains(ext.toLowerCase())) return 'Image';
    if (pdfExts.contains(ext.toLowerCase())) return 'PDF';
    return 'Autre';
  }

  Future<void> _ajouterPhoto({required ImageSource source}) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network required')));
      return;
    }

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

          // Upload to Supabase Storage
          final storageUrl = await _documentsRepo.uploadFile(
            imageFile,
            fileName,
          );

          // Create document record
          await _documentsRepo.createDocument(
            nom: path.basename(photo.path),
            categorie: 'Image',
            storageUrl: storageUrl,
            taille: await imageFile.length(),
          );

          await _loadDocuments();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo ajoutée avec succès')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: ${e is AppException ? e.message : e.toString()}',
              ),
            ),
          );
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout de la photo: $e')),
      );
    }
  }

  Future<void> _scannerDocument() async {
    try {
      final scannedPath = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentScanPage()),
      );
      if (scannedPath != null && scannedPath is String) {
        final File scannedFile = File(scannedPath);
        final dir = await getApplicationDocumentsDirectory();
        final newName =
            '${const Uuid().v4()}_scanned_document${path.extension(scannedFile.path)}';
        final newFile = await scannedFile.copy('${dir.path}/$newName');
        await _loadDocuments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document scanné ajouté : ${path.basename(newFile.path)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du scan : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _supprimerFichier(Map<String, dynamic> document) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network required')));
      return;
    }

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
      final storagePath = document['chemin'] as String?;
      await _documentsRepo.deleteDocument(
        document['id'] as String,
        storagePath,
      );
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document supprimé')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _previsualiserFichier(Map<String, dynamic> document) async {
    try {
      final storageUrl = document['chemin'] as String?;
      if (storageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL du document non disponible')),
        );
        return;
      }

      // Open URL in browser or download and open
      // For now, show a dialog with the URL
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(document['nom'] as String? ?? 'Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('URL: $storageUrl'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // TODO: Open URL or download file
                  Navigator.pop(ctx);
                },
                child: const Text('Télécharger'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFileOptions(Map<String, dynamic> document) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: Colors.blue),
              title: Text('Prévisualiser'),
              onTap: () {
                Navigator.pop(context);
                _previsualiserFichier(document);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green),
              title: Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implémenter le partage
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Supprimer'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(document);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${document['nom']}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerFichier(document);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Ajouter un fichier'),
              onTap: () {
                Navigator.pop(context);
                _ajouterFichier();
              },
            ),
            ListTile(
              leading: Icon(Icons.document_scanner, color: Colors.blue),
              title: Text('Scanner un document'),
              subtitle: Text('Numériser avec l\'appareil photo'),
              onTap: () {
                Navigator.pop(context);
                _scannerDocument();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _ajouterPhoto(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choisir une photo'),
              onTap: () {
                Navigator.pop(context);
                _ajouterPhoto(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          "Documents Clients",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isOnline ? _showAddMenu : null,
        tooltip: _isOnline ? 'Ajouter' : 'Network required',
        backgroundColor: _isOnline ? Colors.blue.shade600 : Colors.grey,
        child: Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucun document',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isOnline
                        ? 'Appuyez sur + pour ajouter des documents'
                        : 'Network required to load documents',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _documents.length,
              itemBuilder: (_, index) {
                final document = _documents[index];
                final fileName = document['nom'] as String? ?? 'Document';
                final fileSize = document['taille'] as int? ?? 0;
                final dateStr = document['date'] as String?;
                final fileDate = dateStr != null
                    ? DateTime.parse(dateStr)
                    : DateTime.now();

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getFileColor(fileName).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getFileIcon(fileName),
                        color: _getFileColor(fileName),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      fileName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          '${_formatFileSize(fileSize)} • ${_formatDate(fileDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'preview':
                            _previsualiserFichier(document);
                            break;
                          case 'share':
                            // TODO: Implémenter le partage
                            break;
                          case 'delete':
                            _showDeleteConfirmation(document);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('Prévisualiser'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text('Partager'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Supprimer'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _previsualiserFichier(document),
                  ),
                );
              },
            ),
    );
  }

  IconData _getFileIcon(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if ([".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"].contains(ext)) {
      return Icons.photo;
    } else if ([".pdf"].contains(ext)) {
      return Icons.picture_as_pdf;
    } else if ([".doc", ".docx"].contains(ext)) {
      return Icons.description;
    } else if ([".xls", ".xlsx"].contains(ext)) {
      return Icons.table_chart;
    } else if ([".txt"].contains(ext)) {
      return Icons.text_snippet;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if ([".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"].contains(ext)) {
      return Colors.green;
    } else if ([".pdf"].contains(ext)) {
      return Colors.red;
    } else if ([".doc", ".docx"].contains(ext)) {
      return Colors.blue;
    } else if ([".xls", ".xlsx"].contains(ext)) {
      return Colors.green.shade700;
    } else if ([".txt"].contains(ext)) {
      return Colors.grey;
    } else {
      return Colors.blueGrey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class DocumentScanPage extends StatelessWidget {
  const DocumentScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner un document'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: DocumentScanner(
        onSave: (Uint8List scannedImageData) async {
          try {
            // Créer un fichier temporaire avec les données scannées
            final dir = await getApplicationDocumentsDirectory();
            final fileName = '${const Uuid().v4()}_scanned_document.jpg';
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(scannedImageData);

            // Retourner le chemin du fichier scanné
            Navigator.pop(context, file.path);
          } catch (e) {
            // En cas d'erreur, retourner null
            Navigator.pop(context, null);
          }
        },
      ),
    );
  }
}
