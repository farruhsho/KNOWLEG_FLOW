import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../services/data_exception.dart';

/// Human message for a failed load (never the raw exception text).
String dataErrorMessage(BuildContext context, Object? error) {
  final l = AppLocalizations.of(context);
  final failure = error is DataException ? error.failure : DataException.from(error ?? 'unknown').failure;
  switch (failure) {
    case DataFailure.offline:
      return l?.learnErrorOffline ?? 'Нет соединения. Проверьте интернет и попробуйте ещё раз.';
    case DataFailure.permissionDenied:
      return l?.learnErrorPermission ?? 'Нет доступа к данным. Войдите в аккаунт ещё раз.';
    case DataFailure.notFound:
      return l?.learnErrorNotFound ?? 'Материал не найден.';
    case DataFailure.unknown:
      return l?.learnErrorGeneric ?? 'Не удалось загрузить данные. Попробуйте ещё раз.';
  }
}

/// Error state with a human message and a retry button.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryText;
  final IconData? icon;
  final String? title;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryText,
    this.icon,
    this.title,
  });

  /// Error view for a load failure; picks the message from [error].
  factory ErrorView.forError(BuildContext context, Object? error, {VoidCallback? onRetry}) =>
      ErrorView(message: dataErrorMessage(context, error), onRetry: onRetry);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.cloud_off_outlined, size: 48, color: context.tokens.danger),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? l?.error ?? 'Ошибка',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText ?? l?.retry ?? 'Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state: nothing to show yet, with an optional action.
class EmptyView extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  const EmptyView({
    super.key,
    required this.message,
    this.subtitle,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined, size: 48, color: context.tokens.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
