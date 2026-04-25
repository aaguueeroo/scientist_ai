import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF1E5AA8),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
    ),
  );
}
