import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';

/// Non-blocking reminder to confirm the e-mail address of a password
/// account. Hidden for Google accounts, verified users, or after "Later".
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  // Session-scoped: shown again on the next app start until verified.
  static bool _dismissedThisSession = false;
  bool _verified = false;
  bool _busy = false;

  Future<void> _resend() async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final sent = await ref.read(authServiceProvider).sendEmailVerification();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(sent ? l.shellVerifySent : l.shellVerifySendFailed),
    ));
  }

  Future<void> _checkAgain() async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    var verified = false;
    try {
      verified =
          await ref.read(authServiceProvider).reloadAndCheckEmailVerified();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verified = verified;
    });
    messenger.showSnackBar(SnackBar(
      content: Text(verified ? l.shellVerifyDone : l.shellVerifyNotYet),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isPasswordAccount = user != null &&
        user.email != null &&
        user.providerData.any((p) => p.providerId == 'password');
    if (!isPasswordAccount ||
        user.emailVerified ||
        _verified ||
        _dismissedThisSession) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.warningContainer,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.mark_email_unread_outlined,
                    color: tokens.warning, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.shellVerifyTitle, style: text.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l.shellVerifyMessage(user.email!),
                      style: text.bodySmall
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _dismissedThisSession = true),
                child: Text(l.shellLater),
              ),
              TextButton(
                onPressed: _busy ? null : _resend,
                child: Text(l.shellVerifyResend),
              ),
              TextButton(
                onPressed: _busy ? null : _checkAgain,
                child: Text(l.shellVerifyCheck),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
