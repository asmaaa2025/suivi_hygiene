/// NC Wizard Step 6/7 - Preuves / Pièces jointes
/// 
/// Step 6: Photos, Documents, Commentaires preuves

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/nc_draft_model.dart';
import '../widgets/wizard_input_widgets.dart';

class NcWizardStep6Preuves extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final NcDraft draft;
  final ValueChanged<NcDraft Function(NcDraft)> onDraftChanged;

  const NcWizardStep6Preuves({
    super.key,
    required this.formKey,
    required this.draft,
    required this.onDraftChanged,
  });

  @override
  State<NcWizardStep6Preuves> createState() => _NcWizardStep6PreuvesState();
}

class _NcWizardStep6PreuvesState extends State<NcWizardStep6Preuves> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        final photoPaths = List<String>.from(widget.draft.photoPaths);
        photoPaths.add(pickedFile.path);
        widget.onDraftChanged((d) => d.copyWith(photoPaths: photoPaths));
      }
    } catch (e) {
      debugPrint('[NcWizardStep6] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de l\'image: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final documentPaths = List<String>.from(widget.draft.documentPaths);
        for (final file in result.files) {
          if (file.path != null) {
            documentPaths.add(file.path!);
          }
        }
        widget.onDraftChanged((d) => d.copyWith(documentPaths: documentPaths));
      }
    } catch (e) {
      debugPrint('[NcWizardStep6] Error picking document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection du document: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    final photoPaths = List<String>.from(widget.draft.photoPaths);
    photoPaths.removeAt(index);
    widget.onDraftChanged((d) => d.copyWith(photoPaths: photoPaths));
  }

  void _removeDocument(int index) {
    final documentPaths = List<String>.from(widget.draft.documentPaths);
    documentPaths.removeAt(index);
    widget.onDraftChanged((d) => d.copyWith(documentPaths: documentPaths));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step title
            Text(
              'Preuves / Pièces jointes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des photos et documents pour étayer la non-conformité',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            // Photos section
            Text(
              'Photos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Prendre une photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choisir une photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Photo grid
            if (widget.draft.photoPaths.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.draft.photoPaths.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(widget.draft.photoPaths[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 400,
                          cacheHeight: 400,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => _removePhoto(index),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 32),
            // Documents section
            Text(
              'Documents',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.attach_file),
              label: const Text('Ajouter un document'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
            const SizedBox(height: 16),
            // Document list
            if (widget.draft.documentPaths.isNotEmpty)
              ...widget.draft.documentPaths.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                final fileName = path.split('/').last;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(fileName),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeDocument(index),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            // Commentaires preuves
            WizardTextInput(
              label: 'Commentaires sur les preuves',
              helperText: 'Commentaires additionnels sur les pièces jointes (optionnel)',
              value: widget.draft.evidenceComments,
              onChanged: (value) {
                widget.onDraftChanged((d) => d.copyWith(evidenceComments: value.isEmpty ? null : value));
              },
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

