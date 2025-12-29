import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Loading skeleton component
class LoadingSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 16,
      decoration: BoxDecoration(
        color: AppTheme.cardBorder.color,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
}

/// List item skeleton for loading states
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            LoadingSkeleton(
                width: 48, height: 48, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeleton(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  LoadingSkeleton(width: 150, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
