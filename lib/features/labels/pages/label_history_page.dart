import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/haccp_badge.dart';
import '../../../../repositories/labels_repository.dart';

/// Page showing label print history
class LabelHistoryPage extends StatefulWidget {
  const LabelHistoryPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<LabelHistoryPage> createState() => _LabelHistoryPageState();
}

class _LabelHistoryPageState extends State<LabelHistoryPage> {
  final _labelsRepo = LabelsRepository();
  List<Map<String, dynamic>> _prints = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prints = await _labelsRepo.getAll();
      setState(() {
        _prints = prints;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _copyZPL(String zpl) async {
    await Clipboard.setData(ClipboardData(text: zpl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Code ZPL copié'),
          backgroundColor: AppTheme.statusOk,
        ),
      );
    }
  }

  void _showZPLDetails(Map<String, dynamic> printRecord) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Détails impression - ${printRecord['produit_nom'] ?? 'N/A'}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (printRecord['printed_at'] != null) ...[
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(printRecord['printed_at']))}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],
              HaccpBadge(
                status: printRecord['success'] == true
                    ? HaccpStatus.ok
                    : HaccpStatus.critical,
                label: printRecord['success'] == true ? 'Réussi' : 'Échec',
                compact: true,
              ),
              if (printRecord['error_message'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Erreur: ${printRecord['error_message']}',
                  style: TextStyle(color: AppTheme.statusCritical),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Code ZPL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundNeutral,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder.color),
                ),
                child: SelectableText(
                  printRecord['zpl_payload'] ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _copyZPL(printRecord['zpl_payload'] ?? '');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier ZPL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => NavigationHelpers.goHaccpHub(context),
              ),
              title: const Text('Historique impressions'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadHistory,
                  tooltip: 'Actualiser',
                ),
              ],
            )
          : null,
      body: _isLoading
          ? const LoadingSkeleton()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadHistory)
          : _prints.isEmpty
          ? const EmptyState(
              title: 'Aucun historique',
              message: 'Aucune impression enregistrée',
              icon: Icons.print_disabled,
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _prints.length,
                itemBuilder: (context, index) {
                  final printRecord = _prints[index];
                  final printedAt = printRecord['printed_at'] != null
                      ? DateTime.tryParse(printRecord['printed_at'].toString())
                      : null;

                  return SectionCard(
                    child: InkWell(
                      onTap: () => _showZPLDetails(printRecord),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      printRecord['produit_nom'] ??
                                          'Produit inconnu',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (printedAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                        ).format(printedAt),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              HaccpBadge(
                                status: printRecord['success'] == true
                                    ? HaccpStatus.ok
                                    : HaccpStatus.critical,
                                label: printRecord['success'] == true
                                    ? 'Réussi'
                                    : 'Échec',
                                compact: true,
                              ),
                            ],
                          ),
                          if (printRecord['error_message'] != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.statusCriticalBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 16,
                                    color: AppTheme.statusCritical,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      printRecord['error_message'],
                                      style: TextStyle(
                                        color: AppTheme.statusCritical,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    _copyZPL(printRecord['zpl_payload'] ?? ''),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copier ZPL'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
