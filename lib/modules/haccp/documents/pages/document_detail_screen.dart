/// Document Detail Screen
///
/// View and download document details

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../repositories/documents_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import '../models.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _documentsRepo = DocumentsRepository();
  final _networkService = NetworkService();
  final _authService = AuthService();
  final _supabase = SupabaseService();

  Document? _document;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadDocument();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final userRole = await _authService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _isAdmin = userRole.isAdmin;
        });
      }
    } catch (e) {
      debugPrint('[DocumentDetail] Error checking admin status: $e');
    }
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final data = await _documentsRepo.fetchById(widget.documentId);
      if (data != null) {
        setState(() {
          _document = Document.fromJson(data);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Document introuvable')));
          Navigator.pop(context);
        }
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openDocument() async {
    if (_document?.storageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL du document non disponible')),
      );
      return;
    }

    try {
      String documentUrl = _document!.storageUrl!;
      debugPrint('[DocumentDetail] Original storageUrl: $documentUrl');

      // Si l'URL est déjà une URL complète (http/https), l'utiliser directement
      if (documentUrl.startsWith('http://') ||
          documentUrl.startsWith('https://')) {
        final url = Uri.parse(documentUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Sinon, c'est un chemin relatif - obtenir l'URL publique
      try {
        final publicUrl = _supabase.client.storage
            .from('documents')
            .getPublicUrl(documentUrl);
        debugPrint('[DocumentDetail] Public URL: $publicUrl');

        final url = Uri.parse(publicUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint('[DocumentDetail] Error getting public URL: $e');
      }

      // Si l'URL publique ne fonctionne pas, essayer avec une URL signée
      try {
        final signedUrl = await _supabase.client.storage
            .from('documents')
            .createSignedUrl(documentUrl, 3600); // URL valide 1 heure
        debugPrint('[DocumentDetail] Signed URL: $signedUrl');

        final signedUri = Uri.parse(signedUrl);
        if (await canLaunchUrl(signedUri)) {
          await launchUrl(signedUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint('[DocumentDetail] Error getting signed URL: $e');
      }

      // Si tout échoue
      throw Exception('Impossible d\'ouvrir le document');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('[DocumentDetail] Error opening document: $e');
    }
  }

  Future<void> _downloadDocument() async {
    // Same as open for now - could be enhanced with actual download
    await _openDocument();
  }

  Future<void> _editDocument() async {
    if (_document == null) return;

    final location = GoRouterState.of(context).matchedLocation;
    final result = await context.push<bool>(
      location.startsWith('/admin')
          ? '/admin/documents/${widget.documentId}/edit'
          : '/app/documents/${widget.documentId}/edit',
      extra: _document,
    );

    if (result == true) {
      // Reload document after edit
      _loadDocument();
    }
  }

  Future<void> _deleteDocument() async {
    if (_document == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce document ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final hasConnection = await _networkService.hasConnection();
      if (!hasConnection) {
        throw NetworkException('Network required');
      }

      // Extract storage path from chemin
      final storagePath = _document!.storageUrl;

      await _documentsRepo.deleteDocument(widget.documentId, storagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document supprimé avec succès')),
        );
        context.pop(true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e is AppException ? e.message : e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Retour',
          ),
          title: const Text('Détails du document'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Retour',
          ),
          title: const Text('Détails du document'),
        ),
        body: const Center(child: Text('Document introuvable')),
      );
    }

    final doc = _document!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Retour',
        ),
        title: const Text('Détails du document'),
        actions: [
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editDocument,
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteDocument,
              tooltip: 'Supprimer',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openDocument,
            tooltip: 'Ouvrir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              doc.displayTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getCategoryColor(doc.category).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getCategoryColor(doc.category),
                  width: 1.5,
                ),
              ),
              child: Text(
                doc.category.displayName,
                style: TextStyle(
                  color: _getCategoryColor(doc.category),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Details
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Date du document',
              value: doc.documentDate != null
                  ? _formatDate(doc.documentDate!)
                  : 'Non spécifiée',
            ),
            if (doc.taille != null)
              _DetailRow(
                icon: Icons.storage,
                label: 'Taille',
                value: '${(doc.taille! / 1024).toStringAsFixed(2)} KB',
              ),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Créé le',
              value: _formatDateTime(doc.createdAt),
            ),

            if (doc.notes != null && doc.notes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Notes',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(doc.notes!),
              ),
            ],

            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openDocument,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadDocument,
                    icon: const Icon(Icons.download),
                    label: const Text('Télécharger'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.microBio:
        return Colors.blue;
      case DocumentCategory.pestControl:
        return Colors.orange;
      case DocumentCategory.complianceAudit:
        return Colors.green;
      case DocumentCategory.other:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
