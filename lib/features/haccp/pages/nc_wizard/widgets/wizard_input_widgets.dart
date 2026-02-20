/// Reusable Input Widgets for NC Wizard
///
/// Common input components for consistent UI across wizard steps

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Large text input field
class WizardTextInput extends StatelessWidget {
  final String label;
  final String? helperText;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool required;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const WizardTextInput({
    super.key,
    required this.label,
    this.helperText,
    this.value,
    this.onChanged,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (required)
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator:
              validator ??
              (required
                  ? (v) => v == null || v.isEmpty ? 'Ce champ est requis' : null
                  : null),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}

/// Large dropdown field
class WizardDropdown<T> extends StatelessWidget {
  final String label;
  final String? helperText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;
  final String? Function(T?)? validator;

  /// Texte affiché quand aucune valeur n'est sélectionnée
  final String? hintText;

  const WizardDropdown({
    super.key,
    required this.label,
    this.helperText,
    this.value,
    required this.items,
    this.onChanged,
    this.required = false,
    this.validator,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (required)
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          hint: hintText != null
              ? Text(hintText!, style: TextStyle(color: Colors.grey[600]))
              : null,
          items: items,
          onChanged: onChanged,
          validator:
              validator ??
              (required
                  ? (v) => v == null ? 'Ce champ est requis' : null
                  : null),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.black87,
        ),
      ],
    );
  }
}

/// Date picker field
class WizardDatePicker extends StatelessWidget {
  final String label;
  final String? helperText;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final bool required;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const WizardDatePicker({
    super.key,
    required this.label,
    this.helperText,
    this.value,
    this.onChanged,
    this.required = false,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _selectDate(BuildContext context) async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2100),
        // Remove locale to use system default
        // locale: const Locale('fr', 'FR'),
      );
      if (picked != null && onChanged != null && context.mounted) {
        onChanged!(picked);
      }
    } catch (e, stackTrace) {
      debugPrint('[WizardDatePicker] Error selecting date: $e');
      debugPrint('[WizardDatePicker] Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de la date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (required)
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value != null
                      ? dateFormat.format(value!)
                      : 'Sélectionner une date',
                  style: TextStyle(
                    fontSize: 16,
                    color: value != null ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                Icon(Icons.calendar_today, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// DateTime picker field
class WizardDateTimePicker extends StatelessWidget {
  final String label;
  final String? helperText;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final bool required;

  const WizardDateTimePicker({
    super.key,
    required this.label,
    this.helperText,
    this.value,
    this.onChanged,
    this.required = false,
  });

  Future<void> _selectDateTime(BuildContext context) async {
    try {
      // Try with French locale, fallback to default if not available
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        // Remove locale parameter to use system default if 'fr' causes issues
        // locale: const Locale('fr', 'FR'),
      );
      if (pickedDate == null || !context.mounted) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: value != null
            ? TimeOfDay.fromDateTime(value!)
            : TimeOfDay.now(),
      );
      if (pickedTime == null || !context.mounted) return;

      final combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (onChanged != null) {
        onChanged!(combined);
      }
    } catch (e, stackTrace) {
      debugPrint('[WizardDateTimePicker] Error in _selectDateTime: $e');
      debugPrint('[WizardDateTimePicker] Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de la date/heure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use simple date format without locale to avoid errors
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (required)
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            try {
              await _selectDateTime(context);
            } catch (e) {
              debugPrint(
                '[WizardDateTimePicker] Error selecting date/time: $e',
              );
              // Show error to user
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la sélection: $e')),
                );
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value != null
                      ? dateFormat.format(value!)
                      : 'Sélectionner date/heure',
                  style: TextStyle(
                    fontSize: 16,
                    color: value != null ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                Icon(Icons.access_time, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Large action button
class WizardActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;

  const WizardActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );

    final button = icon != null
        ? (isPrimary
              ? ElevatedButton.icon(
                  onPressed: onPressed,
                  style: buttonStyle as ButtonStyle,
                  icon: Icon(icon),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: onPressed,
                  style: buttonStyle as ButtonStyle,
                  icon: Icon(icon),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ))
        : (isPrimary
              ? ElevatedButton(
                  onPressed: onPressed,
                  style: buttonStyle as ButtonStyle,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : OutlinedButton(
                  onPressed: onPressed,
                  style: buttonStyle as ButtonStyle,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ));

    return SizedBox(width: double.infinity, child: button);
  }
}
