import 'dart:ui';

/// Extension for Color to provide backward-compatible opacity methods
extension ColorOpacityExtension on Color {
  /// Creates a color with the specified opacity
  /// Uses the new withValues API but provides backward-compatible syntax
  Color withOpacityCompat(double opacity) {
    return withValues(alpha: opacity);
  }
}
