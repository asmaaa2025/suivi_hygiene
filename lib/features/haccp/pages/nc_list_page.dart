/// Non-Conformities List Page
/// Displays all NCs with filtering capabilities

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/nc_repository.dart';
import '../../../data/models/nc_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../services/nc_pdf_export_service.dart';
import 'nc_detail_page.dart';

class NCListPage extends StatefulWidget {
  const NCListPage({super.key});

  @override
  State<NCListPage> createState() => _NCListPageState();
}

class _NCListPageState extends State<NCListPage> {
  final NCRepository _ncRepo = NCRepository();
  List<NonConformity> _ncs = [];
  bool _isLoading = true;

  // Filters
  NCStatus? _selectedStatus;
  NCSourceType? _selectedSourceType;
  NCObjectCategory? _selectedObjectCategory;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadNCs();
  }

  Future<void> _loadNCs() async {
    setState(() => _isLoading = true);
    try {
      final ncs = await _ncRepo.listNonConformities(
        status: _selectedStatus,
        sourceType: _selectedSourceType,
        objectCategory: _selectedObjectCategory,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _ncs = ncs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[NCList] Error loading NCs: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Try to go back to alerts home, fallback to HACCP hub
            if (context.canPop()) {
              context.pop();
            } else {
              NavigationHelpers.goHaccpHub(context);
            }
          },
          tooltip: 'Retour',
        ),
        title: const Text('Non-Conformités'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _showExportPdfDialog,
            tooltip: 'Exporter fiches en PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNCs,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewNC(),
            tooltip: 'Nouvelle NC',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters - collapsible
          _buildFilters(),
          // NCs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ncs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Aucune non-conformité',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasActiveFilters()
                                ? 'Aucun résultat avec les filtres sélectionnés'
                                : 'Commencez par créer votre première non-conformité',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _createNewNC,
                            icon: const Icon(Icons.add),
                            label: const Text('Créer une NC'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNCs,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _ncs.length,
                      itemBuilder: (context, index) {
                        final nc = _ncs[index];
                        return _buildNCCard(nc);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final hasActiveFilters =
        _selectedStatus != null ||
        _selectedSourceType != null ||
        _selectedObjectCategory != null ||
        _startDate != null ||
        _endDate != null;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200), // Limit filter height
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Filtres',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('Actifs'),
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ],
                const Spacer(),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _selectedSourceType = null;
                        _selectedObjectCategory = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadNCs();
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Réinitialiser'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Filters row - scrollable horizontally
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status filter
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<NCStatus>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous'),
                        ),
                        const DropdownMenuItem(
                          value: NCStatus.draft,
                          child: Text('Brouillon'),
                        ),
                        const DropdownMenuItem(
                          value: NCStatus.open,
                          child: Text('Ouvert'),
                        ),
                        const DropdownMenuItem(
                          value: NCStatus.inProgress,
                          child: Text('En cours'),
                        ),
                        const DropdownMenuItem(
                          value: NCStatus.closed,
                          child: Text('Fermé'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                        _loadNCs();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Source type filter
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<NCSourceType>(
                      value: _selectedSourceType,
                      decoration: InputDecoration(
                        labelText: 'Source',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous'),
                        ),
                        const DropdownMenuItem(
                          value: NCSourceType.temperature,
                          child: Text('Température'),
                        ),
                        const DropdownMenuItem(
                          value: NCSourceType.reception,
                          child: Text('Réception'),
                        ),
                        const DropdownMenuItem(
                          value: NCSourceType.oil,
                          child: Text('Huile'),
                        ),
                        const DropdownMenuItem(
                          value: NCSourceType.cleaning,
                          child: Text('Nettoyage'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSourceType = value;
                        });
                        _loadNCs();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Object category filter
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<NCObjectCategory>(
                      value: _selectedObjectCategory,
                      decoration: InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Toutes'),
                        ),
                        ...NCObjectCategory.values.map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedObjectCategory = value;
                        });
                        _loadNCs();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date range button - more compact
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDateRange(),
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Flexible(
                        child: Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                              : 'Période',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNCCard(NonConformity nc) {
    Color statusColor;
    String statusText;
    switch (nc.status) {
      case NCStatus.draft:
        statusColor = Colors.grey;
        statusText = 'Brouillon';
        break;
      case NCStatus.open:
        statusColor = Colors.orange;
        statusText = 'Ouvert';
        break;
      case NCStatus.inProgress:
        statusColor = Colors.blue;
        statusText = 'En cours';
        break;
      case NCStatus.closed:
        statusColor = Colors.green;
        statusText = 'Fermé';
        break;
    }

    Color sourceColor;
    IconData sourceIcon;
    String sourceText;
    switch (nc.sourceType) {
      case NCSourceType.temperature:
        sourceColor = Colors.red;
        sourceIcon = Icons.thermostat;
        sourceText = 'Température';
        break;
      case NCSourceType.reception:
        sourceColor = Colors.blue;
        sourceIcon = Icons.inventory_2;
        sourceText = 'Réception';
        break;
      case NCSourceType.oil:
        sourceColor = Colors.orange;
        sourceIcon = Icons.oil_barrel;
        sourceText = 'Huile';
        break;
      case NCSourceType.cleaning:
        sourceColor = Colors.green;
        sourceIcon = Icons.cleaning_services;
        sourceText = 'Nettoyage';
        break;
      case null:
        sourceColor = Colors.grey;
        sourceIcon = Icons.description;
        sourceText = 'Manuel';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clickable area for opening details
          InkWell(
            onTap: () => _openNC(nc.id),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with badges
                  Row(
                    children: [
                      // Fiche number
                      if (nc.ficheNumber != null) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              nc.ficheNumber!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Status badge
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Source icon
                      if (nc.sourceType != null)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: sourceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(sourceIcon, color: sourceColor, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    nc.description,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Metadata row
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      // Object category
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              nc.objectCategory.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Source type
                      if (nc.sourceType != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(sourceIcon, size: 16, color: sourceColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                sourceText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: sourceColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      // Date
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(nc.detectionDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Close button for open/in-progress tickets (outside InkWell to prevent conflicts)
          if (nc.status == NCStatus.open || nc.status == NCStatus.inProgress)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _closeTicket(nc),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Fermer le ticket'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _closeTicket(NonConformity nc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fermer le ticket'),
        content: const Text(
          'Êtes-vous sûr de vouloir fermer ce ticket de non-conformité ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updated = nc.copyWith(status: NCStatus.closed);
        await _ncRepo.updateNonConformity(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket fermé avec succès')),
          );
          _loadNCs(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la fermeture: $e')),
          );
        }
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadNCs();
    }
  }

  void _openNC(String ncId) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final prefix = isAdminRoute ? '/admin' : '/app';
    context.push('$prefix/alerts/nc/$ncId');
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _selectedSourceType != null ||
        _selectedObjectCategory != null ||
        _startDate != null ||
        _endDate != null;
  }

  Future<void> _showExportPdfDialog() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    DateTime startDate = startOfMonth;
    DateTime endDate = now;
    bool loading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Exporter les fiches NC en PDF'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sélectionnez la plage de dates pour exporter toutes les fiches remplies.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Du'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: endDate,
                    );
                    if (picked != null) setState(() => startDate = picked);
                  },
                ),
                ListTile(
                  title: const Text('Au'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => endDate = picked);
                  },
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        final service = NcPdfExportService();
                        final path = await service.exportNcsToPdf(
                          startDate: startDate,
                          endDate: endDate,
                        );
                        if (ctx.mounted) {
                          await service.shareExport(path);
                          Navigator.pop(ctx, true);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      } finally {
                        if (ctx.mounted) setState(() => loading = false);
                      }
                    },
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              label: const Text('Exporter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fiches exportées en PDF')));
    }
  }

  void _createNewNC() {
    // Use new wizard instead of old form
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final prefix = isAdminRoute ? '/admin' : '/app';
    context.push('$prefix/alerts/nc/wizard');
  }
}
