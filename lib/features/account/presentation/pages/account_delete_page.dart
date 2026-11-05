import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/account_deletion_service.dart';
import '../../domain/account_deletion.dart';

/// In-app account deletion (RoutePaths.accountDelete), required by Google
/// Play: explains what is deleted and kept, asks for a typed confirmation,
/// re-authenticates, calls `accountDelete`, signs out and returns to splash.
class AccountDeletePage extends ConsumerStatefulWidget {
  const AccountDeletePage({super.key});

  @override
  ConsumerState<AccountDeletePage> createState() => _AccountDeletePageState();
}

class _AccountDeletePageState extends ConsumerState<AccountDeletePage> {
  final _confirm = TextEditingController();
  bool _busy = false;
  AccountDeleteFailure? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  AccountDeletionService get _service => ref.read(accountDeletionServiceProvider);

  Future<void> _start() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (!await _reauthenticate()) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _deleteWithRetry();
    } on AccountDeleteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.failure == AccountDeleteFailure.canceled ? null : e.failure;
      });
    } catch (e) {
      // Never leave the button spinning on an unexpected error.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AccountDeleteFailure.from(e);
      });
    }
  }

  /// Returns false when the user cancelled.
  Future<bool> _reauthenticate() async {
    final methods = _service.methods();
    if (methods.isEmpty) return true; // e.g. phone sign-in: the server decides.
    if (methods.length == 1 && methods.single == ReauthMethod.google) {
      await _service.reauthWithGoogle();
      return true;
    }
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReauthDialog(
        service: _service,
        email: _service.currentUser?.email ?? '',
        allowGoogle: methods.contains(ReauthMethod.google),
      ),
    );
    return ok == true;
  }

  Future<void> _deleteWithRetry() async {
    try {
      await _service.deleteAccount();
    } on AccountDeleteException catch (e) {
      if (e.failure != AccountDeleteFailure.requiresRecentLogin) rethrow;
      // The server wants a sign-in from the last few minutes
      // (REQUIRES_RECENT_LOGIN): prove identity once more, then retry once.
      // Without an in-app re-auth method the error offers "Sign in again".
      if (_service.methods().isEmpty) rethrow;
      if (!await _reauthenticate()) {
        throw const AccountDeleteException(AccountDeleteFailure.canceled);
      }
      await _service.deleteAccount();
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.accountDeleteDone)));
    context.go(RoutePaths.splash);
  }

  /// Signs out so the user can sign in fresh (new `auth_time`) and return.
  Future<void> _signInAgain() async {
    setState(() => _busy = true);
    await _service.signOutForFreshSignIn();
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final g = AppSpacing.gutter(context);
    final signedIn = _service.currentUser != null;
    final available = ref.watch(accountDeletionAvailableProvider);
    final word = l10n.accountDeleteConfirmWord;
    final plainWord = deleteConfirmationPlainForm(word);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.accountDeleteTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(g, AppSpacing.md, g, AppSpacing.xxxl),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: tokens.dangerContainer, borderRadius: AppRadii.lgAll),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: tokens.danger),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.accountDeleteWarningTitle, style: theme.textTheme.titleSmall),
                            const SizedBox(height: AppSpacing.xs),
                            Text(l10n.accountDeleteWarningBody, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Section(
                title: l10n.accountDeleteWhatDeletedTitle,
                icon: Icons.delete_outline,
                items: [
                  l10n.accountDeleteItemProfile,
                  l10n.accountDeleteItemProgress,
                  l10n.accountDeleteItemExams,
                  l10n.accountDeleteItemGamification,
                  l10n.accountDeleteItemAi,
                  l10n.accountDeleteItemCredits,
                  l10n.accountDeleteItemLogin,
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _Section(
                title: l10n.accountDeleteWhatKeptTitle,
                icon: Icons.inventory_2_outlined,
                items: [l10n.accountDeleteKeptPurchases, l10n.accountDeleteKeptGoogle],
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (!signedIn) ...[
                Text(l10n.accountDeleteSignedOut, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.login),
                  child: Text(l10n.accountDeleteGoToLogin),
                ),
              ] else if (!available) ...[
                // No App Check provider here (Windows/Linux, web without a
                // site key): accountDelete would be rejected (D7).
                DecoratedBox(
                  decoration: BoxDecoration(color: tokens.surfaceMuted, borderRadius: AppRadii.mdAll),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.phone_android_outlined, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(l10n.accountDeleteUnavailablePlatform,
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.accountDeleteConfirmLabel(word),
                    helperText: plainWord == null ? null : l10n.accountDeleteConfirmAlt(plainWord),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorText(l10n, _error!),
                      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.danger),
                    ),
                  ),
                  if (_error == AccountDeleteFailure.requiresRecentLogin) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _signInAgain,
                        icon: const Icon(Icons.login),
                        label: Text(l10n.accountReauthSignInAgain),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.lg),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _confirm,
                  builder: (context, value, _) {
                    final valid = isDeleteConfirmationValid(value.text, word);
                    return FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      onPressed: valid && !_busy ? _start : null,
                      icon: _busy
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(_busy ? l10n.accountDeleteInProgress : l10n.accountDeleteButton),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _errorText(AppLocalizations l10n, AccountDeleteFailure f) => switch (f) {
      AccountDeleteFailure.wrongPassword => l10n.accountErrorWrongPassword,
      AccountDeleteFailure.tooManyRequests => l10n.accountErrorTooManyRequests,
      AccountDeleteFailure.network => l10n.accountErrorNetwork,
      AccountDeleteFailure.requiresRecentLogin => l10n.accountErrorRecentLogin,
      AccountDeleteFailure.unauthenticated => l10n.accountErrorUnauthenticated,
      AccountDeleteFailure.userMismatch => l10n.accountErrorUserMismatch,
      AccountDeleteFailure.googleFailed => l10n.accountErrorGoogle,
      AccountDeleteFailure.serviceUnavailable => l10n.accountErrorService,
      AccountDeleteFailure.signedOut => l10n.accountDeleteSignedOut,
      AccountDeleteFailure.canceled || AccountDeleteFailure.unknown => l10n.accountErrorUnknown,
    };

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20, child: Text('•', style: theme.textTheme.bodyMedium)),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog({required this.service, required this.email, required this.allowGoogle});

  final AccountDeletionService service;
  final String email;
  final bool allowGoogle;

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  AccountDeleteFailure? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on AccountDeleteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.failure == AccountDeleteFailure.canceled ? null : e.failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.accountReauthTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.accountReauthBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.accountReauthEmail(widget.email), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: l10n.accountReauthPassword),
            onSubmitted: (_) => _busy ? null : _run(() => widget.service.reauthWithPassword(_password.text)),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorText(l10n, _error!),
              style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.danger),
            ),
          ],
          if (widget.allowGoogle) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(widget.service.reauthWithGoogle),
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(l10n.accountReauthGoogle),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.accountReauthCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _run(() => widget.service.reauthWithPassword(_password.text)),
          child: Text(l10n.accountReauthConfirm),
        ),
      ],
    );
  }
}
