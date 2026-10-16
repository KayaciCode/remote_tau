import 'package:flutter/material.dart';

class AppTheme {
  // Global theme notifier for instant reactive switching
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  static bool isDark(BuildContext context) {
    return themeNotifier.value == ThemeMode.dark;
  }

  static void toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  // Brand Accent Colors
  static const Color accentRed = Color(0xFFE11D48);
  static const Color accentRedDark = Color(0xFFBE123C);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentAmber = Color(0xFFF59E0B);

  // Dark Theme Palette
  static const Color darkBg = Color(0xFF0B0E14);
  static const Color darkHeaderBg = Color(0xFF0E131F);
  static const Color darkSidebarBg = Color(0xFF0D111A);
  static const Color darkCardBg = Color(0xFF111722);
  static const Color darkCardBorder = Color(0x22FFFFFF);
  static const Color darkTerminalBg = Color(0xFF070A10);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Theme Palette
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightHeaderBg = Color(0xFFFFFFFF);
  static const Color lightSidebarBg = Color(0xFFF8FAFC);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTerminalBg = Color(0xFF0F172A);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dynamic Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: accentCyan,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentRed,
        surface: darkCardBg,
        background: darkBg,
      ),
      cardColor: darkCardBg,
      dividerColor: darkCardBorder,
      useMaterial3: true,
      fontFamily: 'Segoe UI',
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: accentBlue,
      colorScheme: const ColorScheme.light(
        primary: accentBlue,
        secondary: accentRed,
        surface: lightCardBg,
        background: lightBg,
      ),
      cardColor: lightCardBg,
      dividerColor: lightCardBorder,
      useMaterial3: true,
      fontFamily: 'Segoe UI',
    );
  }

  // Dynamic Card Decoration
  static BoxDecoration cardDecoration({
    required bool isDark,
    Color? borderCol,
    Color? customBg,
    double radius = 14,
  }) {
    return BoxDecoration(
      color: customBg ?? (isDark ? darkCardBg : lightCardBg),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderCol ?? (isDark ? darkCardBorder : lightCardBorder),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0C000000),
          blurRadius: isDark ? 16 : 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

