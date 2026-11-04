import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/backend_contract.dart';
import '../../core/utils/app_log.dart';
import '../models/leaderboard_model.dart';
import 'data_exception.dart';

/// Reads server-maintained leaderboards (GAM-17). Boards are precomputed by
/// Cloud Functions from server XP only; the client never ranks anyone.
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const int pageSize = 50;

  /// Top [pageSize] by XP plus the viewer's entry and rank. The rank of a
  /// viewer outside the top uses a count() aggregation (1 read per 1000
  /// entries) instead of scanning the board. Throws [DataException].
  Future<LeaderboardSnapshot> load(String boardId, {String? uid}) async {
    try {
      final entries = FirebaseFirestore.instance
          .collection(Collections.leaderboards)
          .doc(boardId)
          .collection(Collections.leaderboardEntries);
      final topSnap = await entries.orderBy('xp', descending: true).limit(pageSize).get();
      final top = [for (final d in topSnap.docs) LeaderboardEntry.fromMap(d.id, d.data())];

      LeaderboardEntry? mine;
      int? rank;
      if (uid != null) {
        final idx = top.indexWhere((e) => e.uid == uid);
        if (idx >= 0) {
          mine = top[idx];
          rank = idx + 1;
        } else {
          final myDoc = await entries.doc(uid).get();
          final data = myDoc.data();
          if (data != null) {
            mine = LeaderboardEntry.fromMap(uid, data);
            try {
              final agg = await entries.where('xp', isGreaterThan: mine.xp).count().get();
              rank = (agg.count ?? 0) + 1;
            } catch (e, st) {
              reportError(e, st, reason: 'learn.leaderboard.rank');
            }
          }
        }
      }
      return LeaderboardSnapshot(boardId: boardId, top: top, mine: mine, myRank: rank);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.leaderboard.load');
      throw DataException.from(e);
    }
  }
}
