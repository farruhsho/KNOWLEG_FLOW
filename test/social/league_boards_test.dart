import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/utils/bishkek_time.dart';
import 'package:knowledge_flow/features/onboarding/data/kg_regions_provider.dart';
import 'package:knowledge_flow/features/social/domain/league_boards.dart';
import 'package:knowledge_flow/features/social/domain/social_models.dart';
import 'package:knowledge_flow/shared/models/leaderboard_model.dart';

/// Board ids of the phase-3 leagues (ARCHITECTURE §9.3) must match the
/// server exactly: `{kind}_{id}_weekly_{YYYY}-W{ww}` with the ISO week of the
/// Bishkek calendar.
void main() {
  group('board ids', () {
    final wednesday = DateTime.utc(2026, 11, 4, 9);

    test('region and group boards use the Bishkek ISO week', () {
      expect(LeagueBoards.regionWeeklyBoardId('chuy', wednesday), 'region_chuy_weekly_2026-W45');
      expect(LeagueBoards.groupWeeklyBoardId('g_abc', wednesday), 'group_g_abc_weekly_2026-W45');
    });

    test('friends league reads the general weekly board', () {
      expect(LeagueBoards.friendsSourceBoardId(wednesday), 'weekly_2026-W45');
      expect(LeagueBoards.friendsSourceBoardId(wednesday), BishkekTime.weeklyBoardId(wednesday));
    });

    test('the week flips at midnight in Bishkek, not UTC', () {
      // Sunday 23:59 in Bishkek (17:59 UTC) — still week 45.
      expect(LeagueBoards.regionWeeklyBoardId('osh', DateTime.utc(2026, 11, 8, 17, 59)),
          'region_osh_weekly_2026-W45');
      // Monday 00:30 in Bishkek is still Sunday in UTC — already week 46.
      expect(LeagueBoards.regionWeeklyBoardId('osh', DateTime.utc(2026, 11, 8, 18, 30)),
          'region_osh_weekly_2026-W46');
      expect(LeagueBoards.groupWeeklyBoardId('g1', DateTime.utc(2026, 11, 8, 18, 30)),
          'group_g1_weekly_2026-W46');
    });

    test('ISO year boundary (2026 has 53 weeks)', () {
      final newYear = DateTime.utc(2027, 1, 1, 12);
      expect(LeagueBoards.groupWeeklyBoardId('g1', newYear), 'group_g1_weekly_2026-W53');
      expect(LeagueBoards.regionWeeklyBoardId('chuy', DateTime.utc(2027, 1, 4, 6)),
          'region_chuy_weekly_2027-W01');
    });
  });

  group('region id from the profile', () {
    final regions = parseKgRegions(File('assets/data/kg_regions.json').readAsStringSync());

    test('the stored oblast (canonical Russian name) maps to the asset id', () {
      expect(LeagueBoards.regionIdFor('Чуйская область', regions), 'chuy');
      expect(LeagueBoards.regionIdFor('Бишкек', regions), isNotNull);
    });

    test('an id stored directly is accepted', () {
      expect(LeagueBoards.regionIdFor('chuy', regions), 'chuy');
    });

    test('missing or unknown region → null (empty state, no board read)', () {
      expect(LeagueBoards.regionIdFor(null, regions), isNull);
      expect(LeagueBoards.regionIdFor('  ', regions), isNull);
      expect(LeagueBoards.regionIdFor('Атлантида', regions), isNull);
    });

    test('every region in the asset has an id usable in a document id', () {
      for (final r in regions) {
        expect(r.id, matches(RegExp(r'^[a-z0-9_.]+$')), reason: r.oblast);
        expect(LeagueBoards.regionIdFor(r.oblast, regions), r.id);
      }
    });
  });

  group('friends league ranking', () {
    LeaderboardEntry e(String uid, int xp, [String name = '']) =>
        LeaderboardEntry(uid: uid, displayName: name, xp: xp);

    test('me plus friends by weekly XP; friends without an entry have 0', () {
      final rows = LeagueBoards.rankFriends(
        myUid: 'me',
        myName: 'Айдана',
        friends: const [
          FriendEntry(uid: 'a', displayName: 'Бек'),
          FriendEntry(uid: 'b', displayName: 'Нурлан'),
          FriendEntry(uid: 'c', displayName: 'Алина'),
        ],
        weeklyEntries: {'me': e('me', 40), 'a': e('a', 120, 'Бекжан'), 'c': e('c', 40)},
      );
      expect(rows.map((r) => r.uid), ['a', 'me', 'c', 'b']);
      expect(rows.map((r) => r.rank), [1, 2, 3, 4]);
      expect(rows.first.displayName, 'Бекжан', reason: 'board name wins');
      expect(rows[1].isMe, isTrue);
      expect(rows[1].displayName, 'Айдана');
      expect(rows.last.xp, 0);
      expect(rows.last.displayName, 'Нурлан');
    });

    test('the viewer is always present, even with no friends and no XP', () {
      final rows = LeagueBoards.rankFriends(myUid: 'me', myName: '', friends: const [], weeklyEntries: const {});
      expect(rows, hasLength(1));
      expect(rows.single.isMe, isTrue);
      expect(rows.single.xp, 0);
    });

    test('a friend entry with my own uid is not duplicated', () {
      final rows = LeagueBoards.rankFriends(
        myUid: 'me',
        myName: 'Я',
        friends: const [FriendEntry(uid: 'me'), FriendEntry(uid: 'x')],
        weeklyEntries: const {},
      );
      expect(rows.where((r) => r.uid == 'me'), hasLength(1));
      expect(rows, hasLength(2));
    });
  });
}
