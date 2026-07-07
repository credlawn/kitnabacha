import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppTheme {
  static String formatAmount(double amount, {int decimalDigits = 2}) {
    return NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: decimalDigits)
        .format(amount)
        .replaceFirst('₹', '₹ ');
  }

  // Brand Colors (from logo #152450)
  static const Color primary = Color(0xFF152450);
  static const Color primaryLight = Color(0xFF1E3A5F);
  static const Color primaryDark = Color(0xFF0C1A33);
  static const Color accentBlue = Color(0xFF1877F2);

  // Semantic Colors
  static const Color creditGreen = Color(0xFF059669);
  static const Color creditGreenBg = Color(0xFFD1FAE5);
  static const Color debitRed = Color(0xFFDC2626);
  static const Color debitRedBg = Color(0xFFFEE2E2);
  static const Color warningOrange = Color(0xFFF59E0B);

  // Light Theme Colors (clean white, Facebook-style)
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F8FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E6EB);
  static const Color lightDivider = Color(0xFFCED0D4);
  static const Color textPrimary = Color(0xFF1C1E21);
  static const Color textSecondary = Color(0xFF65676B);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0C1A33);
  static const Color darkCard = Color(0xFF152450);
  static const Color darkSurface = Color(0xFF0F2240);
  static const Color darkBorder = Color(0xFF1E3A5F);
  static const Color darkTextPrimary = Color(0xFFF0F2F5);
  static const Color darkTextSecondary = Color(0xFFB0B8C5);

  // Backward-compatible aliases
  static const Color secondaryText = Color(0xFF65676B);
  static const Color lightTextPrimary = Color(0xFF1C1E21);
  static const Color lightTextSecondary = Color(0xFF65676B);
  static const Color navUnselected = Color(0xFF9CA3AF);
  static const Color darkNavUnselected = Color(0xFF6B7280);
  static const LinearGradient premiumCardGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A5F), Color(0xFF152450)],
  );
  static const LinearGradient premiumCardLightGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A5F), Color(0xFF152450)],
  );
  static const LinearGradient greenCardGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF065F46), Color(0xFF047857)],
  );
  static const LinearGradient redCardGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF9F1239), Color(0xFFBE123C)],
  );

  // Text Theme with Inter
  static TextTheme _textTheme({required bool isDark}) {
    final color = isDark ? darkTextPrimary : textPrimary;
    final secondaryColor = isDark ? darkTextSecondary : textSecondary;
    return GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: color, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: color, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: secondaryColor),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: secondaryColor, letterSpacing: 0.5),
      ),
    );
  }

  // AppBar Theme
  static AppBarTheme _appBarTheme({required bool isDark}) {
    return AppBarTheme(
      backgroundColor: isDark ? darkBg : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleSpacing: 16,
      iconTheme: IconThemeData(color: isDark ? darkTextPrimary : textPrimary),
      titleTextStyle: _textTheme(isDark: isDark).titleLarge?.copyWith(
        color: isDark ? darkTextPrimary : textPrimary,
      ),
    );
  }

  // Card Theme
  static CardThemeData _cardTheme({required bool isDark}) {
    return CardThemeData(
      color: isDark ? darkCard : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? darkBorder : lightBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  // Elevated Button Theme
  static ElevatedButtonThemeData _elevatedButtonTheme({required bool isDark}) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Outlined Button Theme
  static OutlinedButtonThemeData _outlinedButtonTheme({required bool isDark}) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? darkTextPrimary : textPrimary,
        side: BorderSide(color: isDark ? darkBorder : lightBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Input Decoration Theme
  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? darkSurface : lightSurface,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? darkTextSecondary : textSecondary),
      labelStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? darkTextSecondary : textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? darkBorder : lightBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: debitRed.withValues(alpha: 0.5)),
      ),
    );
  }

  // Bottom Navigation Bar Theme
  static NavigationBarThemeData _navBarTheme({required bool isDark}) {
    return NavigationBarThemeData(
      backgroundColor: isDark ? darkBg : Colors.white,
      indicatorColor: primary.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: primary);
        }
        return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? darkTextSecondary : textSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primary, size: 22);
        }
        return IconThemeData(color: isDark ? darkTextSecondary : textSecondary, size: 22);
      }),
    );
  }

  // Divider Theme
  static DividerThemeData _dividerTheme({required bool isDark}) {
    return DividerThemeData(
      color: isDark ? darkBorder : lightDivider,
      thickness: 1,
      space: 1,
    );
  }

  // Bottom Sheet Theme
  static BottomSheetThemeData _bottomSheetTheme({required bool isDark}) {
    return BottomSheetThemeData(
      backgroundColor: isDark ? darkCard : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  // Floating Action Button Theme
  static FloatingActionButtonThemeData _fabTheme({required bool isDark}) {
    return FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      extendedTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  // Chip Theme
  static ChipThemeData _chipTheme({required bool isDark}) {
    return ChipThemeData(
      backgroundColor: isDark ? darkSurface : lightSurface,
      labelStyle: GoogleFonts.inter(fontSize: 12, color: isDark ? darkTextPrimary : textPrimary),
      side: BorderSide(color: isDark ? darkBorder : lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // === Theme Getters ===
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: darkBg,
        surfaceContainerHighest: darkCard,
        error: debitRed,
      ),
      textTheme: _textTheme(isDark: true),
      appBarTheme: _appBarTheme(isDark: true),
      cardTheme: _cardTheme(isDark: true),
      elevatedButtonTheme: _elevatedButtonTheme(isDark: true),
      outlinedButtonTheme: _outlinedButtonTheme(isDark: true),
      inputDecorationTheme: _inputDecorationTheme(isDark: true),
      navigationBarTheme: _navBarTheme(isDark: true),
      dividerTheme: _dividerTheme(isDark: true),
      bottomSheetTheme: _bottomSheetTheme(isDark: true),
      floatingActionButtonTheme: _fabTheme(isDark: true),
      chipTheme: _chipTheme(isDark: true),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        backgroundColor: darkCard,
        elevation: 4,
        actionTextColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightSurface,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: Colors.white,
        surfaceContainerHighest: Colors.white,
        error: debitRed,
      ),
      textTheme: _textTheme(isDark: false),
      appBarTheme: _appBarTheme(isDark: false),
      cardTheme: _cardTheme(isDark: false),
      elevatedButtonTheme: _elevatedButtonTheme(isDark: false),
      outlinedButtonTheme: _outlinedButtonTheme(isDark: false),
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
      navigationBarTheme: _navBarTheme(isDark: false),
      dividerTheme: _dividerTheme(isDark: false),
      bottomSheetTheme: _bottomSheetTheme(isDark: false),
      floatingActionButtonTheme: _fabTheme(isDark: false),
      chipTheme: _chipTheme(isDark: false),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        backgroundColor: primary,
        elevation: 4,
        actionTextColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // === Helper Methods ===
  static void showSnackBar(BuildContext context, String message, {Color? backgroundColor, Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? (Theme.of(context).brightness == Brightness.dark ? darkCard : primary),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  // === Reusable Decorations ===
  static BoxDecoration cardDecoration({bool isDark = false, double radius = 12}) {
    return BoxDecoration(
      color: isDark ? darkCard : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: isDark ? darkBorder : lightBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration balanceCard({required double radius, required Color color}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withValues(alpha: 0.8)],
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static BoxDecoration glassmorphicBox({
    Color? color,
    BorderRadius? borderRadius,
    Gradient? gradient,
    BuildContext? context,
  }) {
    final isDark = context == null ? true : Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? darkCard.withValues(alpha: 0.6) : Colors.white),
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      gradient: gradient,
      border: Border.all(
        color: isDark ? darkBorder.withValues(alpha: 0.5) : lightBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
