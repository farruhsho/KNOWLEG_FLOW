import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Design tokens exposed through the theme so widgets can read spacing, radii
/// and semantic surface colors without hardcoding values.
///
/// Usage: `final t = Theme.of(context).extension<AppTokens>()!;`
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.paper,
    required this.section,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.accentTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Brightness brightness;

  /// App background ("paper").
  final Color paper;

  /// Grouped/section background, one step from paper.
  final Color section;

  /// Card / elevated surface.
  final Color surface;

  /// Hairline border (1px).
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color accent;
  final Color accentHover;

  /// Soft accent fill for chips / badges on paper.
  final Color accentTint;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  // --- Spacing scale (4 / 8pt grid) -----------------------------------------
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // --- Radii ------------------------------------------------------------------
  static const double radiusButton = 8;
  static const double radiusInput = 8;
  static const double radiusCard = 12;
  static const double radiusPill = 999;

  // --- Touch target -----------------------------------------------------------
  static const double minTouchTarget = 48;

  static const AppTokens light = AppTokens(
    brightness: Brightness.light,
    paper: AppColors.paper,
    section: AppColors.section,
    surface: AppColors.surface,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    accent: AppColors.clay,
    accentHover: AppColors.clayHover,
    accentTint: AppColors.clayTint,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    info: AppColors.info,
  );

  static const AppTokens dark = AppTokens(
    brightness: Brightness.dark,
    paper: AppColors.backgroundDark,
    section: AppColors.sectionDark,
    surface: AppColors.surfaceDark,
    border: AppColors.borderDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    accent: AppColors.clay,
    accentHover: AppColors.clayHover,
    accentTint: Color(0x33C96442),
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    info: AppColors.info,
  );

  @override
  AppTokens copyWith({
    Brightness? brightness,
    Color? paper,
    Color? section,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentHover,
    Color? accentTint,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return AppTokens(
      brightness: brightness ?? this.brightness,
      paper: paper ?? this.paper,
      section: section ?? this.section,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentTint: accentTint ?? this.accentTint,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      paper: Color.lerp(paper, other.paper, t)!,
      section: Color.lerp(section, other.section, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Convenience accessor.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
