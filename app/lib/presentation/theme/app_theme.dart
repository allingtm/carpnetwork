import 'package:flutter/material.dart';

class AppColors {
  static const deepLake = Color(0xFF1B3A4B);
  static const reedGreen = Color(0xFF4A7C59);
  static const goldenHour = Color(0xFFD4A843);
  static const chalkWhite = Color(0xFFF5F5F0);
  static const slate = Color(0xFF2C3E50);
  static const mist = Color(0xFFE8ECEF);
  static const dawn = Color(0xFFFFF8F0);
  static const alertRed = Color(0xFFC0392B);
  static const success = Color(0xFF2E7D32);

  // Fish species colours
  static const commonCarp = deepLake;
  static const mirrorCarp = goldenHour;
  static const leatherCarp = reedGreen;
  static const grassCarp = Color(0xFF81C784);
  static const fullyScaledCarp = Color(0xFF5D8AA8);
  static const ghostCarp = Color(0xFF90A4AE);

  static Color forSpecies(String species) {
    switch (species) {
      case 'common':
        return commonCarp;
      case 'mirror':
        return mirrorCarp;
      case 'leather':
        return leatherCarp;
      case 'grass':
        return grassCarp;
      case 'fully_scaled':
        return fullyScaledCarp;
      case 'ghost':
        return ghostCarp;
      default:
        return deepLake;
    }
  }
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepLake,
      primary: AppColors.deepLake,
      secondary: AppColors.reedGreen,
      tertiary: AppColors.goldenHour,
      surface: AppColors.chalkWhite,
      error: AppColors.alertRed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepLake,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.deepLake.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.deepLake,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.slate,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.mist),
        ),
        color: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepLake,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepLake,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.mist),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.mist),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.slate,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.slate,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.slate,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.slate,
          height: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.slate,
        ),
      ),
    );
  }
}
