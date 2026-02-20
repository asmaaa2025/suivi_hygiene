/// Service d'export PDF des fiches de non-conformité
/// - Export d'une fiche individuelle en PDF
/// - Export de toutes les fiches sur une plage de dates (PDF multi-pages)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bekkapp/data/models/nc_models.dart';
import 'package:bekkapp/data/repositories/nc_repository.dart';

class NcPdfExportService {
  final _ncRepo = NCRepository();
  final _df = DateFormat('dd/MM/yyyy');
  final _dfTime = DateFormat('dd/MM/yyyy HH:mm');

  bool _isImageAttachment(NCAttachment a) {
    final t = (a.fileType ?? '').toLowerCase();
    if (t == 'image') return true;
    final ext = (a.fileName.split('.').lastOrNull ?? '').toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  Future<Uint8List?> _loadImageBytes(NCAttachment att) async {
    return _ncRepo.downloadAttachmentBytes(att);
  }

  /// Construit le contenu PDF d'une fiche NC (1 page)
  Future<pw.Widget> buildNcFormPage(NonConformity nc, {int? pageIndex, int? totalPages}) async {
    final footer = (pageIndex != null && totalPages != null)
        ? 'Fiche ${pageIndex + 1}/$totalPages - Document généré le ${_dfTime.format(DateTime.now())}'
        : 'Document généré le ${_dfTime.format(DateTime.now())}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // En-tête
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue900,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FICHE DE NON-CONFORMITÉ',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'N° ${nc.ficheNumber ?? nc.id.substring(0, 8)}',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _ncStatusLabel(nc.status),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _df.format(nc.detectionDate),
                    style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Section 1 - Identification
        _sectionTitle('1. Identification'),
        _row('Catégorie', nc.objectCategory.displayName),
        if (nc.objectOther != null && nc.objectOther!.isNotEmpty)
          _row('Autre', nc.objectOther!),
        _row('Étape / Poste', nc.step ?? '-'),
        _row('Ouvert par', nc.openedByRoleService ?? '-'),
        pw.SizedBox(height: 8),

        // Section 2 - Description
        _sectionTitle('2. Description du constat'),
        _row('Produit', nc.productName ?? '-'),
        _paragraph('Description', nc.description),
        if (nc.sanitaryImpact != null && nc.sanitaryImpact!.isNotEmpty)
          _row('Impact sanitaire', nc.sanitaryImpact!),
        pw.SizedBox(height: 8),

        // Section 3 - Action immédiate
        _sectionTitle('3. Action immédiate'),
        _row('Effectuée', nc.immediateActionDone ? 'Oui' : 'Non'),
        if (nc.immediateActionDetail != null && nc.immediateActionDetail!.isNotEmpty)
          _paragraph('Détail', nc.immediateActionDetail!),
        if (nc.immediateActionDoneAt != null)
          _row('Date', _dfTime.format(nc.immediateActionDoneAt!)),
        pw.SizedBox(height: 8),

        // Section 4 - Évaluation RQ
        _sectionTitle('4. Évaluation RQ'),
        if (nc.rqDate != null) _row('Date RQ', _df.format(nc.rqDate!)),
        if (nc.rqClassification != null) _row('Classification', nc.rqClassification!),
        _row('Action corrective requise', nc.rqActionCorrectiveRequired ? 'Oui' : 'Non'),
        pw.SizedBox(height: 8),

        // Section 5 - Causes
        if (nc.causes != null && nc.causes!.isNotEmpty) ...[
          _sectionTitle('5. Causes probables'),
          for (final c in nc.causes!)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '• ${c.category.displayName}: ${_truncate(c.causeText, 200)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          pw.SizedBox(height: 8),
        ],

        // Section 6 - Solutions
        if (nc.solutions != null && nc.solutions!.isNotEmpty) ...[
          _sectionTitle('6. Solutions proposées'),
          for (final s in nc.solutions!)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('• ${_truncate(s.solutionText, 200)}', style: const pw.TextStyle(fontSize: 9)),
            ),
          pw.SizedBox(height: 8),
        ],

        // Section 7 - Actions correctives
        if (nc.actions != null && nc.actions!.isNotEmpty) ...[
          _sectionTitle('7. Actions correctives'),
          for (final a in nc.actions!)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '• ${_truncate(a.actionText, 150)} ${a.targetDate != null ? '(${_df.format(a.targetDate!)})' : ''} - ${_actionStatusLabel(a.status)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          pw.SizedBox(height: 8),
        ],

        // Section 8 - Vérifications
        if (nc.verifications != null && nc.verifications!.isNotEmpty) ...[
          _sectionTitle('8. Vérifications'),
          for (final v in nc.verifications!)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '• ${v.actionVerified ?? '-'}: ${v.result ?? 'Non vérifié'}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          pw.SizedBox(height: 8),
        ],

        // Pièces jointes : photos affichées, documents listés
        if (nc.attachments != null && nc.attachments!.isNotEmpty) ...[
          _sectionTitle('Pièces jointes'),
          ...await _buildAttachmentWidgets(nc.attachments!),
          pw.SizedBox(height: 8),
        ],

        pw.Spacer(),
        pw.Divider(thickness: 0.5),
        pw.Text(footer, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ],
    );
  }

  Future<List<pw.Widget>> _buildAttachmentWidgets(List<NCAttachment> attachments) async {
    final widgets = <pw.Widget>[];
    final images = attachments.where(_isImageAttachment).toList();
    final others = attachments.where((a) => !_isImageAttachment(a)).toList();

    for (final att in images) {
      final bytes = await _loadImageBytes(att);
      if (bytes != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(att.fileName, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Container(
                  constraints: const pw.BoxConstraints(maxWidth: 200, maxHeight: 150),
                  child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('Photo: ${att.fileName}', style: const pw.TextStyle(fontSize: 9)),
          ),
        );
      }
    }
    if (others.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Documents: ${others.map((a) => a.fileName).join(', ')}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      );
    }
    return widgets;
  }

  pw.Widget _sectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 100,
              child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              child: pw.Text(_truncate(value, 300), style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

  pw.Widget _paragraph(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$label:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(_truncate(value, 500), style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }

  String _ncStatusLabel(NCStatus s) {
    switch (s) {
      case NCStatus.draft: return 'Brouillon';
      case NCStatus.open: return 'Ouvert';
      case NCStatus.inProgress: return 'En cours';
      case NCStatus.closed: return 'Clôturé';
    }
  }

  String _actionStatusLabel(NCActionStatus s) {
    switch (s) {
      case NCActionStatus.pending: return 'En attente';
      case NCActionStatus.inProgress: return 'En cours';
      case NCActionStatus.completed: return 'Terminé';
      case NCActionStatus.cancelled: return 'Annulé';
    }
  }

  /// Exporte une fiche NC en PDF (1 page)
  Future<String> exportSingleNcToPdf(NonConformity nc) async {
    // Charger les données complètes si nécessaire
    NonConformity fullNc = nc;
    if (nc.causes == null && nc.solutions == null && nc.actions == null) {
      final loaded = await _ncRepo.getById(nc.id, includeRelated: true);
      if (loaded != null) fullNc = loaded;
    }

    final pdf = pw.Document();
    final pageContent = await buildNcFormPage(fullNc);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pageContent,
      ),
    );

    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exports_nc');
    if (!await exportDir.exists()) await exportDir.create(recursive: true);
    final fileName = 'fiche_nc_${fullNc.ficheNumber ?? fullNc.id.substring(0, 8)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    debugPrint('[NcPdfExport] ✅ Fiche exportée: ${file.path}');
    return file.path;
  }

  /// Exporte toutes les fiches NC sur une plage de dates (PDF avec N pages)
  /// Exclut les brouillons
  Future<String> exportNcsToPdf({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ncs = await _ncRepo.listNonConformities(
      startDate: startDate,
      endDate: endDate,
    );
    final filledNcs = ncs.where((nc) => nc.status != NCStatus.draft).toList();

    if (filledNcs.isEmpty) {
      throw Exception('Aucune fiche de non-conformité remplie sur cette période');
    }

    // Charger les données complètes pour chaque NC
    final fullNcs = <NonConformity>[];
    for (final nc in filledNcs) {
      final loaded = await _ncRepo.getById(nc.id, includeRelated: true);
      fullNcs.add(loaded ?? nc);
    }

    final pdf = pw.Document();
    final total = fullNcs.length;

    for (var i = 0; i < fullNcs.length; i++) {
      final pageContent = await buildNcFormPage(fullNcs[i], pageIndex: i, totalPages: total);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pageContent,
        ),
      );
    }

    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exports_nc');
    if (!await exportDir.exists()) await exportDir.create(recursive: true);
    final fileName = 'fiches_nc_${_df.format(startDate).replaceAll('/', '')}_${_df.format(endDate).replaceAll('/', '')}_${DateFormat('HHmmss').format(DateTime.now())}.pdf';
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    debugPrint('[NcPdfExport] ✅ $total fiche(s) exportée(s): ${file.path}');
    return file.path;
  }

  /// Partage le fichier PDF exporté
  Future<void> shareExport(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Fiche(s) de non-conformité',
      text: 'Export des fiches de non-conformité HACCP',
    );
  }
}
