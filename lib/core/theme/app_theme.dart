import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const card = Color(0xFF121212);
  static const cardHover = Color(0xFF1B1D1D);
  static const iconSurface = Color(0xFF1B1D1D);
  static const accent = Color(0xFFC8FF00); // Electric Lime matching Figma
  static const accentDark = Color(0xFFAABB00);
  static const accentTint = Color(0xFF26320D);
  static const accentPill = Color(0xFF202815);
  static const chartBarMuted = Color(0xFF3A4A19);
  static const secondary = Color(0xFF00E5FF); // Cyan from web
  static const textPrimary = Color(0xFFF8F9FA);
  static const textSecondary = Color(0xFFA2ABB2);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFF2A2D2E);
  static const borderSubtle = Color(0xFF1E1E1E);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const successPillBg = Color(0xFF1D3023);
  static const successPillText = Color(0xFFA9D8B5);
  static const warning = Color(0xFFF59E0B);
  static const warningPillBg = Color(0xFF342918);
  static const warningPillText = Color(0xFFE8B86D);
  static const infoPillBg = Color(0xFF1F2B38);
  static const infoPillText = Color(0xFFADC8E8);
  static const tabBar = Color(0xFF0A0A0A);
}

class AppTheme {
  static Color? parseHexColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return null;
    final clean = hexString.trim().replaceFirst('#', '');
    final buffer = StringBuffer();
    if (clean.length == 6) {
      buffer.write('ff');
      buffer.write(clean);
    } else if (clean.length == 8) {
      buffer.write(clean);
    } else {
      return null;
    }
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  static ThemeData get dark => getTheme();

  static ThemeData getTheme({Color? customPrimary, Color? customSecondary}) {
    final primary = customPrimary ?? AppColors.accent;
    final secondary = customSecondary ?? primary;
    final onPrimary =
        primary.computeLuminance() > 0.5 ? const Color(0xFF000000) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: onPrimary,
        onSecondary:
            secondary.computeLuminance() > 0.5 ? const Color(0xFF000000) : Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.figtree(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.tabBar,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle:
              GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
      fontFamily: GoogleFonts.figtree().fontFamily,
      textTheme:
          GoogleFonts.figtreeTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.figtree(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.figtree(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
        ),
        bodyLarge: GoogleFonts.figtree(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.figtree(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
