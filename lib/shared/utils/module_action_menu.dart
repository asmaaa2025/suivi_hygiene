import 'package:flutter/material.dart';

/// Represents a single action in a module contextual menu
class ModuleAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const ModuleAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// Shows a popup menu anchored at [position] with the given [actions].
/// Returns the selected [ModuleAction] or null if dismissed.
Future<ModuleAction?> showModuleActionMenu({
  required BuildContext context,
  required Offset position,
  required List<ModuleAction> actions,
}) async {
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox;

  final selected = await showMenu<ModuleAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(40, 40),
      Offset.zero & overlay.size,
    ),
    items: actions
        .map(
          (action) => PopupMenuItem<ModuleAction>(
            value: action,
            child: Row(
              children: [
                Icon(action.icon, size: 20),
                const SizedBox(width: 12),
                Text(action.label),
              ],
            ),
          ),
        )
        .toList(),
  );

  if (selected != null) {
    selected.onTap();
  }
  return selected;
}
