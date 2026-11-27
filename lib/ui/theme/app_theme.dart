import 'package:flutter/material.dart';

/// 브랜드 색상은 여기서 한 번에 변경합니다.
abstract final class AppColors {
  static const primary = Color(0xFF12296B);
  static const primaryDark = Color(0xFF0B1740);
  static const primaryLight = Color(0xFFE7EBF6);
  static const lime = Color(0xFFC5D3F6);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F7FB);
  static const text = Color(0xFF0B1740);
  static const muted = Color(0xFF55607F);
  static const border = Color(0xFFD5DBEA);
  static const blue = Color(0xFF3350A8);
  static const blueLight = Color(0xFFC5D3F6);
  static const amber = Color(0xFF9A5B00);
  static const amberLight = Color(0xFFFFF1D6);
  static const error = Color(0xFFC62828);
  static const errorLight = Color(0xFFFDE7E4);
  static const success = Color(0xFF3A7519);
  static const successLight = Color(0xFFE6F4D7);
  static const accent = Color(0xFF7CC242);
  static const busExpress = Color(0xFFD93A2B);
  static const busTrunk = Color(0xFF1E50C8);
  static const busFeeder = Color(0xFF0A6E50);
}

abstract final class AppNumbers {
  static const hero = TextStyle(
    fontFamily: 'Archivo Black',
    fontSize: 56,
    height: 1,
  );
  static const large = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w700,
  );
  static const medium = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w700,
  );
  static const small = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );
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
      fontFamily: 'IBM Plex Sans KR',
      fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic', 'sans-serif'],
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          height: 40 / 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.96,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.48,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.48,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.16,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
        bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          color: AppColors.muted,
        ),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontFamily: 'IBM Plex Sans KR',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.48,
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
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            fontSize: 12,
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
