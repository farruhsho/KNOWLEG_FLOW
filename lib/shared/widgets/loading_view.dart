import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

class LoadingView extends StatelessWidget {
  final String? message;
  final bool isOverlay;

  const LoadingView({
    super.key,
    this.message,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );

    if (isOverlay) {
      return ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: 0.3),
        child: content,
      );
    }

    return content;
  }
}
