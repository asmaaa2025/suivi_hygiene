/// Document Edit Screen
///
/// Edit document metadata (title, category, date, notes)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../repositories/documents_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../exceptions/app_exceptions.dart';
import '../models.dart';

class DocumentEditScreen extends StatefulWidget {
  final String documentId;
  final Document document;

  const DocumentEditScreen({
    super.key,
    required this.documentId,
    required this.document,
  });

  @override
  State<DocumentEditScreen> createState() => _DocumentEditScreenState();
}

class _DocumentEditScreenState extends State<DocumentEditScreen> {
  final _documentsRepo = DocumentsRepository();
  final _networkService = NetworkService();
  final _formKey = GlobalKey<FormState>();

  late DocumentCategory _category;
  late TextEditingController _titleController;
  DateTime? _documentDate;
  late TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.document.category;
    _titleController = TextEditingController(
      text: widget.document.title ?? widget.document.nom,
    );
    _documentDate = widget.document.documentDate;
    _notesController = TextEditingController(text: widget.document.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _documentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _documentDate = picked;
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate: document_date is required for compliance categories
    if (_category.isComplianceCategory && _documentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La date du document est requise pour les catégories de conformité',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final hasConnection = await _networkService.hasConnection();
      if (!hasConnection) {
        throw NetworkException('Network required');
      }

      await _documentsRepo.updateDocument(
        id: widget.documentId,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        category: _category,
        documentDate: _documentDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document modifié avec succès')),
        );
        context.pop(true); // Return true to indicate success
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Retour',
        ),
        title: const Text('Modifier le document'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File info (read-only)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.document.nom,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category
              DropdownButtonFormField<DocumentCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Catégorie *',
                  border: OutlineInputBorder(),
                ),
                items: DocumentCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Titre du document',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Document date
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _documentDate != null
                      ? 'Date: ${_formatDate(_documentDate!)}'
                      : _category.isComplianceCategory
                      ? 'Date du document *'
                      : 'Date du document',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (_category.isComplianceCategory && _documentDate == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'La date est requise pour les catégories de conformité',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Notes supplémentaires',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveDocument,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
