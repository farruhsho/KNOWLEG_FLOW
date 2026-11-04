import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../shared/models/leaderboard_model.dart';
import '../data/referral_local_store.dart';
import '../data/social_repository.dart';
import '../domain/league_boards.dart';
import '../domain/social_models.dart';

/// Data access; replaced by a fake in widget tests.
final socialRepositoryProvider =
    Provider<SocialRepository>((ref) => FirebaseSocialRepository());

/// Signed-in uid (null when signed out).
final socialUidProvider = Provider<String?>((ref) => ref.watch(currentUidProvider));

/// "Now" for board ids; overridable in tests.
final socialClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final referralLocalStoreProvider = Provider<ReferralLocalStore>(
    (ref) => ReferralLocalStore(ref.watch(sharedPreferencesProvider)));

/// Social fields of `users/{uid}` (null when signed out).
final socialProfileProvider = StreamProvider.autoDispose<SocialProfile?>((ref) {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(socialRepositoryProvider).watchProfile(uid);
});

/// The student's own referral code: the device cache, else the profile
/// field, else `referralGetCode` (idempotent on the server). Kept for the
/// session so the invite page never calls the function twice.
final myReferralCodeProvider = FutureProvider<String?>((ref) async {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return null;
  final local = ref.watch(referralLocalStoreProvider);
  final cached = local.cachedCode(uid);
  if (cached != null && cached.isNotEmpty) return cached;
  final repo = ref.watch(socialRepositoryProvider);
  String? code;
  try {
    final profile = await repo.watchProfile(uid).first.timeout(const Duration(seconds: 5));
    code = profile.referralCode;
  } catch (_) {
    // Profile unreadable or slow: ask the server instead.
  }
  if (code == null || code.isEmpty) code = await repo.referralGetCode();
  await local.cacheCode(uid, code);
  return code;
});

/// `referrals/{uid}/items` — friends who joined with the student's code.
final referralsProvider = StreamProvider.autoDispose<List<ReferralItem>>((ref) {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchReferrals(uid);
});

/// A friend's code typed during onboarding, waiting to be applied.
class PendingReferralNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(referralLocalStoreProvider).pendingCode;

  Future<void> save(String code) async {
    await ref.read(referralLocalStoreProvider).savePendingCode(code);
    state = code;
  }

  Future<void> clear() async {
    await ref.read(referralLocalStoreProvider).clearPendingCode();
    state = null;
  }
}

final pendingReferralProvider =
    NotifierProvider<PendingReferralNotifier, String?>(PendingReferralNotifier.new);

/// `friends/{uid}/list`.
final friendsProvider = StreamProvider.autoDispose<List<FriendEntry>>((ref) {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchFriends(uid);
});

/// Friends league: the friends' and the student's weekly entries, ranked on
/// the client (ARCHITECTURE §9.3).
final friendsLeagueProvider = FutureProvider.autoDispose<List<FriendStanding>>((ref) async {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return const [];
  final friendsFuture = ref.watch(friendsProvider.future);
  final profileFuture = ref.watch(socialProfileProvider.future);
  final repo = ref.watch(socialRepositoryProvider);
  final boardId = LeagueBoards.friendsSourceBoardId(ref.watch(socialClockProvider)());
  final friends = await friendsFuture;
  final entries = await repo.boardEntries(boardId, [uid, for (final f in friends) f.uid]);
  String myName = '';
  try {
    myName = (await profileFuture)?.displayName ?? '';
  } catch (_) {
    // The name is cosmetic; the league still renders without it.
  }
  return LeagueBoards.rankFriends(
    myUid: uid,
    myName: myName,
    friends: friends,
    weeklyEntries: entries,
  );
});

/// The student's groups (`users/{uid}.group_ids`, ≤ 5), reloaded whenever
/// the server changes the list.
final myGroupsProvider = StreamProvider.autoDispose<List<StudyGroup>>((ref) {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return Stream.value(const []);
  final repo = ref.watch(socialRepositoryProvider);
  return repo
      .watchProfile(uid)
      .map((p) => p.groupIds)
      .distinct(listEquals)
      .asyncMap((ids) => ids.isEmpty ? Future.value(const <StudyGroup>[]) : repo.loadGroups(ids));
});

final groupProvider = StreamProvider.autoDispose.family<StudyGroup?, String>(
    (ref, groupId) => ref.watch(socialRepositoryProvider).watchGroup(groupId));

final groupMembersProvider = StreamProvider.autoDispose.family<List<GroupMember>, String>(
    (ref, groupId) => ref.watch(socialRepositoryProvider).watchMembers(groupId));

final groupAssignmentsProvider = StreamProvider.autoDispose.family<List<GroupAssignment>, String>(
    (ref, groupId) => ref.watch(socialRepositoryProvider).watchAssignments(groupId));

/// Key of one assignment.
typedef AssignmentKey = ({String groupId, String assignmentId});

/// Every member's submission (the owner's view).
final assignmentSubmissionsProvider =
    StreamProvider.autoDispose.family<List<AssignmentSubmission>, AssignmentKey>((ref, key) =>
        ref.watch(socialRepositoryProvider).watchSubmissions(key.groupId, key.assignmentId));

/// The student's own submission.
final mySubmissionProvider =
    StreamProvider.autoDispose.family<AssignmentSubmission?, AssignmentKey>((ref, key) {
  final uid = ref.watch(socialUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(socialRepositoryProvider).watchMySubmission(key.groupId, key.assignmentId, uid);
});

/// Weekly group league (`group_{gid}_weekly_*`).
final groupLeaderboardProvider =
    FutureProvider.autoDispose.family<LeaderboardSnapshot, String>((ref, groupId) {
  final now = ref.watch(socialClockProvider)();
  return ref.watch(socialRepositoryProvider).loadBoard(
        LeagueBoards.groupWeeklyBoardId(groupId, now),
        uid: ref.watch(socialUidProvider),
      );
});

/// What the owner can assign, per kind and content language.
final assignableItemsProvider = FutureProvider.autoDispose
    .family<List<AssignableItem>, ({AssignmentKind kind, String lang})>((ref, key) {
  final repo = ref.watch(socialRepositoryProvider);
  return switch (key.kind) {
    AssignmentKind.lesson => repo.assignableLessons(key.lang),
    AssignmentKind.practice => repo.assignableSubjects(key.lang),
    AssignmentKind.examVariant => repo.assignableVariants(key.lang),
  };
});
