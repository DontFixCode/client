import 'package:flutter/material.dart';

/// 브랜드 색상은 여기서 한 번에 변경합니다.
abstract final class AppColors {
  static const primary = Color(0xFF6A7D35);
  static const primaryDark = Color(0xFF46552B);
  static const primaryLight = Color(0xFFEEF1E4);
  static const lime = Color(0xFFE2E8C8);
  static const background = Color(0xFFF0F2EF);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF202824);
  static const muted = Color(0xFF687068);
  static const border = Color(0xFFE2E5DF);
  static const blue = Color(0xFF5874AA);
  static const blueLight = Color(0xFFEDF0F7);
  static const amber = Color(0xFF8D7228);
  static const amberLight = Color(0xFFF6EFDB);
  static const error = Color(0xFF802D29);
}

abstract final class AppTheme {
  static const radius = 20.0;
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.lime,
      onSecondary: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Apple SD Gothic Neo',
      fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic', 'sans-serif'],
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.25,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.35,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.4,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.6, letterSpacing: -.3),
        bodyMedium: TextStyle(fontSize: 14, height: 1.6, letterSpacing: -.2),
        bodySmall: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: AppColors.primaryLight,
        selectedColor: AppColors.lime,
        labelStyle: const TextStyle(color: AppColors.primaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryLight,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
