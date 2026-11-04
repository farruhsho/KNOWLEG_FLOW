import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/leaderboard_model.dart';

/// One leaderboard row (rank, name, weekly XP).
class LeagueEntryTile extends StatelessWidget {
  const LeagueEntryTile({
    super.key,
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int? rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = entry.displayName.trim().isEmpty ? l.learnLeaderboardAnonymous : entry.displayName.trim();
    return ListTile(
      tileColor: isMe ? theme.colorScheme.primaryContainer : null,
      leading: SizedBox(
        width: 40,
        child: Text(
          rank == null ? '—' : '$rank',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: (rank ?? 99) <= 3 ? context.tokens.xp : null),
        ),
      ),
      title: Text(isMe ? l.learnLeaderboardYou(name) : name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(l.learnXpShort(entry.xp), style: theme.textTheme.labelLarge),
    );
  }
}
