import 'package:flutter/material.dart';

/// ORT Master KG — Anthropic / Claude inspired palette.
///
/// Warm, calm, editorial minimalism. Paper backgrounds, a single clay accent
/// reserved for primary actions, soft 1px borders and quiet neutrals.
///
/// Constant names are preserved from the previous palette so the whole app
/// adopts the new look without touching every call-site. Prefer reading colors
/// from `Theme.of(context).colorScheme` / `AppTokens` in new code.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand accent — "clay". The ONLY saturated color, used for primary actions.
  // ---------------------------------------------------------------------------
  static const Color clay = Color(0xFFC96442);
  static const Color clayHover = Color(0xFFB5573A);
  static const Color clayTint = Color(0xFFF4E8E2); // soft fill on paper

  // Kept names mapped onto the accent so legacy references stay on-brand.
  static const Color primary = clay;
  static const Color primaryDark = clayHover;
  static const Color primaryLight = Color(0xFFD98C72);

  // Secondary / accent now resolve to the same restrained clay family rather
  // than the old green/amber, so legacy gradients stay quiet and cohesive.
  static const Color secondary = Color(0xFF5E7E6E); // muted sage (status only)
  static const Color secondaryDark = Color(0xFF4C6A5B);
  static const Color secondaryLight = Color(0xFF7E9A8B);

  static const Color accent = clay;
  static const Color accentDark = clayHover;
  static const Color accentLight = primaryLight;

  // ---------------------------------------------------------------------------
  // Status — desaturated to fit the editorial tone while staying legible (AA).
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF5E7E6E); // sage
  static const Color warning = Color(0xFFB8862F); // ochre
  static const Color error = Color(0xFFBC4B3C); // brick red
  static const Color info = Color(0xFF52708A); // slate blue

  // ---------------------------------------------------------------------------
  // Subject colors — muted, paper-friendly tones (no neon).
  // ---------------------------------------------------------------------------
  static const Color mathColor = Color(0xFF7B6CA8); // muted violet
  static const Color physicsColor = Color(0xFF52708A); // slate blue
  static const Color chemistryColor = Color(0xFF5E7E6E); // sage
  static const Color biologyColor = Color(0xFF4F8079); // teal-green
  static const Color historyColor = Color(0xFFBC4B3C); // brick
  static const Color geographyColor = Color(0xFFB8862F); // ochre
  static const Color languageColor = Color(0xFFB06B86); // dusty rose

  // ---------------------------------------------------------------------------
  // Neutrals — warm greige ramp (light) used for borders, fills, text.
  // ---------------------------------------------------------------------------
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1A1A18);
  static const Color grey50 = Color(0xFFFAF9F5); // paper
  static const Color grey100 = Color(0xFFF0EEE6); // section
  static const Color grey200 = Color(0xFFE5E3DC); // border
  static const Color grey300 = Color(0xFFD7D4CA);
  static const Color grey400 = Color(0xFFAEAAA0);
  static const Color grey500 = Color(0xFF6B6B66); // secondary text
  static const Color grey600 = Color(0xFF55554F);
  static const Color grey700 = Color(0xFF3D3D3A); // dark border
  static const Color grey800 = Color(0xFF30302E); // dark surface
  static const Color grey900 = Color(0xFF262624); // dark bg

  // ---------------------------------------------------------------------------
  // Surfaces / backgrounds.
  // ---------------------------------------------------------------------------
  static const Color paper = Color(0xFFFAF9F5);
  static const Color section = Color(0xFFF0EEE6);
  static const Color background = paper;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E3DC);

  static const Color backgroundDark = Color(0xFF262624);
  static const Color surfaceDark = Color(0xFF30302E);
  static const Color sectionDark = Color(0xFF2B2B29);
  static const Color borderDark = Color(0xFF3D3D3A);

  // ---------------------------------------------------------------------------
  // Text.
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1A1A18);
  static const Color textSecondary = Color(0xFF6B6B66);
  static const Color textTertiary = Color(0xFF8E8B83);
  static const Color textPrimaryDark = Color(0xFFF5F4EF);
  static const Color textSecondaryDark = Color(0xFFA8A29A);
  static const Color textTertiaryDark = Color(0xFF807C74);

  // ---------------------------------------------------------------------------
  // Gradients — kept for legacy call-sites but flattened to subtle clay washes
  // so we avoid the old acid blue/green gradients.
  // ---------------------------------------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [clay, clayHover],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  static Color getScoreColor(int score) {
    if (score >= 180) return success;
    if (score >= 160) return info;
    if (score >= 120) return warning;
    return error;
  }

  static Color getSubjectColor(String subjectId) {
    switch (subjectId) {
      case 'math':
        return mathColor;
      case 'physics':
        return physicsColor;
      case 'chemistry':
        return chemistryColor;
      case 'biology':
        return biologyColor;
      case 'history':
        return historyColor;
      case 'geography':
        return geographyColor;
      default:
        return languageColor;
    }
  }
}
