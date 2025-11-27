import 'package:flutter/material.dart';

/// Admin panel color scheme
/// Based on professional education platform design
class AdminColors {
  // Primary - глубокий синий (доверие, образование)
  static const primary = Color(0xFF1E3A5F);
  static const primaryLight = Color(0xFF2E5077);
  static const primaryDark = Color(0xFF0F2744);

  // Secondary - бирюзовый (свежесть, прогресс)
  static const secondary = Color(0xFF00BFA6);
  static const secondaryLight = Color(0xFF5DF2D6);
  static const secondaryDark = Color(0xFF008E76);

  // Accent - оранжевый (энергия, важность)
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFF9A6C);
  static const accentDark = Color(0xFFCC4A1C);

  // Semantic colors
  static const success = Color(0xFF4CAF50);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFFFC107);
  static const warningLight = Color(0xFFFFF8E1);
  static const error = Color(0xFFE53935);
  static const errorLight = Color(0xFFFFEBEE);
  static const info = Color(0xFF2196F3);
  static const infoLight = Color(0xFFE3F2FD);

  // Neutrals
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F2F5);
  static const border = Color(0xFFE0E4E8);
  static const divider = Color(0xFFEEEEEE);

  // Text
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Subject Colors (для каждого предмета)
  static const math = Color(0xFF6366F1); // индиго
  static const physics = Color(0xFFEC4899); // розовый
  static const chemistry = Color(0xFF10B981); // изумруд
  static const biology = Color(0xFF84CC16); // лайм
  static const history = Color(0xFFF59E0B); // янтарь
  static const geography = Color(0xFF06B6D4); // циан
  static const language = Color(0xFF8B5CF6); // фиолет
  static const reading = Color(0xFFF97316); // оранжевый

  /// Get subject color by subject ID
  static Color getSubjectColor(String subjectId) {
    switch (subjectId.toLowerCase()) {
      case 'math':
      case 'mathematics':
      case 'математика':
        return math;
      case 'physics':
      case 'физика':
        return physics;
      case 'chemistry':
      case 'химия':
        return chemistry;
      case 'biology':
      case 'биология':
        return biology;
      case 'history':
      case 'история':
        return history;
      case 'geography':
      case 'география':
        return geography;
      case 'language':
      case 'язык':
        return language;
      case 'reading':
      case 'чтение':
        return reading;
      default:
        return primary;
    }
  }

  /// Create gradient for backgrounds
  static LinearGradient primaryGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static LinearGradient secondaryGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );

  static LinearGradient accentGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );
}
