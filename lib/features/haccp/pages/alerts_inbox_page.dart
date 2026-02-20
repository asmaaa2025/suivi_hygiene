/// HACCP Alerts Inbox Page
///
/// Displays all HACCP alerts with filtering and status management

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../modules/haccp/alerts/alert_repository.dart';
import '../../../modules/haccp/alerts/models.dart';
import '../../../modules/haccp/alerts/alert_display_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/navigation_helpers.dart';
import 'alert_detail_page.dart';

/// Filtre simplifié : Urgentes | Toutes | Par catégorie
enum InboxFilter {
  urgentes,
  toutes,
  temperature,
  reception,
  huile,
  nettoyage,
  documents,
}

class AlertsInboxPage extends StatefulWidget {
  const AlertsInboxPage({super.key});

  @override
  State<AlertsInboxPage> createState() => _AlertsInboxPageState();
}

class _AlertsInboxPageState extends State<AlertsInboxPage> {
  final AlertRepository _alertRepo = AlertRepository();
  List<Alert> _alerts = [];
  List<Alert> _filteredAlerts = [];
  bool _isLoading = true;
  InboxFilter _filter = InboxFilter.toutes;
  bool _activesUniquement = true; // Par défaut : non traitées seulement

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _alertRepo.getAll();
      setState(() {
        _alerts = alerts;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[AlertsInbox] Error loading alerts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var list = _alerts;
    if (_activesUniquement) {
      list = list.where((a) => a.status == AlertStatus.active).toList();
    }
    switch (_filter) {
      case InboxFilter.urgentes:
        list = list
            .where(
              (a) => AlertDisplayHelper.getPriority(a) == AlertPriority.urgent,
            )
            .toList();
        break;
      case InboxFilter.temperature:
        list = list
            .where(
              (a) =>
                  AlertDisplayHelper.getCategory(a) ==
                  AlertCategory.temperature,
            )
            .toList();
        break;
      case InboxFilter.reception:
        list = list
            .where(
              (a) =>
                  AlertDisplayHelper.getCategory(a) == AlertCategory.reception,
            )
            .toList();
        break;
      case InboxFilter.huile:
        list = list
            .where(
              (a) => AlertDisplayHelper.getCategory(a) == AlertCategory.huile,
            )
            .toList();
        break;
      case InboxFilter.nettoyage:
        list = list
            .where(
              (a) =>
                  AlertDisplayHelper.getCategory(a) == AlertCategory.nettoyage,
            )
            .toList();
        break;
      case InboxFilter.documents:
        list = list
            .where(
              (a) =>
                  AlertDisplayHelper.getCategory(a) == AlertCategory.documents,
            )
            .toList();
        break;
      case InboxFilter.toutes:
        break;
    }
    _filteredAlerts = list;
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
        title: const Text('Alertes HACCP'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(),
          // Alerts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAlerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune alerte',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAlerts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = _filteredAlerts[index];
                        return _buildAlertCard(alert);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('À traiter'),
                selected: _activesUniquement,
                onSelected: (v) {
                  setState(() {
                    _activesUniquement = v ?? true;
                    _applyFilters();
                  });
                },
                selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
              ),
              _filterChip(
                InboxFilter.urgentes,
                'Urgentes',
                Icons.priority_high,
              ),
              _filterChip(InboxFilter.toutes, 'Toutes', Icons.list),
              _filterChip(
                InboxFilter.temperature,
                'Température',
                Icons.thermostat,
              ),
              _filterChip(
                InboxFilter.reception,
                'Réception',
                Icons.inventory_2,
              ),
              _filterChip(InboxFilter.huile, 'Huile', Icons.oil_barrel),
              _filterChip(
                InboxFilter.nettoyage,
                'Nettoyage',
                Icons.cleaning_services,
              ),
              _filterChip(InboxFilter.documents, 'Documents', Icons.folder),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(InboxFilter value, String label, IconData icon) {
    final selected = _filter == value;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : Colors.grey[700],
      ),
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          _filter = value;
          _applyFilters();
        });
      },
      selectedColor: AppTheme.primaryBlue.withOpacity(0.3),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    final category = AlertDisplayHelper.getCategory(alert);
    final priority = AlertDisplayHelper.getPriority(alert);
    final shortTitle = AlertDisplayHelper.getShortTitle(alert);

    final isUrgent = priority == AlertPriority.urgent;
    final color = isUrgent ? Colors.red : Colors.orange;
    final icon = isUrgent ? Icons.error : Icons.warning_amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUrgent ? color : Colors.transparent,
          width: isUrgent ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlertDetailPage(alert: alert),
            ),
          );
          if (result == true) _loadAlerts();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                priority.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (alert.blocking)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.message,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
