import 'package:flutter/material.dart';

/// HACCP status enum
enum HaccpStatus {
  ok,
  warning,
  critical,
}

/// Badge widget for HACCP status
class HaccpBadge extends StatelessWidget {
  final HaccpStatus status;
  final String label;
  final bool compact;

  const HaccpBadge({
    super.key,
    required this.status,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case HaccpStatus.ok:
        color = Colors.green;
        break;
      case HaccpStatus.warning:
        color = Colors.orange;
        break;
      case HaccpStatus.critical:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
