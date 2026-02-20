/// Synthèse hebdomadaire d'autocontrôle HACCP
/// Classeur hebdomadaire conforme au PMS (Plan de Maîtrise Sanitaire)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../services/haccp_export_service.dart';

class SyntheseHebdomadairePage extends StatefulWidget {
  const SyntheseHebdomadairePage({super.key});

  @override
  State<SyntheseHebdomadairePage> createState() => _SyntheseHebdomadairePageState();
}

class _SyntheseHebdomadairePageState extends State<SyntheseHebdomadairePage> {
  final _exportService = HaccpExportService();
  DateTime _startDate = _getStartOfWeek(DateTime.now());
  DateTime _endDate = _getStartOfWeek(DateTime.now()).add(const Duration(days: 6));
  bool _isExporting = false;

  static DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  String get _periodLabel =>
      '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';

  int get _totalDays => _endDate.difference(_startDate).inDays + 1;

  DateTime get _endDateForExport =>
      DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

  void _setPreset(int days) {
    setState(() {
      _endDate = DateTime(_startDate.year, _startDate.month, _startDate.day + days - 1);
    });
  }

  void _setCurrentWeek() {
    setState(() {
      _startDate = _getStartOfWeek(DateTime.now());
      _endDate = _startDate.add(const Duration(days: 6));
    });
  }

  void _addDays(int delta) {
    setState(() {
      _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day + delta);
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
    });
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final filePath = await _exportService.exportToPdf(
        modules: null,
        startDate: _startDate,
        endDate: _endDateForExport,
      );
      if (!mounted) return;
      await _exportService.shareExport(filePath, isPdf: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classeur ($_periodLabel) exporté en PDF'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
          tooltip: 'Retour',
        ),
        title: const Text('Classeur hebdomadaire'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            tooltip: 'Exporter PDF',
            onPressed: _isExporting ? null : _exportPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Synthèse hebdomadaire d\'autocontrôle',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conforme au Plan de Maîtrise Sanitaire - Utilisable pour le classeur d\'autocontrôle',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, size: 32, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Text(
                        'Période sélectionnée',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date de début
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: _endDate,
                      );
                      if (d != null && mounted) {
                        setState(() {
                          _startDate = d;
                          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                        });
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.event, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text('Du ', style: TextStyle(color: Colors.grey[600])),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date de fin
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null && mounted) {
                        setState(() => _endDate = d);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.event, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text('Au ', style: TextStyle(color: Colors.grey[600])),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_endDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Presets rapides',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _presetChip('Semaine courante', _setCurrentWeek),
                      _presetChip('7 jours', () => _setPreset(7)),
                      _presetChip('14 jours', () => _setPreset(14)),
                      _presetChip('1 mois', () => _setPreset(31)),
                      _presetChip('+7 jours', () => _addDays(7)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalDays jour(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.checklist, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Contenu du classeur',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildItem('Températures', Icons.thermostat),
                  _buildItem('Réceptions', Icons.inventory_2),
                  _buildItem('Nettoyages', Icons.cleaning_services),
                  _buildItem('Changements d\'huile', Icons.oil_barrel),
                  _buildItem('Non-conformités', Icons.warning),
                  const SizedBox(height: 8),
                  Text(
                    'L\'export PDF regroupe toutes ces données pour la période choisie.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
              label: Text(_isExporting ? 'Génération...' : 'Exporter le classeur en PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
      side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5)),
    );
  }

  Widget _buildItem(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
