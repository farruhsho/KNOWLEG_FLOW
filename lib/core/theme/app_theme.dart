import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

/// ORT Master KG theme — Claude / Anthropic inspired editorial minimalism.
///
/// Warm paper backgrounds, a single clay accent for primary actions, soft 1px
/// borders, minimal shadows, and large low-weight headings with generous
/// line-height. Light + dark are fully defined and selected via
/// `ThemeMode.system`.
class AppTheme {
  AppTheme._();

  /// Left null so the platform's clean system sans is used (San Francisco /
  /// Roboto / Segoe). Bundle "Inter" under pubspec `fonts:` and set this to
  /// 'Inter' to match the Anthropic type exactly.
  static const String? _fontFamily = null;

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        tokens: AppTokens.light,
        overlay: SystemUiOverlayStyle.dark,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        tokens: AppTokens.dark,
        overlay: SystemUiOverlayStyle.light,
      );

  // ---------------------------------------------------------------------------
  static ThemeData _build({
    required Brightness brightness,
    required AppTokens tokens,
    required SystemUiOverlayStyle overlay,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: AppColors.white,
      primaryContainer: tokens.accentTint,
      onPrimaryContainer: tokens.accent,
      secondary: tokens.accent,
      onSecondary: AppColors.white,
      secondaryContainer: tokens.accentTint,
      onSecondaryContainer: tokens.accent,
      error: tokens.danger,
      onError: AppColors.white,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      surfaceContainerHighest: tokens.section,
      onSurfaceVariant: tokens.textSecondary,
      outline: tokens.border,
      outlineVariant: tokens.border,
    );

    final textTheme = _textTheme(tokens);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.paper,
      canvasColor: tokens.paper,
      dividerColor: tokens.border,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[tokens],

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: tokens.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        systemOverlayStyle: overlay,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        iconTheme: IconThemeData(color: tokens.textPrimary, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: BorderSide(color: tokens.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: tokens.accent.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.8),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return Colors.black.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          backgroundColor: tokens.surface,
          minimumSize: const Size(0, AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          minimumSize: const Size(0, AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          minimumSize: const Size(
            AppTokens.minTouchTarget,
            AppTokens.minTouchTarget,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? tokens.section : AppColors.white,
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: tokens.accent),
        prefixIconColor: tokens.textTertiary,
        suffixIconColor: tokens.textTertiary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(tokens.border),
        enabledBorder: _inputBorder(tokens.border),
        focusedBorder: _inputBorder(tokens.accent, width: 1.5),
        errorBorder: _inputBorder(tokens.danger),
        focusedErrorBorder: _inputBorder(tokens.danger, width: 1.5),
        errorStyle: textTheme.bodySmall?.copyWith(color: tokens.danger),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: tokens.section,
        selectedColor: tokens.accentTint,
        disabledColor: tokens.section,
        labelStyle: textTheme.labelMedium?.copyWith(color: tokens.textPrimary),
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: tokens.accent),
        side: BorderSide(color: tokens.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.section,
        circularTrackColor: tokens.section,
        linearMinHeight: 6,
      ),

      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surface,
        selectedItemColor: tokens.accent,
        unselectedItemColor: tokens.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.accentTint,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.grey800 : AppColors.black,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: BorderSide(color: tokens.border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: tokens.textSecondary,
        textColor: tokens.textPrimary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.accent;
          return isDark ? AppColors.grey400 : AppColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accent.withValues(alpha: 0.35);
          }
          return tokens.section;
        }),
      ),

      textTheme: textTheme,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusInput),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Editorial type scale — large, low-weight headings, ~1.5 line-height,
  /// slightly tightened tracking on display sizes.
  static TextTheme _textTheme(AppTokens t) {
    final primary = t.textPrimary;
    final secondary = t.textSecondary;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 19,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: t.textTertiary,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: secondary,
      ),
    );
  }
}
