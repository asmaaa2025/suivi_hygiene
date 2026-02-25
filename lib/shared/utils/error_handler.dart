import 'package:flutter/material.dart';

/// Utility class for displaying error and success messages
class ErrorHandler {
  static void showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
