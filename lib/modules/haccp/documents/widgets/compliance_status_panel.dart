import 'package:flutter/material.dart';
import '../models.dart';

class ComplianceStatusPanel extends StatelessWidget {
  final List<ComplianceStatusInfo> statuses;
  final void Function(ComplianceStatusInfo status)? onUpload;

  const ComplianceStatusPanel({
    super.key,
    required this.statuses,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conformité HACCP',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: statuses.map((info) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: info != statuses.last ? 8 : 0,
                ),
                child: _ComplianceCard(
                  statusInfo: info,
                  onUpload: onUpload != null ? () => onUpload!(info) : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ComplianceCard extends StatelessWidget {
  final ComplianceStatusInfo statusInfo;
  final VoidCallback? onUpload;

  const _ComplianceCard({
    required this.statusInfo,
    this.onUpload,
  });

  IconData _getIcon() {
    switch (statusInfo.requirement.code) {
      case 'MICROBIO':
        return Icons.biotech;
      case 'PEST_CONTROL':
        return Icons.pest_control;
      case 'COMPLIANCE_AUDIT':
        return Icons.verified;
      default:
        return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = statusInfo.status.color;
    final lastDate = statusInfo.lastEventDate;
    final nextDue = statusInfo.nextDueDate;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onUpload,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + status badge row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getIcon(), size: 22, color: color),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusInfo.status.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category name
              Text(
                statusInfo.requirement.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Last date
              Text(
                lastDate != null
                    ? 'Dernier: ${_formatDate(lastDate)}'
                    : 'Aucun document',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),

              // Next due
              if (nextDue != null)
                Text(
                  'Prochain: ${_formatDate(nextDue)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 8),

              // Upload CTA
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onUpload,
                  icon: Icon(Icons.upload, size: 14, color: color),
                  label: Text(
                    'Ajouter',
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
