import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// نفس هوية الألوان المستخدمة في نسخة الويب (from-[#2D9469] to-[#1e6346])
class AppColors {
  static const primary = Color(0xFF2D9469);
  static const primaryDark = Color(0xFF1E6346);
  static const amber = Color(0xFFF59E0B);
  static const bg = Color(0xFFF3F4F6);
  static const cardDark = Color(0xFF0F172A);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.amber,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      useMaterial3: true,
    );
  }
}
