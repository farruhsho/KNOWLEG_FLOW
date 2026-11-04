import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/social_providers.dart';
import '../../domain/social_failure.dart';
import '../social_messages.dart';
import 'social_widgets.dart';

/// Home-screen card for a friend's code typed during onboarding (before the
/// student had an account). Nothing is applied without the student's tap.
/// Renders nothing when there is no pending code or nobody is signed in.
class PendingReferralCard extends ConsumerStatefulWidget {
  const PendingReferralCard({super.key});

  @override
  ConsumerState<PendingReferralCard> createState() => _PendingReferralCardState();
}

class _PendingReferralCardState extends ConsumerState<PendingReferralCard> {
  bool _busy = false;
  SocialFailureKind? _failure;

  /// Failures after which keeping the code makes no sense.
  static const _final = {
    SocialFailureKind.codeInvalid,
    SocialFailureKind.alreadyRedeemed,
    SocialFailureKind.referralNotAllowed,
    SocialFailureKind.ownCode,
  };

  Future<void> _apply(String code) async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(socialRepositoryProvider).referralApply(code);
      if (!mounted) return;
      await ref.read(pendingReferralProvider.notifier).clear();
      if (mounted) showSocialSnack(context, l.socialInviteApplied);
    } catch (e) {
      if (!mounted) return;
      setState(() => _failure = SocialFailure.from(e).kind);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(pendingReferralProvider);
    final signedIn = ref.watch(socialUidProvider) != null;
    if (code == null || !signedIn) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SocialCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_outlined, color: t.xp),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(l.socialPendingReferralTitle(code), style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l.socialPendingReferralBody, style: theme.textTheme.bodyMedium),
            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.socialFailureKindMessage(_failure!, SocialAction.referral),
                style: theme.textTheme.bodySmall?.copyWith(color: t.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => ref.read(pendingReferralProvider.notifier).clear(),
                  child: Text(l.socialPendingReferralDiscard),
                ),
                if (!_final.contains(_failure))
                  FilledButton(
                    key: const ValueKey('pending_referral_apply'),
                    onPressed: _busy ? null : () => _apply(code),
                    child: _busy ? const SocialButtonProgress() : Text(l.socialInviteApply),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
