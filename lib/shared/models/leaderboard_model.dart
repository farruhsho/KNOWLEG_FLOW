import '../../core/utils/json_read.dart';

/// `leaderboards/{boardId}/entries/{uid}` (server-written, ARCHITECTURE §1.7).
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String? avatarUrl;
  final String? regionId;
  final int xp;
  final DateTime? updatedAt;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.xp,
    this.avatarUrl,
    this.regionId,
    this.updatedAt,
  });

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> m) => LeaderboardEntry(
        uid: uid,
        displayName: JsonRead.stringOr(m, ['display_name', 'displayName', 'name']),
        avatarUrl: JsonRead.string(m, ['avatar_url', 'avatarUrl']),
        regionId: JsonRead.string(m, ['region_id', 'regionId']),
        xp: JsonRead.intOr(m, ['xp'], 0),
        updatedAt: JsonRead.date(m, ['updated_at', 'updatedAt']),
      );
}

/// A board page: top entries plus the viewer's own entry and rank.
class LeaderboardSnapshot {
  final String boardId;
  final List<LeaderboardEntry> top;
  final LeaderboardEntry? mine;
  final int? myRank; // 1-based; null when the viewer has no entry

  const LeaderboardSnapshot({
    required this.boardId,
    required this.top,
    this.mine,
    this.myRank,
  });
}
