import 'package:flutter/foundation.dart';

import '../../../core/utils/bishkek_time.dart';
import '../../../shared/models/leaderboard_model.dart';
import '../../../shared/models/region_model.dart';
import 'social_models.dart';

/// Leaderboard ids of the phase-3 leagues (ARCHITECTURE §9.3). Every weekly
/// id uses the ISO week of the Bishkek calendar ([BishkekTime.isoWeekKey]),
/// exactly like the server.
abstract final class LeagueBoards {
  /// `region_{regionId}_weekly_{YYYY}-W{ww}`; [regionId] is the `id` of the
  /// oblast in `assets/data/kg_regions.json` (e.g. `chuy`).
  static String regionWeeklyBoardId(String regionId, DateTime now) =>
      'region_${regionId}_weekly_${BishkekTime.isoWeekKey(now)}';

  /// `group_{gid}_weekly_{YYYY}-W{ww}`.
  static String groupWeeklyBoardId(String groupId, DateTime now) =>
      'group_${groupId}_weekly_${BishkekTime.isoWeekKey(now)}';

  /// The friends league has no board of its own: the client reads the
  /// friends' (and the viewer's) entries from the general weekly board.
  static String friendsSourceBoardId(DateTime now) => BishkekTime.weeklyBoardId(now);

  /// Region id for the stored `users/{uid}.region.oblast` value (canonical
  /// Russian name). Also accepts an id stored directly. Null when the
  /// student has not set a region or the value is unknown.
  static String? regionIdFor(String? stored, List<RegionData> regions) {
    final v = stored?.trim();
    if (v == null || v.isEmpty) return null;
    for (final r in regions) {
      if (r.id.isEmpty) continue;
      if (r.oblast == v || r.id == v) return r.id;
    }
    return null;
  }

  /// Friends league: the viewer plus every friend, by weekly XP (friends
  /// without an entry this week have 0 XP), ties by name.
  static List<FriendStanding> rankFriends({
    required String myUid,
    required String myName,
    required List<FriendEntry> friends,
    required Map<String, LeaderboardEntry> weeklyEntries,
  }) {
    String nameOf(String uid, String fallback) {
      final fromBoard = weeklyEntries[uid]?.displayName.trim() ?? '';
      return fromBoard.isNotEmpty ? fromBoard : fallback.trim();
    }

    final rows = <FriendStanding>[
      FriendStanding(
        uid: myUid,
        displayName: nameOf(myUid, myName),
        xp: weeklyEntries[myUid]?.xp ?? 0,
        isMe: true,
      ),
      for (final f in friends)
        if (f.uid != myUid)
          FriendStanding(
            uid: f.uid,
            displayName: nameOf(f.uid, f.displayName),
            xp: weeklyEntries[f.uid]?.xp ?? 0,
          ),
    ];
    rows.sort((a, b) {
      final byXp = b.xp.compareTo(a.xp);
      if (byXp != 0) return byXp;
      if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return [
      for (var i = 0; i < rows.length; i++) rows[i].withRank(i + 1),
    ];
  }
}

/// One row of the friends league.
@immutable
class FriendStanding {
  final String uid;
  final String displayName;
  final int xp;
  final bool isMe;
  final int rank;

  const FriendStanding({
    required this.uid,
    required this.displayName,
    required this.xp,
    this.isMe = false,
    this.rank = 0,
  });

  FriendStanding withRank(int r) =>
      FriendStanding(uid: uid, displayName: displayName, xp: xp, isMe: isMe, rank: r);
}
