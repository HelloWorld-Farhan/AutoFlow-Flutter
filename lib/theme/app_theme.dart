import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color backgroundWhite = Color(0xFFF8F9FA);
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF8E8E93);
  static const Color accentGreen = Color(0xFF34C759);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(color: textDark),
        bodyMedium: const TextStyle(color: textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
      cardTheme: CardTheme(
        color: cardWhite,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
