import 'package:flutter/material.dart';
import 'admin_colors.dart';
import 'admin_typography.dart';

/// Admin panel theme configuration
class AdminTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AdminTypography.fontFamily,
      
      // Color scheme
      colorScheme: ColorScheme.light(
        primary: AdminColors.primary,
        secondary: AdminColors.secondary,
        error: AdminColors.error,
        surface: AdminColors.surface,
        background: AdminColors.background,
      ),

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AdminTypography.h5,
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
          side: const BorderSide(color: AdminColors.border, width: 1),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: AdminColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          ),
          elevation: 2,
          textStyle: AdminTypography.labelLarge,
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          ),
          side: const BorderSide(color: AdminColors.primary, width: 1.5),
          textStyle: AdminTypography.labelLarge,
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.md,
            vertical: AdminSpacing.sm,
          ),
          textStyle: AdminTypography.labelLarge,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: AdminSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          borderSide: const BorderSide(color: AdminColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        labelStyle: AdminTypography.bodyMedium.copyWith(
          color: AdminColors.textSecondary,
        ),
        hintStyle: AdminTypography.bodyMedium.copyWith(
          color: AdminColors.textTertiary,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.surfaceVariant,
        labelStyle: AdminTypography.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.sm,
          vertical: AdminSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AdminColors.divider,
        thickness: 1,
        space: AdminSpacing.md,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: AdminColors.textSecondary,
        size: 24,
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: AdminTypography.h1,
        displayMedium: AdminTypography.h2,
        displaySmall: AdminTypography.h3,
        headlineLarge: AdminTypography.h4,
        headlineMedium: AdminTypography.h5,
        headlineSmall: AdminTypography.h6,
        bodyLarge: AdminTypography.bodyLarge,
        bodyMedium: AdminTypography.bodyMedium,
        bodySmall: AdminTypography.bodySmall,
        labelLarge: AdminTypography.labelLarge,
        labelMedium: AdminTypography.labelMedium,
        labelSmall: AdminTypography.labelSmall,
      ).apply(
        bodyColor: AdminColors.textPrimary,
        displayColor: AdminColors.textPrimary,
      ),

      // Scaffold background
      scaffoldBackgroundColor: AdminColors.background,
    );
  }

  /// Dark theme (optional, for future implementation)
  static ThemeData get darkTheme {
    // TODO: Implement dark theme if needed
    return lightTheme;
  }
}
