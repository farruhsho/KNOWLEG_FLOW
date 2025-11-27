import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors (Vibrant Orange/Red for energy)
  static const Color primary = Color(0xFFFF6B35); // Energetic Orange
  static const Color primaryDark = Color(0xFFE85D2A);
  static const Color primaryLight = Color(0xFFFF8F66);
  static const Color primaryContainer = Color(0xFFFFE5D9);

  // Secondary Brand Colors (Deep Blue for trust/knowledge)
  static const Color secondary = Color(0xFF2B2D42); // Dark Blue/Grey
  static const Color secondaryDark = Color(0xFF1A1C29);
  static const Color secondaryLight = Color(0xFF4A4E69);
  static const Color secondaryContainer = Color(0xFFE0E2E8);

  // Accent Colors
  static const Color accent = Color(0xFF8D99AE); // Cool Grey
  static const Color accentDark = Color(0xFF6C757D);
  static const Color accentLight = Color(0xFFAFB8C6);

  // Status Colors
  static const Color success = Color(0xFF06D6A0); // Mint Green
  static const Color warning = Color(0xFFFFD166); // Warm Yellow
  static const Color error = Color(0xFFEF476F); // Soft Red
  static const Color info = Color(0xFF118AB2); // Blue

  // Subject Colors (Modern Pastel/Vibrant mix)
  static const Color mathColor = Color(0xFF4CC9F0); // Cyan
  static const Color physicsColor = Color(0xFF4361EE); // Royal Blue
  static const Color chemistryColor = Color(0xFF7209B7); // Purple
  static const Color biologyColor = Color(0xFF06D6A0); // Mint
  static const Color historyColor = Color(0xFFF72585); // Pink
  static const Color geographyColor = Color(0xFFFF9F1C); // Orange
  static const Color languageColor = Color(0xFF2EC4B6); // Teal

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF8F9FA);
  static const Color grey100 = Color(0xFFF1F3F5);
  static const Color grey200 = Color(0xFFE9ECEF);
  static const Color grey300 = Color(0xFFDEE2E6);
  static const Color grey400 = Color(0xFFCED4DA);
  static const Color grey500 = Color(0xFFADB5BD);
  static const Color grey600 = Color(0xFF868E96);
  static const Color grey700 = Color(0xFF495057);
  static const Color grey800 = Color(0xFF343A40);
  static const Color grey900 = Color(0xFF212529);
  
  // Shorthand
  static const Color grey = grey500;

  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF868E96);
  static const Color textTertiary = Color(0xFFADB5BD);
  static const Color textPrimaryDark = Color(0xFFF8F9FA);
  static const Color textSecondaryDark = Color(0xFFADB5BD);
  static const Color textTertiaryDark = Color(0xFF495057);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF7209B7), Color(0xFFF72585)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF4361EE), Color(0xFF4CC9F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.white24, Colors.white10],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Score Colors
  static Color getScoreColor(int score) {
    if (score >= 180) return success;
    if (score >= 160) return info;
    if (score >= 120) return warning;
    return error;
  }

  // Subject Colors Map
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
