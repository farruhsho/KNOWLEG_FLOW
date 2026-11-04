import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_contract.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/network/firebase_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/paged_list.dart';
import '../../data/repositories/content_repositories.dart';
import '../../data/repositories/exam_repositories.dart';
import '../../domain/callable_errors.dart';
import '../../domain/review_workflow.dart';

/// Human message for any error the CMS can hit (never a raw stack trace).
///
/// [appCheckAvailable] defaults to whether this platform activates App Check
/// ([FirebaseService.supportsAppCheck]) and [appCheckEnforced] to whether the
/// backend enforces it on admin callables ([kAdminAppCheckEnforced]); tests
/// pass them explicitly.
String adminErrorMessage(
  AppLocalizations l,
  Object error, {
  bool? appCheckAvailable,
  bool appCheckEnforced = kAdminAppCheckEnforced,
}) {
  if (error is FirebaseFunctionsException) {
    final reason = BackendReasons.of(error);
    switch (classifyAdminCallableError(
      code: error.code,
      reason: reason,
      message: error.message,
      appCheckAvailable: appCheckAvailable ?? FirebaseService.supportsAppCheck,
      appCheckEnforced: appCheckEnforced,
    )) {
      case AdminCallableIssue.appCheckUnavailable:
        return l.adminErrAppCheckPlatform;
      case AdminCallableIssue.appCheckRejected:
        return l.adminErrAppCheckRejected;
      case AdminCallableIssue.sessionExpired:
        return l.adminErrSessionExpired;
      case AdminCallableIssue.userBanned:
        return l.adminErrUserBanned;
      case null:
        break;
    }
    if (reason == BackendReasons.forbiddenRole) return l.adminErrForbidden;
    if (reason == BackendReasons.validationFailed) {
      return l.adminErrValidation(error.message ?? '');
    }
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return l.adminErrForbidden;
      case 'not-found':
      case 'unimplemented':
        return l.adminErrFunctionMissing;
      case 'unavailable':
      case 'deadline-exceeded':
        return l.adminErrNetwork;
      case 'resource-exhausted':
        return l.adminErrQuota;
      case 'invalid-argument':
      case 'failed-precondition':
        return l.adminErrValidation(error.message ?? '');
    }
    return l.adminErrGeneric(error.message ?? error.code);
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return l.adminLoginErrCredentials;
      case 'user-disabled':
        return l.adminLoginErrDisabled;
      case 'too-many-requests':
        return l.adminLoginErrTooMany;
      case 'network-request-failed':
        return l.adminErrNetwork;
    }
    return l.adminErrGeneric(error.message ?? error.code);
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return l.adminErrForbidden;
      case 'unavailable':
      case 'deadline-exceeded':
      case 'retry-limit-exceeded':
        return l.adminErrNetwork;
      case 'failed-precondition':
        return l.adminErrIndex;
      case 'not-found':
      case 'object-not-found':
        return l.adminErrNotFound;
    }
    return l.adminErrGeneric(error.message ?? error.code);
  }
  if (error is SubjectExistsException) return l.adminSubjectsErrExists;
  if (error is SubjectInUseException) {
    final u = error.usage;
    return l.adminSubjectsErrInUse(u.lessons, u.questions, u.examQuestions);
  }
  if (error is MediaTooLargeException) {
    return l.adminErrFileTooLarge((error.maxBytes / (1024 * 1024)).round());
  }
  if (error is UnsupportedMediaTypeException) {
    return l.adminErrUnsupportedMedia(error.extension.isEmpty ? '?' : error.extension.toUpperCase());
  }
  if (error is MissingKeyException) return l.adminExamErrApproveNoKey;
  if (error is QuestionNotFoundException) return l.adminErrNotFound;
  if (error is VariantPublishedException) return l.adminVariantsErrPublished;
  return l.adminErrUnknown;
}

void showAdminSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.adminCancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class AdminLoadingView extends StatelessWidget {
  const AdminLoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(label!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
}

class AdminMessageView extends StatelessWidget {
  const AdminMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.action,
    this.color,
  });

  final IconData icon;
  final String? title;
  final String message;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: color ?? context.tokens.textTertiary),
              const SizedBox(height: AppSpacing.md),
              if (title != null) ...[
                Text(title!, style: text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(message,
                  style: text.bodyMedium?.copyWith(color: context.tokens.textSecondary),
                  textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AdminMessageView(
      icon: Icons.error_outline,
      color: context.tokens.danger,
      title: l.adminErrTitle,
      message: adminErrorMessage(l, error),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l.adminRetry),
            ),
    );
  }
}

class AdminEmptyView extends StatelessWidget {
  const AdminEmptyView({super.key, required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      AdminMessageView(icon: Icons.inbox_outlined, message: message, action: action);
}

class AdminForbiddenView extends StatelessWidget {
  const AdminForbiddenView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AdminMessageView(
      icon: Icons.lock_outline,
      title: l.adminForbiddenTitle,
      message: l.adminForbiddenBody,
    );
  }
}

/// Loading / error (with retry) / data for an [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const AdminLoadingView(),
        error: (e, _) => AdminErrorView(error: e, onRetry: onRetry),
      );
}

/// Page body with a constrained readable width and gutters.
class AdminPageBody extends StatelessWidget {
  const AdminPageBody({super.key, required this.children, this.maxWidth = 1100});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final g = AppSpacing.gutter(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(g, AppSpacing.lg, g, AppSpacing.huge * 2),
      children: [
        for (final c in children)
          Center(
            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: c),
          ),
      ],
    );
  }
}

/// Flat bordered card with an optional title row.
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, this.title, this.trailing, required this.child, this.padding});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: context.tokens.border),
      ),
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// Wrap of filter controls that reflows on narrow screens.
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter(context),
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
}

/// Compact dropdown used in filter bars. `null` value = "all".
class AdminDropdown<T> extends StatelessWidget {
  const AdminDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.allLabel,
    this.width = 180,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  /// When set, an extra "all" entry mapping to `null` is shown.
  final String? allLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    final entries = <DropdownMenuItem<T?>>[
      if (allLabel != null) DropdownMenuItem<T?>(value: null, child: Text(allLabel!)),
      for (final e in items.entries)
        DropdownMenuItem<T?>(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ];
    final effective = (value == null || items.containsKey(value)) ? value : null;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T?>(
        initialValue: effective,
        key: ValueKey('$label:$effective:${items.length}'),
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: entries,
        onChanged: onChanged,
      ),
    );
  }
}

/// Generic paginated list body with loading, error+retry, empty and
/// "load more" states.
class PagedListBody<T> extends StatelessWidget {
  const PagedListBody({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final PagedState<T> state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (state.isInitialLoading || !state.started && state.error == null) {
      return const AdminLoadingView();
    }
    if (state.items.isEmpty && state.error != null) {
      return AdminErrorView(error: state.error!, onRetry: onRetry);
    }
    if (state.isEmpty) return AdminEmptyView(message: emptyMessage);
    final g = AppSpacing.gutter(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(g, AppSpacing.sm, g, AppSpacing.huge * 2),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i < state.items.length) return itemBuilder(context, state.items[i]);
          if (state.error != null) {
            return Center(
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(adminErrorMessage(l, state.error!)),
              ),
            );
          }
          if (state.loading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!state.hasMore) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  l.adminListEnd(state.items.length),
                  style: TextStyle(color: context.tokens.textTertiary),
                ),
              ),
            );
          }
          return Center(
            child: OutlinedButton(onPressed: onLoadMore, child: Text(l.adminLoadMore)),
          );
        },
      ),
    );
  }
}

/// Bordered list tile used by all lists.
class AdminListTile extends StatelessWidget {
  const AdminListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chips = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: context.tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(color: context.tokens.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: chips),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

enum AdminTone { neutral, info, success, warning, danger }

/// Small status pill using semantic tokens (works in dark mode).
class AdminPill extends StatelessWidget {
  const AdminPill(this.label, {super.key, this.tone = AdminTone.neutral});
  final String label;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      AdminTone.neutral => (t.surfaceMuted, t.textSecondary),
      AdminTone.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AdminTone.success => (t.successContainer, t.success),
      AdminTone.warning => (t.warningContainer, t.warning),
      AdminTone.danger => (t.dangerContainer, t.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

String reviewStatusLabel(AppLocalizations l, ReviewStatus s) => switch (s) {
      ReviewStatus.draft => l.adminReviewDraft,
      ReviewStatus.aiVerified => l.adminReviewAiVerified,
      ReviewStatus.methodologistApproved => l.adminReviewApproved,
      ReviewStatus.rejected => l.adminReviewRejected,
    };

AdminTone reviewStatusTone(ReviewStatus s) => switch (s) {
      ReviewStatus.draft => AdminTone.neutral,
      ReviewStatus.aiVerified => AdminTone.info,
      ReviewStatus.methodologistApproved => AdminTone.success,
      ReviewStatus.rejected => AdminTone.danger,
    };

String languageLabel(AppLocalizations l, String code) => switch (code) {
      'ru' => l.adminLangRu,
      'ky' => l.adminLangKy,
      'en' => l.adminLangEn,
      _ => code,
    };

String formatAdminDate(DateTime? d) {
  if (d == null) return '—';
  final x = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${x.year}-${two(x.month)}-${two(x.day)} ${two(x.hour)}:${two(x.minute)}';
}

/// Label + value row for detail screens; wraps on narrow screens.
class AdminKeyValue extends StatelessWidget {
  const AdminKeyValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          Text('$label:', style: text.bodyMedium?.copyWith(color: context.tokens.textSecondary)),
          SelectableText(value, style: text.bodyMedium),
        ],
      ),
    );
  }
}
