import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design/tokens.dart';

/// App-wide Material 3 themes built from [AppPalette] / [AppTokens].
///
/// Typeface: Inter for everything. Unlike the previous Outfit headings, Inter
/// ships the Cyrillic Extended glyphs Kyrgyz needs (ң, ө, ү), so headings no
/// longer fall back to a different system font mid-word.
class AppTheme {
  AppTheme._();

  // Built once; MaterialApp rebuilds must not re-create ThemeData.
  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle s(double size, double height, FontWeight w,
            {double spacing = 0, Color? color}) =>
        GoogleFonts.inter(
          fontSize: size,
          height: height / size,
          fontWeight: w,
          letterSpacing: spacing,
          color: color ?? primary,
        );
    return TextTheme(
      displayLarge: s(40, 48, FontWeight.w700, spacing: -1.0),
      displayMedium: s(32, 40, FontWeight.w700, spacing: -0.6),
      displaySmall: s(28, 36, FontWeight.w700, spacing: -0.4),
      headlineLarge: s(26, 34, FontWeight.w700, spacing: -0.4),
      headlineMedium: s(22, 30, FontWeight.w700, spacing: -0.3),
      headlineSmall: s(20, 28, FontWeight.w600, spacing: -0.2),
      titleLarge: s(18, 26, FontWeight.w600, spacing: -0.1),
      titleMedium: s(16, 24, FontWeight.w600),
      titleSmall: s(14, 20, FontWeight.w600),
      bodyLarge: s(16, 24, FontWeight.w400),
      bodyMedium: s(15, 22, FontWeight.w400),
      bodySmall: s(13, 18, FontWeight.w400, color: secondary),
      labelLarge: s(15, 20, FontWeight.w600),
      labelMedium: s(13, 18, FontWeight.w600),
      labelSmall: s(12, 16, FontWeight.w500, spacing: 0.1, color: secondary),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final t = dark ? AppTokens.dark : AppTokens.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? AppPalette.blue300 : AppPalette.blue600,
      onPrimary: dark ? AppPalette.n950 : AppPalette.n0,
      primaryContainer: dark ? const Color(0xFF1E2A5C) : AppPalette.blue50,
      onPrimaryContainer: dark ? AppPalette.blue100 : AppPalette.blue800,
      secondary: dark ? AppPalette.saffron300 : AppPalette.saffron700,
      onSecondary: dark ? AppPalette.n950 : AppPalette.n0,
      secondaryContainer: t.xpContainer,
      onSecondaryContainer: dark ? AppPalette.saffron100 : AppPalette.saffron700,
      tertiary: dark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
      onTertiary: dark ? AppPalette.n950 : AppPalette.n0,
      error: t.danger,
      onError: dark ? AppPalette.n950 : AppPalette.n0,
      errorContainer: t.dangerContainer,
      onErrorContainer: dark ? AppPalette.red400 : AppPalette.red600,
      surface: dark ? AppPalette.n900 : AppPalette.n0,
      onSurface: dark ? AppPalette.darkText : AppPalette.n900,
      onSurfaceVariant: t.textSecondary,
      surfaceContainerLowest: dark ? AppPalette.n950 : AppPalette.n0,
      surfaceContainerLow: dark ? AppPalette.n900 : AppPalette.n25,
      surfaceContainer: dark ? AppPalette.n850 : AppPalette.n50,
      surfaceContainerHigh: dark ? AppPalette.n800 : AppPalette.n100,
      surfaceContainerHighest: dark ? AppPalette.n700 : AppPalette.n150,
      outline: t.borderStrong,
      outlineVariant: t.border,
      shadow: AppPalette.n950,
      scrim: AppPalette.n950,
      inverseSurface: dark ? AppPalette.n100 : AppPalette.n850,
      onInverseSurface: dark ? AppPalette.n900 : AppPalette.n50,
      inversePrimary: dark ? AppPalette.blue600 : AppPalette.blue300,
    );

    final text = _textTheme(scheme.onSurface, t.textSecondary);
    final background = dark ? AppPalette.n950 : AppPalette.n50;

    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md));
    const buttonPadding =
        EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14);
    const buttonMinSize = Size(64, AppSpacing.minTouch);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [t],
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      fontFamily: GoogleFonts.inter().fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgAll,
          side: BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        // Legacy pages use ElevatedButton; render it flat like FilledButton.
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: t.borderStrong),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSpacing.minTouch),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppPalette.n900 : AppPalette.n0,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
        hintStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceMuted,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        // 11px keeps the longest tab label ("Экзамендер", ky) on one line on a
        // 360dp phone (5 tabs × 72dp); NavigationDestination has no maxLines.
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            text.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: 0,
              color: states.contains(WidgetState.selected)
                  ? scheme.onSurface
                  : t.textSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : t.textSecondary,
            )),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: t.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: text.labelSmall,
        unselectedLabelStyle: text.labelSmall,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        iconColor: t.textSecondary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: t.surfaceMuted,
        circularTrackColor: t.surfaceMuted,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        labelColor: scheme.onSurface,
        unselectedLabelColor: t.textSecondary,
        indicatorColor: scheme.primary,
        dividerColor: t.border,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: t.borderStrong),
          textStyle: text.labelMedium,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
