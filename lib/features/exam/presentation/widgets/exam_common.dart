import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/exam_failure.dart';
import '../../domain/localized_text.dart';

extension ExamContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// UI language code (ru / ky / en).
  String get uiLang => Localizations.localeOf(this).languageCode;

  String tr(LocalizedText text, {String? lang, String fallback = ''}) =>
      text.resolve(lang ?? uiLang, fallback: fallback);
}

String examFailureMessage(AppLocalizations l, Object? error) {
  final kind = error is ExamFailure ? error.kind : ExamFailureKind.unknown;
  return switch (kind) {
    ExamFailureKind.network => l.examErrorNetwork,
    ExamFailureKind.variantNotAvailable => l.examErrorVariantUnavailable,
    ExamFailureKind.attemptNotFound => l.examErrorAttemptNotFound,
    ExamFailureKind.unauthenticated => l.examErrorSignIn,
    ExamFailureKind.noEntitlement => l.examCostNeedCredit,
    _ => l.examErrorGeneric,
  };
}

String examLanguageName(AppLocalizations l, String code) => switch (code) {
      'ky' => l.examLangKy,
      'en' => l.examLangEn,
      _ => l.examLangRu,
    };

/// "64,7" (ru/ky) or "64.7" (en) — at most one decimal.
String formatExamPercent(double percent, String locale) {
  try {
    final f = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 1
      ..minimumFractionDigits = 0;
    return f.format(percent);
  } catch (_) {
    return percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 1);
  }
}

String formatExamDate(int? epochMs, String locale) {
  if (epochMs == null) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  try {
    return DateFormat.yMMMd(locale).add_Hm().format(d);
  } catch (_) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// `h:mm:ss` or `mm:ss`.
String formatExamDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class ExamLoadingView extends StatelessWidget {
  final String? message;
  const ExamLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? context.l10n.examLoading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExamMessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const ExamMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  factory ExamMessageView.error(
    BuildContext context, {
    Key? key,
    required Object? error,
    VoidCallback? onRetry,
  }) {
    final l = context.l10n;
    return ExamMessageView(
      key: key,
      icon: error is ExamFailure && error.kind == ExamFailureKind.network
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      message: examFailureMessage(l, error),
      actionLabel: onRetry == null ? null : l.examRetry,
      onAction: onRetry,
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40,
                color: isError ? tokens.danger : tokens.textTertiary),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: tokens.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Flat bordered surface used for cards in the exam feature.
class ExamCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const ExamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgAll,
        side: BorderSide(color: borderColor ?? context.tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small rounded label.
class ExamPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const ExamPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
