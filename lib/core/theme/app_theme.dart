import 'package:flutter/material.dart';

/// Application theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme,
      scaffoldBackgroundColor: base.scaffoldBackgroundColor,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme,
      scaffoldBackgroundColor: base.scaffoldBackgroundColor,
    );
  }

  // STUB: These are placeholder getters - should be replaced with proper theme colors
  // TODO: Define proper color scheme matching app design
  // TODO: Consider using ColorScheme.fromSeed() for Material 3
  // TODO: Add proper status colors (critical, warning, ok, info) matching HACCP standards
  // TODO: Add proper text colors (primary, secondary, tertiary)
  // TODO: Add proper background colors
  static Color get primaryBlue => Colors.blue;
  static Color get statusCritical => Colors.red;
  static Color get statusCriticalBg => Colors.red.shade50;
  static Color get statusOk => Colors.green;
  static Color get statusWarn => Colors.orange;
  static Color get statusInfo => Colors.blue;
  static Color get textTertiary => Colors.grey;
  static Color get textSecondary => Colors.grey.shade700;
  static Color get backgroundNeutral => Colors.grey.shade100;
  static BorderSide get cardBorder => BorderSide(color: Colors.grey.shade300);
}
