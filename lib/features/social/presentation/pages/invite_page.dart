import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../application/social_providers.dart';
import '../../domain/social_codes.dart';
import '../../domain/social_failure.dart';
import '../../domain/social_models.dart';
import '../social_messages.dart';
import '../widgets/social_widgets.dart';

/// "Пригласить друзей" (RoutePaths.invite, ARCHITECTURE §9.1): the student's
/// own code with copy/share, entering a friend's code once, and the list of
/// friends who joined with this student's code. Rewards are granted only by
/// the server; this page explains the rule honestly.
class InvitePage extends ConsumerWidget {
  const InvitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final signedIn = ref.watch(socialUidProvider) != null;
    final gutter = AppSpacing.gutter(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.socialInviteTitle)),
      body: !signedIn
          ? EmptyView(
              icon: Icons.lock_outline,
              message: l.socialSignInRequired,
              action: FilledButton(
                onPressed: () => context.go(RoutePaths.login),
                child: Text(l.socialSignIn),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
              children: const [
                _MyCodeCard(),
                SizedBox(height: AppSpacing.md),
                _RewardCard(),
                SizedBox(height: AppSpacing.xl),
                _EnterFriendCode(),
                SizedBox(height: AppSpacing.xl),
                _ReferralsSection(),
              ],
            ),
    );
  }
}

class _MyCodeCard extends ConsumerWidget {
  const _MyCodeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final code = ref.watch(myReferralCodeProvider);
    return SocialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.socialInviteMyCodeTitle,
              style: theme.textTheme.labelLarge?.copyWith(color: context.tokens.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          code.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Align(alignment: AlignmentDirectional.centerStart, child: SocialButtonProgress()),
            ),
            error: (e, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    '${l.socialCodeLoadError} ${l.socialErrorMessage(e, SocialAction.other)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(myReferralCodeProvider),
                  child: Text(l.socialRetry),
                ),
              ],
            ),
            data: (c) => c == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        c,
                        key: const ValueKey('my_referral_code'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => copyWithSnack(context, c, l.socialInviteCopied),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: Text(l.socialInviteCopy),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => copyWithSnack(
                              context,
                              l.socialInviteShareText(c),
                              l.socialInviteTextCopied,
                            ),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: Text(l.socialInviteCopyText),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          SocialMuted(l.socialInviteMyCodeHint),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: t.xpContainer, borderRadius: AppRadii.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.card_giftcard_outlined, color: t.xp),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.socialInviteRewardTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(l.socialInviteRewardBody, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterFriendCode extends ConsumerStatefulWidget {
  const _EnterFriendCode();

  @override
  ConsumerState<_EnterFriendCode> createState() => _EnterFriendCodeState();
}

class _EnterFriendCodeState extends ConsumerState<_EnterFriendCode> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _applied = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l = AppLocalizations.of(context)!;
    final code = SocialCodes.normalize(_controller.text);
    if (!SocialCodes.isReferralCode(code)) {
      setState(() => _error = l.socialErrorReferralFormat);
      return;
    }
    final mine = ref.read(myReferralCodeProvider).valueOrNull;
    if (mine != null && mine == code) {
      setState(() => _error = l.socialFailureKindMessage(SocialFailureKind.ownCode, SocialAction.referral));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(socialRepositoryProvider).referralApply(code);
      if (!mounted) return;
      // A code typed during onboarding is no longer needed.
      await ref.read(pendingReferralProvider.notifier).clear();
      if (!mounted) return;
      setState(() => _applied = true);
      showSocialSnack(context, l.socialInviteApplied);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l.socialErrorMessage(e, SocialAction.referral));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final referred = ref.watch(socialProfileProvider.select((p) => p.valueOrNull?.wasReferred ?? false));
    if (referred || _applied) {
      return SocialCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: context.tokens.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _applied ? l.socialInviteApplied : l.socialInviteAlreadyReferred,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialHeading(l.socialInviteEnterCodeTitle),
        SocialMuted(l.socialInviteEnterCodeHint),
        const SizedBox(height: AppSpacing.md),
        SocialCodeField(
          key: const ValueKey('friend_code_field'),
          controller: _controller,
          maxLength: SocialCodes.referralLength,
          errorText: _error,
          enabled: !_busy,
          onSubmitted: (_) => _apply(),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: const ValueKey('apply_friend_code'),
            onPressed: _busy ? null : _apply,
            child: _busy ? const SocialButtonProgress() : Text(l.socialInviteApply),
          ),
        ),
      ],
    );
  }
}

class _ReferralsSection extends ConsumerWidget {
  const _ReferralsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final referrals = ref.watch(referralsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialHeading(l.socialInviteReferralsTitle),
        referrals.when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: SocialButtonProgress()),
          ),
          error: (e, _) => Row(
            children: [
              Expanded(child: SocialMuted(l.socialInviteReferralsError)),
              TextButton(onPressed: () => ref.invalidate(referralsProvider), child: Text(l.socialRetry)),
            ],
          ),
          data: (items) {
            if (items.isEmpty) return SocialMuted(l.socialInviteReferralsEmpty);
            final rewarded = items.where((i) => i.status == ReferralStatus.rewarded).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SocialMuted(l.socialReferralSummary(items.length, rewarded)),
                const SizedBox(height: AppSpacing.sm),
                for (final item in items) _ReferralTile(item: item),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile({required this.item});

  final ReferralItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final rewarded = item.status == ReferralStatus.rewarded;
    final name = item.displayName.trim().isEmpty ? l.socialAnonymousStudent : item.displayName.trim();
    final date = socialDate(context, rewarded ? item.rewardedAt : item.joinedAt);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: rewarded ? t.successContainer : t.surfaceMuted,
        child: Icon(
          rewarded ? Icons.check_rounded : Icons.hourglass_empty_rounded,
          color: rewarded ? t.success : t.textTertiary,
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [rewarded ? l.socialReferralRewarded : l.socialReferralJoined, if (date.isNotEmpty) date].join(' · '),
      ),
    );
  }
}
