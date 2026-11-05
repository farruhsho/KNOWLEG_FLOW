import 'package:flutter/material.dart';
import '../design/tokens.dart';

/// LEGACY colour façade.
///
/// ~45 older pages reference these static constants directly. They are now
/// mapped onto the new [AppPalette] so the whole app picks up the new visual
/// language without touching every file. These constants are light-mode
/// only — new and migrated code must use `Theme.of(context).colorScheme` and
/// `context.tokens` instead so dark mode works.
class AppColors {
  // Brand
  static const Color primary = AppPalette.blue600;
  static const Color primaryDark = AppPalette.blue700;
  static const Color primaryLight = AppPalette.blue400;
  static const Color primaryContainer = AppPalette.blue50;

  static const Color secondary = AppPalette.n800;
  static const Color secondaryDark = AppPalette.n900;
  static const Color secondaryLight = AppPalette.n600;
  static const Color secondaryContainer = AppPalette.n100;

  static const Color accent = AppPalette.saffron500;
  static const Color accentDark = AppPalette.saffron700;
  static const Color accentLight = AppPalette.saffron300;

  // Status
  static const Color success = AppPalette.green600;
  static const Color warning = AppPalette.amber600;
  static const Color error = AppPalette.red600;
  static const Color info = AppPalette.blue500;

  // Subjects
  static const Color mathColor = AppPalette.blue600;
  static const Color physicsColor = Color(0xFF0E7490);
  static const Color chemistryColor = Color(0xFF7C3AED);
  static const Color biologyColor = AppPalette.green700;
  static const Color historyColor = Color(0xFFB45309);
  static const Color geographyColor = Color(0xFF0F766E);
  static const Color languageColor = Color(0xFF4338CA);

  // Neutrals
  static const Color white = AppPalette.n0;
  static const Color black = AppPalette.n950;
  static const Color grey50 = AppPalette.n50;
  static const Color grey100 = AppPalette.n100;
  static const Color grey200 = AppPalette.n200;
  static const Color grey300 = AppPalette.n300;
  static const Color grey400 = AppPalette.n400;
  static const Color grey500 = AppPalette.n500;
  static const Color grey600 = AppPalette.n600;
  static const Color grey700 = AppPalette.n700;
  static const Color grey800 = AppPalette.n800;
  static const Color grey900 = AppPalette.n900;
  static const Color grey = grey500;

  // Backgrounds
  static const Color background = AppPalette.n50;
  static const Color backgroundDark = AppPalette.n950;
  static const Color surface = AppPalette.n0;
  static const Color surfaceDark = AppPalette.n900;

  // Text
  static const Color textPrimary = AppPalette.n900;
  static const Color textSecondary = AppPalette.n600;
  static const Color textTertiary = AppPalette.n500;
  static const Color textPrimaryDark = AppPalette.darkText;
  static const Color textSecondaryDark = AppPalette.darkTextSecondary;
  static const Color textTertiaryDark = AppPalette.darkTextTertiary;

  // Gradients — kept for API compatibility but deliberately subtle (two
  // adjacent shades) so legacy hero cards read as flat brand surfaces.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppPalette.blue600, AppPalette.blue700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF5B21B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [AppPalette.blue500, AppPalette.blue600],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.white24, Colors.white10],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color getScoreColor(int score) {
    if (score >= 180) return success;
    if (score >= 160) return info;
    if (score >= 120) return warning;
    return error;
  }

  static Color getSubjectColor(String subjectId) => SubjectColors.of(subjectId);
}
