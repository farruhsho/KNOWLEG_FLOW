import 'package:flutter/material.dart';

/// ORT Master design tokens — the single source of truth for colour, spacing,
/// radii, motion and type. Widgets should read colours through
/// `Theme.of(context).colorScheme` or `context.tokens` (see
/// [AppTokens]) so light and dark themes both work; the raw [AppPalette]
/// values are for building themes, not for direct use in pages.
///
/// Visual direction: calm "Issyk-Kul" blue for focus and trust, a warm
/// "tunduk" saffron reserved for progress/XP, cool slate neutrals, flat
/// surfaces separated by 1px borders instead of heavy shadows and gradients.
abstract final class AppPalette {
  // Brand blue
  static const blue50 = Color(0xFFEFF3FF);
  static const blue100 = Color(0xFFDCE4FE);
  static const blue200 = Color(0xFFBFCDFD);
  static const blue300 = Color(0xFF93A9FA);
  static const blue400 = Color(0xFF6B87F4);
  static const blue500 = Color(0xFF4D6BEE);
  static const blue600 = Color(0xFF3A57E8);
  static const blue700 = Color(0xFF2E45C7);
  static const blue800 = Color(0xFF2A3CA0);
  static const blue900 = Color(0xFF26357E);

  // Saffron — XP, streak, rewards. Never used for primary actions.
  static const saffron100 = Color(0xFFFEF0D2);
  static const saffron300 = Color(0xFFFBCB6A);
  static const saffron500 = Color(0xFFF5A524);
  static const saffron700 = Color(0xFFB86E06);
  static const flame = Color(0xFFFF7A1A);

  // Semantic
  static const green50 = Color(0xFFEDFBF2);
  static const green400 = Color(0xFF4ADE80);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const red50 = Color(0xFFFEF1F1);
  static const red400 = Color(0xFFF87171);
  static const red600 = Color(0xFFDC2626);
  static const amber50 = Color(0xFFFFF7E6);
  static const amber400 = Color(0xFFFBBF24);
  static const amber600 = Color(0xFFD97706);

  // Cool slate neutrals
  static const n0 = Color(0xFFFFFFFF);
  static const n25 = Color(0xFFFCFCFD);
  static const n50 = Color(0xFFF7F8FA);
  static const n100 = Color(0xFFF0F2F5);
  static const n150 = Color(0xFFE8EBF0);
  static const n200 = Color(0xFFDDE1E8);
  static const n300 = Color(0xFFC4CAD4);
  static const n400 = Color(0xFF98A1B0);
  static const n500 = Color(0xFF6B7485);
  static const n600 = Color(0xFF4F5868);
  static const n700 = Color(0xFF3A4250);
  static const n800 = Color(0xFF262C38);
  static const n850 = Color(0xFF1C212B);
  static const n900 = Color(0xFF151922);
  static const n950 = Color(0xFF0D1016);
  static const darkText = Color(0xFFF2F4F7);
  static const darkTextSecondary = Color(0xFFA9B1BF);
  static const darkTextTertiary = Color(0xFF7D8696);
}

/// Subject accent colours — muted so a screen with several subjects does not
/// look like a candy box. Keys match subject ids used in Firestore and in
/// exam blueprints.
abstract final class SubjectColors {
  static const Map<String, Color> byId = {
    'math': AppPalette.blue600,
    'mathematics': AppPalette.blue600,
    'physics': Color(0xFF0E7490),
    'chemistry': Color(0xFF7C3AED),
    'biology': AppPalette.green700,
    'history': Color(0xFFB45309),
    'history_kg': Color(0xFFB45309),
    'english': Color(0xFF0369A1),
    'kyrgyz_lang': AppPalette.red600,
    'kyrgyz': AppPalette.red600,
    'state_language': AppPalette.red600,
    'russian_lang': Color(0xFF4338CA),
    'russian': Color(0xFF4338CA),
    'analogies': Color(0xFFDB2777),
    'reading': Color(0xFF0F766E),
    'grammar': Color(0xFF9333EA),
  };

  static Color of(String? id) => byId[id] ?? AppPalette.n500;
}

/// 4-pt spacing scale.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  /// Horizontal page gutter. 16 on phones narrower than 400dp, 20 otherwise.
  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 400 ? lg : xl;

  /// Minimum touch target (Material / Android accessibility guideline).
  static const double minTouch = 48;
}

abstract final class AppRadii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

/// Motion. Keep animations short and never block input; honour the system
/// "remove animations" setting via [AppMotion.of].
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Returns [d], or zero when the user asked the OS to disable animations.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}

/// Semantic colours that Material's [ColorScheme] does not model. Read with
/// `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color xp;
  final Color xpContainer;
  final Color streak;
  final Color border;
  final Color borderStrong;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color textSecondary;
  final Color textTertiary;

  const AppTokens({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.xp,
    required this.xpContainer,
    required this.streak,
    required this.border,
    required this.borderStrong,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.textSecondary,
    required this.textTertiary,
  });

  static const light = AppTokens(
    success: AppPalette.green600,
    successContainer: AppPalette.green50,
    warning: AppPalette.amber600,
    warningContainer: AppPalette.amber50,
    danger: AppPalette.red600,
    dangerContainer: AppPalette.red50,
    xp: AppPalette.saffron700,
    xpContainer: AppPalette.saffron100,
    streak: AppPalette.flame,
    border: AppPalette.n200,
    borderStrong: AppPalette.n300,
    surfaceMuted: AppPalette.n100,
    surfaceRaised: AppPalette.n0,
    textSecondary: AppPalette.n600,
    textTertiary: AppPalette.n500,
  );

  static const dark = AppTokens(
    success: AppPalette.green400,
    successContainer: Color(0xFF12301F),
    warning: AppPalette.amber400,
    warningContainer: Color(0xFF33270D),
    danger: AppPalette.red400,
    dangerContainer: Color(0xFF3A1717),
    xp: AppPalette.saffron300,
    xpContainer: Color(0xFF3A2A0C),
    streak: AppPalette.flame,
    border: AppPalette.n800,
    borderStrong: AppPalette.n700,
    surfaceMuted: AppPalette.n850,
    surfaceRaised: AppPalette.n850,
    textSecondary: AppPalette.darkTextSecondary,
    textTertiary: AppPalette.darkTextTertiary,
  );

  @override
  AppTokens copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? xp,
    Color? xpContainer,
    Color? streak,
    Color? border,
    Color? borderStrong,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? textSecondary,
    Color? textTertiary,
  }) {
    return AppTokens(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      xp: xp ?? this.xp,
      xpContainer: xpContainer ?? this.xpContainer,
      streak: streak ?? this.streak,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      xp: Color.lerp(xp, other.xp, t)!,
      xpContainer: Color.lerp(xpContainer, other.xpContainer, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  /// Semantic design tokens for the current theme brightness.
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppTokens.dark
          : AppTokens.light);
}
