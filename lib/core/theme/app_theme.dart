import 'package:flutter/material.dart';

/// Tema Material 3 do BeautyConnect — Identidade Visual Verde Condeza.
class AppTheme {
  static const Color primary = Color(0xFF627970); 
  static const Color primaryContainer = Color(0xFFE6EBE4);
  static const Color secondaryContainer = Color(0xFFDDE3DB); 
  static const Color surface = Color(0xFFFFFFFF); // Fundo puro para os cartões
  static const Color surfaceDim = Color(0xFFF7F8F4); // Fundo Creme da imagem para a aplicação
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: surface,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: primary,
          side: const BorderSide(color: primary),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDim,
        foregroundColor: const Color(0xFF2C3532), // Texto Escuro Condeza
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: primary),
      ),
      
      tabBarTheme: TabBarTheme(
        labelColor: primary,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}
