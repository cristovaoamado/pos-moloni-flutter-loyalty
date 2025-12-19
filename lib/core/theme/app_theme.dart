import 'package:flutter/material.dart';
import 'package:pos_moloni_app/core/theme/app_colors.dart';

/// Tema da aplicação optimizado para touch/POS
class AppTheme {
  AppTheme._();

  // Dimensões para touch
  static const double buttonMinHeight = 52.0;
  static const double buttonMinWidth = 120.0;
  static const double touchTargetSize = 48.0;
  static const double borderRadius = 4.0;
  static const double inputHeight = 56.0;

  /// Tema claro (principal)
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,

      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.secondaryDark,

      error: AppColors.error,
      onError: Colors.white,

      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,

      outline: AppColors.grey400,
      outlineVariant: AppColors.grey200,

      tertiary: AppColors.accent,
      onTertiary: AppColors.textPrimary,
      tertiaryContainer: AppColors.accent,
      onTertiaryContainer: AppColors.primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 2,
        centerTitle: false,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(buttonMinWidth, buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(buttonMinWidth, buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(buttonMinWidth, buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // IconButton
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(touchTargetSize, touchTargetSize),
          padding: const EdgeInsets.all(12),
        ),
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(buttonMinWidth, buttonMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 4,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
        hintStyle: const TextStyle(fontSize: 16, color: AppColors.textHint),
      ),

      // Cards
      // Cards - SEM cantos arredondados
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),

      // Dialogs - SEM cantos arredondados
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        backgroundColor: AppColors.surface,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        thickness: 1,
        color: AppColors.divider,
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Tema escuro
  static ThemeData get darkTheme {
    final colorScheme = lightTheme.colorScheme.copyWith(
      brightness: Brightness.dark,
      surface: AppColors.grey800,
      onSurface: AppColors.white,
    );

    return lightTheme.copyWith(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        elevation: 2,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }

  // === ESTILOS POS ===

  static ButtonStyle get primaryActionButtonStyle {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 64),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  static ButtonStyle get secondaryActionButtonStyle {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      side: const BorderSide(color: AppColors.secondary, width: 1.5),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle get quantityButtonStyle {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(56, 56),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static ButtonStyle paymentMethodButtonStyle(bool isSelected) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(120, 80),
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.grey300,
        width: isSelected ? 2 : 1,
      ),
      backgroundColor: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : null,
    );
  }

  static ButtonStyle get productGridButtonStyle {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(100, 100),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static ButtonStyle get dangerButtonStyle {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(buttonMinWidth, buttonMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle get successButtonStyle {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(buttonMinWidth, buttonMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle get warningButtonStyle {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(buttonMinWidth, buttonMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      backgroundColor: AppColors.warning,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}