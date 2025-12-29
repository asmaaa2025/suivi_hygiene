// CONTEXT: Flutter UI modernisation
// OBJECTIF: Style minimaliste et élégant pour l'application de relevé de températures

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildWowTheme() {
  return ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.grey.shade800,
    scaffoldBackgroundColor: Colors.grey.shade50,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade900,
      ),
      iconTheme: IconThemeData(color: Colors.grey.shade900),
    ),
    textTheme: GoogleFonts.montserratTextTheme().copyWith(
      bodyMedium: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: TextStyle(color: Colors.grey.shade700),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: Colors.grey.shade700),
      fillColor: WidgetStateProperty.all(Colors.grey.shade800),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: Colors.grey.shade900,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade300,
      thickness: 1,
    ),
  );
}
