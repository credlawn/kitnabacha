import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  // Format amount with commas (Indian Lakhs/Crores standard format, e.g. ₹12,34,567.89)
  static String formatAmount(double amount) {
    return NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 2).format(amount);
  }

  // Theme Color System
  static const Color darkBg = Color(0xFF0B0F19);       // Deep space dark background
  static const Color darkCard = Color(0xFF161E2E);     // Dark card color
  static const Color darkBorder = Color(0xFF243048);   // Glassmorphic border outline
  static const Color primary = Color(0xFF6366F1);      // Electric Indigo
  static const Color primaryLight = Color(0xFF818CF8); // Bright Indigo

  // Semantic Status Colors
  static const Color creditGreen = Color(0xFF10B981);  // Emerald green (Kitna Lena Hai)
  static const Color creditGreenBg = Color(0xFF064E3B);
  static const Color debitRed = Color(0xFFF43F5E);     // Coral Rose (Kitna Dena Hai)
  static const Color debitRedBg = Color(0xFF4C0519);
  
  static const Color warningOrange = Color(0xFFF59E0B); // Amber for Sync Pending
  static const Color secondaryText = Color(0xFF94A3B8); // Slate 400

  // Light Theme Color System
  static const Color lightBg = Color(0xFFF8FAFC);       // Slate 50 background
  static const Color lightCard = Color(0xFFFFFFFF);     // Pure white cards
  static const Color lightBorder = Color(0xFFE2E8F0);   // Slate 200 border
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900 primary text
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500 secondary text

  // Standard Dark Theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: darkBg,
        surfaceContainerHighest: darkCard,
        error: debitRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F293D),
        hintStyle: const TextStyle(color: secondaryText, fontSize: 14),
        labelStyle: const TextStyle(color: Colors.white70),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  // Standard Light Theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: lightBg,
        surfaceContainerHighest: lightCard,
        error: debitRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9), // Slate 100
        hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: lightTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  // Premium UI Card Gradient
  static const LinearGradient premiumCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B), // Slate 800
      Color(0xFF0F172A), // Slate 900
    ],
  );

  static const LinearGradient premiumCardLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF64748B), // Slate 500
      Color(0xFF475569), // Slate 600
    ],
  );

  // Gradient for Net positive balance card
  static const LinearGradient greenCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF065F46), // Deep Emerald
      Color(0xFF047857), // Mid Emerald
    ],
  );

  // Gradient for Net negative balance card
  static const LinearGradient redCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9F1239), // Deep Rose
      Color(0xFFBE123C), // Mid Rose
    ],
  );

  // Box shadow for premium glassmorphism elevation (Dark Mode)
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.02),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];

  // Box shadow for premium elevation (Light Mode)
  static List<BoxShadow> get premiumLightShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];

  // Glassmorphic border styling (Theme Adaptive)
  static BoxDecoration glassmorphicBox({
    Color? color,
    BorderRadius? borderRadius,
    Gradient? gradient,
    BuildContext? context,
  }) {
    final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? darkCard.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.85)),
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      gradient: gradient,
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        width: 1,
      ),
      boxShadow: isDark ? premiumShadow : premiumLightShadow,
    );
  }
}
