/// HACCP Alert Detail Page
///
/// Displays alert details with evidence, recommended actions, and resolution options

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../modules/haccp/alerts/alert_service.dart';
import '../../../modules/haccp/alerts/models.dart';
import '../../../modules/haccp/alerts/alert_display_helper.dart';
import '../../../core/theme/app_theme.dart';

class AlertDetailPage extends StatefulWidget {
  final Alert alert;

  const AlertDetailPage({super.key, required this.alert});

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  final AlertService _alertService = AlertService.instance;
  bool _isLoading = false;
  late Alert _alert;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
  }

  Future<void> _resolveAlert() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Résoudre l\'alerte'),
        content: const Text(
          'Êtes-vous sûr de vouloir marquer cette alerte comme résolue ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Résoudre'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _alertService.resolveAlert(_alert.id);
        setState(() {
          _alert = _alert.copyWith(
            status: AlertStatus.resolved,
            resolvedAt: DateTime.now(),
          );
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Alerte résolue')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  Future<void> _acknowledgeAlert() async {
    setState(() => _isLoading = true);
    try {
      await _alertService.acknowledgeAlert(_alert.id);
      setState(() {
        _alert = _alert.copyWith(status: AlertStatus.acknowledged);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alerte acquittée')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _createCorrectiveAction() {
    // TODO: Navigate to corrective action form
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité à venir: Créer une action corrective'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priority = AlertDisplayHelper.getPriority(_alert);
    final category = AlertDisplayHelper.getCategory(_alert);
    final shortTitle = AlertDisplayHelper.getShortTitle(_alert);
    final isUrgent = priority == AlertPriority.urgent;
    final severityColor = isUrgent ? Colors.red : Colors.orange;
    final severityIcon = isUrgent ? Icons.error : Icons.warning_amber;
    final severityLabel = priority.label;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Retour',
        ),
        title: const Text('Détail de l\'alerte'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _alert.blocking
                            ? severityColor
                            : Colors.transparent,
                        width: _alert.blocking ? 2 : 0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: severityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  severityIcon,
                                  color: severityColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shortTitle,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${severityLabel} · ${category.label}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: severityColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_alert.blocking)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'BLOQUANT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _alert.message,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Module and metadata
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Module', _alert.module.toUpperCase()),
                          const Divider(),
                          _buildInfoRow('Code alerte', _alert.alertCode),
                          const Divider(),
                          _buildInfoRow(
                            'Date de création',
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(_alert.createdAt),
                          ),
                          if (_alert.resolvedAt != null) ...[
                            const Divider(),
                            _buildInfoRow(
                              'Date de résolution',
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(_alert.resolvedAt!),
                            ),
                          ],
                          const Divider(),
                          _buildInfoRow(
                            'Statut',
                            _alert.status == AlertStatus.active
                                ? 'Actif'
                                : _alert.status == AlertStatus.resolved
                                ? 'Résolu'
                                : 'Acquitté',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommended actions
                  if (_alert.recommendedActions.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.amber[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Actions recommandées',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._alert.recommendedActions.map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(
                                        top: 6,
                                        right: 12,
                                      ),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        action,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Event snapshot (evidence)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.fact_check, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Données de l\'événement',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _formatEventSnapshot(_alert.eventSnapshot),
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  if (_alert.status == AlertStatus.active) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _alert.blocking ? null : _resolveAlert,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Marquer comme résolu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _acknowledgeAlert,
                        icon: const Icon(Icons.check),
                        label: const Text('Acquitter'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _createCorrectiveAction,
                        icon: const Icon(Icons.build),
                        label: const Text('Créer une action corrective'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventSnapshot(Map<String, dynamic> snapshot) {
    final buffer = StringBuffer();
    void formatMap(Map<String, dynamic> map, {int indent = 0}) {
      final prefix = '  ' * indent;
      map.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          buffer.writeln('$prefix$key:');
          formatMap(value, indent: indent + 1);
        } else {
          buffer.writeln('$prefix$key: $value');
        }
      });
    }

    formatMap(snapshot);
    return buffer.toString();
  }
}
