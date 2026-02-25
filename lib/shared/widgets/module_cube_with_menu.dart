/// Module Cube with Contextual Menu
///
/// Reusable widget for HACCP hub cubes with popup menu
/// Tablet-friendly with large touch targets

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/module_action_menu.dart';
import 'app_module_tile.dart';

class ModuleCubeWithMenu extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final List<ModuleAction> actions;
  final String menuTitle;

  /// Si défini, un tap simple navigue vers cette route au lieu d'afficher le menu
  final String? tapNavigatesTo;

  const ModuleCubeWithMenu({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.actions,
    required this.menuTitle,
    this.tapNavigatesTo,
  });

  void _onTap(BuildContext context, Offset globalPosition) {
    if (tapNavigatesTo != null && tapNavigatesTo!.isNotEmpty) {
      // Use GoRouter if available
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go(tapNavigatesTo!);
      }
    } else {
      _showMenu(context, globalPosition);
    }
  }

  void _showMenu(BuildContext context, Offset globalPosition) async {
    // Show anchored menu only
    await showModuleActionMenu(
      context: context,
      position: globalPosition,
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Builder(
        builder: (builderContext) {
          return InkWell(
            onTapDown: (TapDownDetails details) {
              final RenderBox? box =
                  builderContext.findRenderObject() as RenderBox?;
              final Offset pos = box != null
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : details.globalPosition;
              _onTap(context, pos);
            },
            borderRadius: BorderRadius.circular(16),
            child: AppModuleTile.buildTileContent(
              context,
              icon: icon,
              title: title,
              subtitle: subtitle,
              color: color,
            ),
          );
        },
      ),
    );
  }
}
