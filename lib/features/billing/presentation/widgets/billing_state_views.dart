import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

enum BillingTone { neutral, warning, danger, success }

/// Bordered, flat surface used by the billing screens.
class BillingCard extends StatelessWidget {
  const BillingCard({super.key, required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: context.tokens.border),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

/// Icon + message + optional action. Used for error, empty and unavailable
/// states so none of them is a dead end.
class BillingMessage extends StatelessWidget {
  const BillingMessage({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.tone = BillingTone.neutral,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final BillingTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (fg, bg) = switch (tone) {
      BillingTone.neutral => (theme.colorScheme.onSurfaceVariant, tokens.surfaceMuted),
      BillingTone.warning => (tokens.warning, tokens.warningContainer),
      BillingTone.danger => (tokens.danger, tokens.dangerContainer),
      BillingTone.success => (tokens.success, tokens.successContainer),
    };
    return BillingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: bg, borderRadius: AppRadii.smAll),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(message, style: theme.textTheme.bodyMedium),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact inline status: one message with a leading icon or spinner.
class BillingStatusLine extends StatelessWidget {
  const BillingStatusLine({
    super.key,
    required this.text,
    this.icon,
    this.busy = false,
    this.tone = BillingTone.neutral,
  });

  final String text;
  final IconData? icon;
  final bool busy;
  final BillingTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (iconColor, bg) = switch (tone) {
      BillingTone.neutral => (theme.colorScheme.primary, tokens.surfaceMuted),
      BillingTone.warning => (tokens.warning, tokens.warningContainer),
      BillingTone.danger => (tokens.danger, tokens.dangerContainer),
      BillingTone.success => (tokens.success, tokens.successContainer),
    };
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: AppRadii.mdAll),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 20,
                child: busy
                    ? CircularProgressIndicator(strokeWidth: 2, color: iconColor)
                    : Icon(icon ?? Icons.info_outline, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
