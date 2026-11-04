import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Formerly a blurred "glass" panel. The design system has no
/// glassmorphism and BackdropFilter is expensive on low-end phones, so this
/// is now a flat surface with a 1px border. The constructor is unchanged for
/// existing callers; [blur] is ignored, an explicit [color]/[gradient] is
/// still honoured so callers' foreground colours keep their contrast.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.color,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.lgAll;
    final bg = color == null
        ? Theme.of(context).colorScheme.surface
        : color!.withValues(alpha: opacity.clamp(0.0, 1.0) < 0.5 ? 1 : opacity);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: radius,
        border: border ?? Border.all(color: context.tokens.border),
      ),
      child: child,
    );
  }
}
