/// Service d'export des données HACCP pour conformité et traçabilité
/// Exporte températures, réceptions, nettoyages, changements d'huile, non-conformités

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/repositories/temperature_repository.dart';
import '../data/repositories/reception_repository.dart';
import '../data/repositories/nettoyage_repository.dart';
import '../data/repositories/tache_nettoyage_repository.dart';
import '../data/repositories/appareil_repository.dart';
import '../data/repositories/nc_repository.dart';
import '../data/repositories/rappel_repository.dart';
import '../repositories/oil_change_repository.dart';
import '../data/models/temperature.dart';
import '../data/models/reception.dart';
import '../data/models/nettoyage.dart';
import '../data/models/oil_change.dart';
import '../data/models/appareil.dart';
import '../data/models/nc_models.dart';
import '../data/models/rappel.dart';

class HaccpExportService {
  final _temperatureRepo = TemperatureRepository();
  final _receptionRepo = ReceptionRepository();
  final _nettoyageRepo = NettoyageRepository();
  final _tacheRepo = TacheNettoyageRepository();
  final _appareilRepo = AppareilRepository();
  final _ncRepo = NCRepository();
  final _rappelRepo = RappelRepository();
  final _oilChangeRepo = OilChangeRepository();

  static const String _dateFormat = 'dd/MM/yyyy HH:mm';
  final _df = DateFormat(_dateFormat);

  /// Types de modules exportables
  static const String kTemperatures = 'temperatures';
  static const String kReceptions = 'receptions';
  static const String kCleaning = 'cleaning';
  static const String kOil = 'oil';
  static const String kNc = 'nc';
  static const String kRappels = 'rappels';

  /// Exporte les données HACCP en CSV
  /// [modules] si fourni, n'exporte que ces modules (sinon tout)
  /// [startDate] et [endDate] optionnels pour filtrer
  Future<String> exportToCsv({
    List<String>? modules,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allRows = <List<dynamic>>[];
    final includeAll = modules == null || modules.isEmpty;

    allRows.add(['EXPORT HACCP - Données de traçabilité']);
    allRows.add(['Généré le', _df.format(DateTime.now())]);
    if (startDate != null || endDate != null) {
      allRows.add([
        'Période',
        startDate != null ? _df.format(startDate) : '-',
        'à',
        endDate != null ? _df.format(endDate) : '-',
      ]);
    }
    allRows.add([]);

    if (includeAll || modules!.contains(kTemperatures)) {
    // 1. Températures
    try {
      final temps = await _temperatureRepo.getAll(
        startDate: startDate,
        endDate: endDate,
      );
      final appareils = await _appareilRepo.getAll();
      final appareilsMap = {for (var a in appareils) a.id: a};

      allRows.add(['=== TEMPÉRATURES (${temps.length} enregistrement(s)) ===']);
      allRows.add([
        'Date',
        'Appareil',
        'Température (°C)',
        'Employé',
        'Remarque',
        'Photo',
      ]);
      for (final t in temps) {
        final appareil = appareilsMap[t.appareilId];
        final emp = _formatEmployee(t.employeeFirstName, t.employeeLastName);
        allRows.add([
          _df.format(t.createdAt),
          appareil?.nom ?? t.appareilId,
          t.temperature.toStringAsFixed(1),
          emp,
          t.remarque ?? '',
          t.photoUrl != null ? 'Oui' : 'Non',
        ]);
      }
      allRows.add([]);
    } catch (e) {
      debugPrint('[HaccpExport] Températures error: $e');
      allRows.add(['Erreur températures: $e']);
      allRows.add([]);
    }
    }

    if (includeAll || modules!.contains(kReceptions)) {
    // 2. Réceptions
    try {
      final receptions = await _receptionRepo.getAll(
        startDate: startDate,
        endDate: endDate,
      );
      allRows.add(['=== RÉCEPTIONS (${receptions.length} enregistrement(s)) ===']);
      allRows.add([
        'Date',
        'Fournisseur',
        'Lot',
        'Température (°C)',
        'Employé',
        'Remarque',
        'Non-conformité',
      ]);
      for (final r in receptions) {
        final emp = _formatEmployee(r.employeeFirstName, r.employeeLastName);
        allRows.add([
          _df.format(r.receivedAt),
          r.fournisseur ?? '',
          r.lot ?? '',
          r.temperature?.toStringAsFixed(1) ?? '',
          emp,
          r.remarque ?? '',
          r.nonConformityId != null ? 'Oui' : 'Non',
        ]);
      }
      allRows.add([]);
    } catch (e) {
      debugPrint('[HaccpExport] Réceptions error: $e');
      allRows.add(['Erreur réceptions: $e']);
      allRows.add([]);
    }
    }

    if (includeAll || modules!.contains(kCleaning)) {
    // 3. Nettoyages
    try {
      final nettoyages = await _nettoyageRepo.getAllCompleted(
        startDate: startDate,
        endDate: endDate,
      );
      final taches = await _tacheRepo.getAll();
      final tachesMap = {for (var t in taches) t.id: t};

      allRows.add(['=== NETTOYAGES (${nettoyages.length} enregistrement(s)) ===']);
      allRows.add([
        'Date',
        'Tâche',
        'Conforme',
        'Employé',
        'Remarque',
        'Photo',
      ]);
      for (final n in nettoyages) {
        final tache = tachesMap[n.tacheId];
        final emp = _formatEmployee(n.employeeFirstName, n.employeeLastName);
        allRows.add([
          _df.format(n.doneAt ?? n.createdAt),
          tache?.nom ?? n.tacheId,
          n.conforme == true ? 'Oui' : 'Non',
          emp,
          n.remarque ?? '',
          n.photoUrl != null ? 'Oui' : 'Non',
        ]);
      }
      allRows.add([]);
    } catch (e) {
      debugPrint('[HaccpExport] Nettoyages error: $e');
      allRows.add(['Erreur nettoyages: $e']);
      allRows.add([]);
    }
    }

    if (includeAll || modules!.contains(kOil)) {
    // 4. Changements d'huile
    try {
      final oilData = await _oilChangeRepo.getAll();
      final oilChanges = (oilData)
          .map((j) => OilChange.fromJson(j))
          .where((o) {
            if (startDate != null && o.changedAt.isBefore(startDate)) return false;
            if (endDate != null) {
              final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
              if (o.changedAt.isAfter(endOfDay)) return false;
            }
            return true;
          })
          .toList();

      allRows.add(['=== CHANGEMENTS D\'HUILE (${oilChanges.length} enregistrement(s)) ===']);
      allRows.add([
        'Date',
        'Machine',
        'Quantité (L)',
        'Employé',
        'Remarque',
      ]);
      for (final o in oilChanges) {
        final emp = _formatEmployee(o.employeeFirstName, o.employeeLastName);
        allRows.add([
          _df.format(o.changedAt),
          o.friteuseNom ?? o.friteuseId,
          o.quantite.toStringAsFixed(1),
          emp,
          o.remarque ?? '',
        ]);
      }
      allRows.add([]);
    } catch (e) {
      debugPrint('[HaccpExport] Huiles error: $e');
      allRows.add(['Erreur changements d\'huile: $e']);
      allRows.add([]);
    }
    }

    if (includeAll || modules!.contains(kNc)) {
    // 5. Non-conformités
    try {
      final ncs = await _ncRepo.listNonConformities();
      final filteredNcs = ncs.where((nc) {
        if (startDate != null && nc.detectionDate.isBefore(startDate)) return false;
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (nc.detectionDate.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();

      allRows.add(['=== NON-CONFORMITÉS (${filteredNcs.length} enregistrement(s)) ===']);
      allRows.add([
        'Date',
        'N° Fiche',
        'Statut',
        'Description',
        'Catégorie',
        'Source',
      ]);
      for (final nc in filteredNcs) {
        allRows.add([
          _df.format(nc.detectionDate),
          nc.ficheNumber ?? nc.id,
          _ncStatusLabel(nc.status),
          nc.description,
          nc.objectCategory.displayName,
          nc.sourceType?.value ?? 'Manuel',
        ]);
      }
    } catch (e) {
      debugPrint('[HaccpExport] NC error: $e');
      allRows.add(['Erreur non-conformités: $e']);
    }
    }

    if (includeAll || modules!.contains(kRappels)) {
    try {
      final rappels = await _rappelRepo.getAll();
      final filtered = rappels.where((r) {
        if (startDate != null && r.dateDetection.isBefore(startDate)) return false;
        if (endDate != null) {
          final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (r.dateDetection.isAfter(end)) return false;
        }
        return true;
      }).toList();
      allRows.add(['=== PLAN DE RAPPEL (${filtered.length} entrée(s)) ===']);
      allRows.add(['Date', 'Produit', 'Lot', 'Fournisseur', 'Motif', 'Statut', 'Actions']);
      for (final r in filtered) {
        allRows.add([
          _df.format(r.dateDetection),
          r.produitNom,
          r.lot ?? '-',
          r.fournisseur ?? '-',
          r.motif,
          r.statut.displayName,
          r.actionsPrises ?? '-',
        ]);
      }
      allRows.add([]);
    } catch (e) {
      debugPrint('[HaccpExport] Rappels error: $e');
      allRows.add(['Erreur rappels: $e']);
      allRows.add([]);
    }
    }

    // Écrire le fichier
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(allRows);
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exports_haccp');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final fileName =
        'export_haccp_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(csv, encoding: utf8);

    debugPrint('[HaccpExport] ✅ Fichier créé: ${file.path}');
    return file.path;
  }

  String _ncStatusLabel(NCStatus s) {
    switch (s) {
      case NCStatus.draft: return 'Brouillon';
      case NCStatus.open: return 'Ouvert';
      case NCStatus.inProgress: return 'En cours';
      case NCStatus.closed: return 'Fermé';
    }
  }

  String _truncateForPdf(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }

  String _formatEmployee(String? first, String? last) {
    if (first != null && last != null) return '$first $last';
    if (first != null) return first;
    if (last != null) return last;
    return '';
  }

  /// Exporte en PDF pour contrôle officiel (non modifiable, format professionnel)
  Future<String> exportToPdf({
    List<String>? modules,
    DateTime? startDate,
    DateTime? endDate,
    String? companyName,
  }) async {
    final includeAll = modules == null || modules.isEmpty;
    final pdf = pw.Document();
    final now = DateTime.now();

    pw.Widget buildHeader() => pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue900,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'REGISTRE HACCP - Données de traçabilité',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Document généré le ${_df.format(now)} - Utilisable pour contrôle officiel',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
              if (companyName != null && companyName.isNotEmpty)
                pw.Text(
                  companyName,
                  style: pw.TextStyle(color: PdfColors.grey200, fontSize: 10),
                ),
            ],
          ),
        );

    final sections = <pw.Widget>[buildHeader(), pw.SizedBox(height: 16)];

    if (startDate != null || endDate != null) {
      sections.add(pw.Text(
        'Période : ${startDate != null ? _df.format(startDate) : '-'} à ${endDate != null ? _df.format(endDate) : '-'}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ));
      sections.add(pw.SizedBox(height: 12));
    }

    if (includeAll || modules!.contains(kTemperatures)) {
      try {
        final temps = await _temperatureRepo.getAll(
          startDate: startDate,
          endDate: endDate,
        );
        final appareils = await _appareilRepo.getAll();
        final appareilsMap = {for (var a in appareils) a.id: a};

        sections.add(_pdfSectionTitle('Températures (${temps.length})'));
        sections.add(_pdfTable(
          headers: ['Date', 'Appareil', '°C', 'Employé', 'Remarque'],
          rows: temps.map((t) {
            final a = appareilsMap[t.appareilId];
            return [
              _df.format(t.createdAt),
              a?.nom ?? t.appareilId,
              t.temperature.toStringAsFixed(1),
              _formatEmployee(t.employeeFirstName, t.employeeLastName),
              t.remarque ?? '-',
            ];
          }).toList(),
        ));
        sections.add(pw.SizedBox(height: 12));
      } catch (e) {
        sections.add(pw.Text('Erreur températures: $e', style: const pw.TextStyle(color: PdfColors.red)));
        sections.add(pw.SizedBox(height: 8));
      }
    }

    if (includeAll || modules!.contains(kReceptions)) {
      try {
        final receptions = await _receptionRepo.getAll(
          startDate: startDate,
          endDate: endDate,
        );
        sections.add(_pdfSectionTitle('Réceptions (${receptions.length})'));
        sections.add(_pdfTable(
          headers: ['Date', 'Fournisseur', 'Lot', '°C', 'Employé', 'NC'],
          rows: receptions.map((r) => [
                _df.format(r.receivedAt),
                r.fournisseur ?? '-',
                r.lot ?? '-',
                r.temperature?.toStringAsFixed(1) ?? '-',
                _formatEmployee(r.employeeFirstName, r.employeeLastName),
                r.nonConformityId != null ? 'Oui' : 'Non',
              ]).toList(),
        ));
        sections.add(pw.SizedBox(height: 12));
      } catch (e) {
        sections.add(pw.Text('Erreur réceptions: $e', style: const pw.TextStyle(color: PdfColors.red)));
        sections.add(pw.SizedBox(height: 8));
      }
    }

    if (includeAll || modules!.contains(kCleaning)) {
      try {
        final nettoyages = await _nettoyageRepo.getAllCompleted(
          startDate: startDate,
          endDate: endDate,
        );
        final taches = await _tacheRepo.getAll();
        final tachesMap = {for (var t in taches) t.id: t};

        sections.add(_pdfSectionTitle('Nettoyages (${nettoyages.length})'));
        sections.add(_pdfTable(
          headers: ['Date', 'Tâche', 'Conforme', 'Employé', 'Remarque'],
          rows: nettoyages.map((n) => [
                _df.format(n.doneAt ?? n.createdAt),
                tachesMap[n.tacheId]?.nom ?? n.tacheId,
                n.conforme == true ? 'Oui' : 'Non',
                _formatEmployee(n.employeeFirstName, n.employeeLastName),
                n.remarque ?? '-',
              ]).toList(),
        ));
        sections.add(pw.SizedBox(height: 12));
      } catch (e) {
        sections.add(pw.Text('Erreur nettoyages: $e', style: const pw.TextStyle(color: PdfColors.red)));
        sections.add(pw.SizedBox(height: 8));
      }
    }

    if (includeAll || modules!.contains(kOil)) {
      try {
        final oilData = await _oilChangeRepo.getAll();
        final oilChanges = oilData
            .map((j) => OilChange.fromJson(j))
            .where((o) {
              if (startDate != null && o.changedAt.isBefore(startDate)) return false;
              if (endDate != null) {
                final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
                if (o.changedAt.isAfter(end)) return false;
              }
              return true;
            })
            .toList();

        sections.add(_pdfSectionTitle('Changements d\'huile (${oilChanges.length})'));
        sections.add(_pdfTable(
          headers: ['Date', 'Machine', 'Quantité (L)', 'Employé', 'Remarque'],
          rows: oilChanges.map((o) => [
                _df.format(o.changedAt),
                o.friteuseNom ?? o.friteuseId,
                o.quantite.toStringAsFixed(1),
                _formatEmployee(o.employeeFirstName, o.employeeLastName),
                o.remarque ?? '-',
              ]).toList(),
        ));
        sections.add(pw.SizedBox(height: 12));
      } catch (e) {
        sections.add(pw.Text('Erreur huiles: $e', style: const pw.TextStyle(color: PdfColors.red)));
        sections.add(pw.SizedBox(height: 8));
      }
    }

    if (includeAll || modules!.contains(kNc)) {
      try {
        final ncs = await _ncRepo.listNonConformities();
        final filtered = ncs.where((nc) {
          if (startDate != null && nc.detectionDate.isBefore(startDate)) return false;
          if (endDate != null) {
            final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
            if (nc.detectionDate.isAfter(end)) return false;
          }
          return true;
        }).toList();

        sections.add(_pdfSectionTitle('Non-conformités (${filtered.length})'));
        sections.add(_pdfTable(
          headers: ['Date', 'N° Fiche', 'Statut', 'Description', 'Catégorie'],
          rows: filtered.map((nc) => [
                _df.format(nc.detectionDate),
                nc.ficheNumber ?? nc.id,
                _ncStatusLabel(nc.status),
                nc.description,
                nc.objectCategory.displayName,
              ]).toList(),
        ));
      } catch (e) {
        sections.add(pw.Text('Erreur NC: $e', style: const pw.TextStyle(color: PdfColors.red)));
      }
    }

    if (includeAll || modules!.contains(kRappels)) {
      try {
        final rappels = await _rappelRepo.getAll();
        final filtered = rappels.where((r) {
          if (startDate != null && r.dateDetection.isBefore(startDate)) return false;
          if (endDate != null) {
            final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
            if (r.dateDetection.isAfter(end)) return false;
          }
          return true;
        }).toList();
        sections.add(_pdfSectionTitle('Plan de rappel (${filtered.length})'));
        sections.add(_pdfTable(
          headers: ['Date', 'Produit', 'Lot', 'Statut', 'Motif'],
          rows: filtered.map((r) => [
                _df.format(r.dateDetection),
                r.produitNom,
                r.lot ?? '-',
                r.statut.displayName,
                _truncateForPdf(r.motif, 40),
              ]).toList(),
        ));
      } catch (e) {
        sections.add(pw.Text('Erreur rappels: $e', style: const pw.TextStyle(color: PdfColors.red)));
      }
    }

    sections.add(pw.SizedBox(height: 20));
    sections.add(pw.Divider());
    sections.add(pw.Text(
      'Document généré par HACCPilot - Export destiné au contrôle officiel',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    ));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => sections,
      ),
    );

    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exports_haccp');
    if (!await exportDir.exists()) await exportDir.create(recursive: true);
    final fileName = 'registre_haccp_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    debugPrint('[HaccpExport] ✅ PDF créé: ${file.path}');
    return file.path;
  }

  pw.Widget _pdfSectionTitle(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget _pdfTable({required List<String> headers, required List<List<String>> rows}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        for (var i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              )).toList(),
        ),
        ...rows.map((row) => pw.TableRow(
              children: row.map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(_truncateForPdf(c, 80), style: const pw.TextStyle(fontSize: 8)),
                  )).toList(),
            )),
      ],
    );
  }

  /// Partage le fichier exporté via l'application de partage du système
  Future<void> shareExport(String filePath, {bool isPdf = false}) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: isPdf ? 'Registre HACCP - Contrôle officiel' : 'Export HACCP - Données',
      text: isPdf
          ? 'Registre de traçabilité HACCP - Document pour contrôle officiel'
          : 'Export des données HACCP',
    );
  }
}
