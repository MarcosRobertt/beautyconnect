import 'package:flutter/material.dart';

/// Tema Material 3 do BeautyConnect.
/// Paleta berry/rosa (mundo da manicure), consistente com o protótipo
/// validado com a cliente antes desta implementação em Flutter.
class AppTheme {
  static const Color primary = Color(0xFF8C2F5C);
  static const Color primaryContainer = Color(0xFFFFD8E9);
  static const Color secondaryContainer = Color(0xFFFBD9E7);
  static const Color surface = Color(0xFFFFFBFF);
  static const Color surfaceDim = Color(0xFFF6EEF1);
  static const Color error = Color(0xFFBA1A4A);
  static const Color success = Color(0xFF2E7D4F);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      primaryContainer: primaryContainer,
      secondaryContainer: secondaryContainer,
      surface: surface,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDim,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        color: surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
