import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../application/social_providers.dart';
import '../../domain/league_boards.dart';
import '../../domain/social_codes.dart';
import '../../domain/social_failure.dart';
import '../../domain/social_models.dart';
import '../social_messages.dart';
import 'code_entry_dialog.dart';
import 'social_widgets.dart';

/// "Друзья" tab of the leaderboard: the student and their friends by this
/// week's XP (read from the general weekly board), add a friend by their
/// invite code (`friendAdd`), remove a friend (own list only).
class FriendsLeagueView extends ConsumerWidget {
  const FriendsLeagueView({super.key});

  /// How long the own-code check waits for the student's code before letting
  /// the server decide (it rejects the own code too, `why: 'self'`).
  static const _myCodeWait = Duration(seconds: 5);

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    // Start loading the own code now (usually cached), so it is known by the
    // time the student submits, even on the first visit (§9.7).
    final myCode = ref.read(myReferralCodeProvider.future).then<String?>((c) => c, onError: (Object _) => null);
    final added = await showCodeEntryDialog<FriendAdded>(
      context,
      title: l.socialFriendsAddTitle,
      hint: l.socialFriendsAddHint,
      actionLabel: l.socialFriendsAdd,
      action: SocialAction.friendAdd,
      maxLength: SocialCodes.referralLength,
      fieldKey: const ValueKey('friend_add_field'),
      actionKey: const ValueKey('friend_add_submit'),
      validate: (c) async {
        if (!SocialCodes.isReferralCode(c)) return l.socialErrorReferralFormat;
        final mine = await myCode.timeout(_myCodeWait, onTimeout: () => null);
        if (mine != null && SocialCodes.normalize(mine) == c) {
          return l.socialFailureKindMessage(SocialFailureKind.ownCode, SocialAction.friendAdd);
        }
        return null;
      },
      submit: ref.read(socialRepositoryProvider).friendAdd,
    );
    if (added == null || !context.mounted) return;
    ref.invalidate(friendsLeagueProvider);
    showSocialSnack(
      context,
      added.displayName.trim().isEmpty ? l.socialFriendsAddedGeneric : l.socialFriendsAdded(added.displayName.trim()),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, FriendStanding f, String name) async {
    final l = AppLocalizations.of(context)!;
    final uid = ref.read(socialUidProvider);
    if (uid == null) return;
    final ok = await confirmSocialAction(
      context,
      message: l.socialFriendsRemoveConfirm(name),
      confirmLabel: l.socialRemove,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(socialRepositoryProvider).removeFriend(uid, f.uid);
      ref.invalidate(friendsLeagueProvider);
    } catch (e) {
      if (context.mounted) showSocialSnack(context, l.socialErrorMessage(e, SocialAction.other));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (ref.watch(socialUidProvider) == null) {
      return EmptyView(icon: Icons.lock_outline, message: l.socialSignInRequired);
    }
    final league = ref.watch(friendsLeagueProvider);
    final gutter = AppSpacing.gutter(context);
    final addButton = FilledButton.tonalIcon(
      key: const ValueKey('friends_add'),
      onPressed: () => _add(context, ref),
      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
      label: Text(l.socialFriendsAdd),
    );
    Future<void> refresh() async {
      ref.invalidate(friendsLeagueProvider);
      try {
        await ref.read(friendsLeagueProvider.future);
      } catch (_) {}
    }

    return league.when(
      skipLoadingOnReload: true,
      loading: () => LoadingView(message: l.loading),
      error: (e, _) => ErrorView(
        title: l.socialFriendsLoadError,
        message: l.socialErrorMessage(e, SocialAction.other),
        onRetry: refresh,
      ),
      data: (rows) {
        final hasFriends = rows.any((r) => !r.isMe);
        if (!hasFriends) {
          return EmptyView(
            icon: Icons.people_outline,
            message: l.socialFriendsEmptyTitle,
            subtitle: l.socialFriendsEmptyBody,
            action: addButton,
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: SocialMuted(l.socialFriendsHint)),
                    const SizedBox(width: AppSpacing.sm),
                    addButton,
                  ],
                ),
              ),
              for (final r in rows) _FriendRow(row: r, onRemove: (name) => _remove(context, ref, r, name)),
            ],
          ),
        );
      },
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.row, required this.onRemove});

  final FriendStanding row;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = row.displayName.trim().isEmpty ? l.learnLeaderboardAnonymous : row.displayName.trim();
    return ListTile(
      key: ValueKey('friend_row_${row.uid}'),
      tileColor: row.isMe ? theme.colorScheme.primaryContainer : null,
      leading: SizedBox(
        width: 40,
        child: Text(
          '${row.rank}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: row.rank <= 3 ? context.tokens.xp : null),
        ),
      ),
      title: Text(row.isMe ? l.learnLeaderboardYou(name) : name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.learnXpShort(row.xp), style: theme.textTheme.labelLarge),
          if (!row.isMe)
            IconButton(
              key: ValueKey('friend_remove_${row.uid}'),
              tooltip: l.socialFriendsRemove,
              icon: const Icon(Icons.person_remove_outlined, size: 20),
              onPressed: () => onRemove(name),
            ),
        ],
      ),
    );
  }
}
