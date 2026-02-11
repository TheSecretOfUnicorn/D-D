import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Palette de couleurs "Donjon Sombre"
  static const Color primary = Color(0xFF8B0000); // Rouge Sang séché
  static const Color accent = Color(0xFFFFD700);  // Or
  static const Color background = Color(0xFF1A1A1A); // Gris très sombre (Charbon)
  static const Color surface = Color(0xFF2C2C2C); // Gris pierre pour les cartes
  static const Color textMain = Color(0xFFE0E0E0); // Blanc cassé
  static const Color textMuted = Color(0xFFA0A0A0); // Gris clair

  static ThemeData get darkFantasy {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      
      // Configuration des couleurs globales
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        onSurface: textMain,
      ),

      // Typographie
      textTheme: TextTheme(
        displayLarge: GoogleFonts.cinzel(fontSize: 32, fontWeight: FontWeight.bold, color: accent),
        displayMedium: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.bold, color: textMain),
        titleLarge: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: accent),
        bodyLarge: GoogleFonts.lora(fontSize: 16, color: textMain),
        bodyMedium: GoogleFonts.lora(fontSize: 14, color: textMain),
      ),

      // Style des Cards (Fiches, Items)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withAlpha(26), width: 1), // 26 = 10% de transparence sur 255
        ),
      ),

      // Style de l'AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.bold, color: accent),
        iconTheme: const IconThemeData(color: accent),
        elevation: 0,
      ),

      // Style des Boutons Flottants (FAB)
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black, // Texte noir sur fond or pour le contraste
      ),

      // Style des Inputs (Champs de texte)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent),
        ),
        labelStyle: GoogleFonts.lora(color: textMuted),
      ),
    );
  }
}