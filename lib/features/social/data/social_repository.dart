import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/firebase_service.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/json_read.dart';
import '../../../shared/models/leaderboard_model.dart';
import '../../../shared/services/firebase_data_service.dart';
import '../../../shared/services/leaderboard_service.dart';
import '../../exam/domain/localized_text.dart';
import '../domain/social_failure.dart';
import '../domain/social_models.dart';

/// Data access for referrals, promo codes, friends, groups and homework
/// (ARCHITECTURE §9).
///
/// Everything that grants something (credits, friendships, memberships) goes
/// through a callable; the client writes only what the rules allow it to:
/// deleting its own friend entries, homework assignments as a group owner
/// and its own submission. Every method throws [SocialFailure].
abstract class SocialRepository {
  // Profile
  Stream<SocialProfile> watchProfile(String uid);

  // Referrals
  Future<String> referralGetCode();
  Future<void> referralApply(String code);
  Stream<List<ReferralItem>> watchReferrals(String uid);

  // Promo codes
  Future<PromoRedeemResult> promoRedeem(String code);

  // Friends
  Stream<List<FriendEntry>> watchFriends(String uid);
  Future<FriendAdded> friendAdd(String code);
  Future<void> removeFriend(String uid, String friendUid);

  /// Entries of [uids] on [boardId] (missing uids have no entry).
  Future<Map<String, LeaderboardEntry>> boardEntries(String boardId, List<String> uids);

  /// Top of [boardId] plus the viewer's own position.
  Future<LeaderboardSnapshot> loadBoard(String boardId, {String? uid});

  // Groups
  Future<List<StudyGroup>> loadGroups(List<String> groupIds);
  Stream<StudyGroup?> watchGroup(String groupId);
  Stream<List<GroupMember>> watchMembers(String groupId);
  Future<GroupCreated> groupCreate(String name);
  Future<String> groupJoin(String code);
  Future<void> groupLeave(String groupId);
  Future<void> groupRemoveMember(String groupId, String uid);

  // Homework
  Stream<List<GroupAssignment>> watchAssignments(String groupId);
  Stream<List<AssignmentSubmission>> watchSubmissions(String groupId, String assignmentId);
  Stream<AssignmentSubmission?> watchMySubmission(String groupId, String assignmentId, String uid);
  Future<void> markAssignmentDone(String groupId, String assignmentId, String uid);
  Future<void> createAssignment(String groupId, AssignmentDraft draft, {required String uid});
  Future<void> deleteAssignment(String groupId, String assignmentId);

  // Assignment pickers (owner only)
  Future<List<AssignableItem>> assignableLessons(String lang);
  Future<List<AssignableItem>> assignableSubjects(String lang);
  Future<List<AssignableItem>> assignableVariants(String lang);
}

/// Production implementation over Firestore + the phase-3 callables.
class FirebaseSocialRepository implements SocialRepository {
  FirebaseSocialRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseService.firestore;

  /// Max uids per `whereIn` query.
  static const _whereInLimit = 30;

  // ------------------------------------------------------------ callables

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    if (!FirebaseService.supportsCallables) {
      throw const SocialFailure(SocialFailureKind.unsupportedPlatform);
    }
    try {
      final res = await BackendFunctions.callable(name, timeout: const Duration(seconds: 20))
          .call<Object?>(data);
      return JsonRead.asMap(res.data) ?? const <String, dynamic>{};
    } catch (e, st) {
      final f = SocialFailure.from(e);
      if (f.kind == SocialFailureKind.unknown) reportError(e, st, reason: 'social.$name');
      throw f;
    }
  }

  Future<T> _guard<T>(String reason, Future<T> Function() body) async {
    try {
      return await body();
    } on SocialFailure {
      rethrow;
    } catch (e, st) {
      final f = SocialFailure.from(e);
      if (f.kind == SocialFailureKind.unknown) reportError(e, st, reason: 'social.$reason');
      throw f;
    }
  }

  Stream<T> _guardStream<T>(Stream<T> source) =>
      source.handleError((Object e) => throw SocialFailure.from(e));

  @override
  Future<String> referralGetCode() async {
    final data = await _call(BackendFunctions.referralGetCode, const {});
    final code = JsonRead.string(data, ['code']);
    if (code == null || code.isEmpty) throw const SocialFailure(SocialFailureKind.unknown);
    return code;
  }

  @override
  Future<void> referralApply(String code) => _call(BackendFunctions.referralApply, {'code': code});

  @override
  Future<PromoRedeemResult> promoRedeem(String code) async =>
      PromoRedeemResult.fromMap(await _call(BackendFunctions.promoRedeem, {'code': code}));

  @override
  Future<FriendAdded> friendAdd(String code) async {
    final data = await _call(BackendFunctions.friendAdd, {'code': code});
    return FriendAdded(
      friendUid: JsonRead.string(data, ['friendUid', 'friend_uid', 'uid']),
      displayName: JsonRead.stringOr(data, ['displayName', 'display_name']),
    );
  }

  @override
  Future<GroupCreated> groupCreate(String name) async {
    final data = await _call(BackendFunctions.groupCreate, {'name': name});
    final id = JsonRead.string(data, ['groupId', 'group_id']);
    if (id == null || id.isEmpty) throw const SocialFailure(SocialFailureKind.unknown);
    return GroupCreated(groupId: id, joinCode: JsonRead.stringOr(data, ['joinCode', 'join_code']));
  }

  @override
  Future<String> groupJoin(String code) async {
    final data = await _call(BackendFunctions.groupJoin, {'code': code});
    final id = JsonRead.string(data, ['groupId', 'group_id']);
    if (id == null || id.isEmpty) throw const SocialFailure(SocialFailureKind.unknown);
    return id;
  }

  @override
  Future<void> groupLeave(String groupId) => _call(BackendFunctions.groupLeave, {'groupId': groupId});

  @override
  Future<void> groupRemoveMember(String groupId, String uid) =>
      _call(BackendFunctions.groupRemoveMember, {'groupId': groupId, 'uid': uid});

  // ----------------------------------------------------------- Firestore

  DocumentReference<Map<String, dynamic>> _group(String gid) =>
      _db.collection(Collections.groups).doc(gid);

  CollectionReference<Map<String, dynamic>> _assignments(String gid) =>
      _group(gid).collection(Collections.groupAssignments);

  CollectionReference<Map<String, dynamic>> _submissions(String gid, String aid) =>
      _assignments(gid).doc(aid).collection(Collections.assignmentSubmissions);

  @override
  Stream<SocialProfile> watchProfile(String uid) => _guardStream(_db
      .collection(AppConstants.collectionUsers)
      .doc(uid)
      .snapshots()
      .map((s) => SocialProfile.fromMap(uid, s.data())));

  @override
  Stream<List<ReferralItem>> watchReferrals(String uid) => _guardStream(_db
      .collection(Collections.referrals)
      .doc(uid)
      .collection(Collections.referralItems)
      .orderBy('joined_at', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) ReferralItem.fromMap(d.id, d.data())]));

  @override
  Stream<List<FriendEntry>> watchFriends(String uid) => _guardStream(_db
      .collection(Collections.friends)
      .doc(uid)
      .collection(Collections.friendList)
      .limit(60)
      .snapshots()
      .map((s) => [for (final d in s.docs) FriendEntry.fromMap(d.id, d.data())]
        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()))));

  @override
  Future<void> removeFriend(String uid, String friendUid) => _guard(
        'friend_remove',
        () => _db
            .collection(Collections.friends)
            .doc(uid)
            .collection(Collections.friendList)
            .doc(friendUid)
            .delete(),
      );

  @override
  Future<Map<String, LeaderboardEntry>> boardEntries(String boardId, List<String> uids) =>
      _guard('board_entries', () async {
        final entries = _db
            .collection(Collections.leaderboards)
            .doc(boardId)
            .collection(Collections.leaderboardEntries);
        final unique = uids.toSet().toList();
        final out = <String, LeaderboardEntry>{};
        for (var i = 0; i < unique.length; i += _whereInLimit) {
          final chunk = unique.sublist(i, (i + _whereInLimit).clamp(0, unique.length));
          final snap = await entries.where(FieldPath.documentId, whereIn: chunk).get();
          for (final d in snap.docs) {
            out[d.id] = LeaderboardEntry.fromMap(d.id, d.data());
          }
        }
        return out;
      });

  @override
  Future<LeaderboardSnapshot> loadBoard(String boardId, {String? uid}) =>
      _guard('board_load', () => LeaderboardService.instance.load(boardId, uid: uid));

  @override
  Future<List<StudyGroup>> loadGroups(List<String> groupIds) => _guard('groups_load', () async {
        final docs = await Future.wait(groupIds.toSet().map((id) async {
          try {
            return await _group(id).get();
          } on FirebaseException catch (e) {
            // A group the student was just removed from is no longer
            // readable; skip it instead of failing the whole list.
            if (e.code == 'permission-denied' || e.code == 'not-found') return null;
            rethrow;
          }
        }));
        return [
          for (final d in docs)
            if (d != null && d.exists) StudyGroup.fromMap(d.id, d.data()!),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });

  @override
  Stream<StudyGroup?> watchGroup(String groupId) => _guardStream(_group(groupId)
      .snapshots()
      .map((s) => s.exists ? StudyGroup.fromMap(s.id, s.data()!) : null));

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) => _guardStream(_group(groupId)
      .collection(Collections.groupMembers)
      .limit(StudyGroup.maxMembers)
      .snapshots()
      .map((s) => [for (final d in s.docs) GroupMember.fromMap(d.id, d.data())]
        ..sort((a, b) {
          if (a.role != b.role) return a.role == GroupRole.owner ? -1 : 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        })));

  @override
  Stream<List<GroupAssignment>> watchAssignments(String groupId) => _guardStream(_assignments(groupId)
      .orderBy('due_at')
      .limit(100)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              if (GroupAssignment.fromMap(d.id, d.data()) case final a?) a,
          ]));

  @override
  Stream<List<AssignmentSubmission>> watchSubmissions(String groupId, String assignmentId) =>
      _guardStream(_submissions(groupId, assignmentId)
          .limit(StudyGroup.maxMembers)
          .snapshots()
          .map((s) => [for (final d in s.docs) AssignmentSubmission.fromMap(d.id, d.data())]));

  @override
  Stream<AssignmentSubmission?> watchMySubmission(String groupId, String assignmentId, String uid) =>
      _guardStream(_submissions(groupId, assignmentId)
          .doc(uid)
          .snapshots()
          .map((s) => s.exists ? AssignmentSubmission.fromMap(uid, s.data()!) : null));

  @override
  Future<void> markAssignmentDone(String groupId, String assignmentId, String uid) => _guard(
        'assignment_done',
        // Exactly the fields the rules allow: the server time, no score
        // (the client has no trustworthy score to report).
        () => _submissions(groupId, assignmentId).doc(uid).set({
          'done_at': FieldValue.serverTimestamp(),
        }),
      );

  @override
  Future<void> createAssignment(String groupId, AssignmentDraft draft, {required String uid}) {
    if (!draft.isValid) return Future.error(const SocialFailure(SocialFailureKind.validation));
    return _guard(
      'assignment_create',
      () => _assignments(groupId).add({
        'title': draft.title.trim(),
        'kind': draft.kind.wire,
        'ref_id': draft.refId.trim(),
        'due_at': Timestamp.fromDate(draft.dueAt),
        'created_by': uid,
        'created_at': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> deleteAssignment(String groupId, String assignmentId) =>
      _guard('assignment_delete', () => _assignments(groupId).doc(assignmentId).delete());

  @override
  Future<List<AssignableItem>> assignableLessons(String lang) => _guard('pick_lessons', () async {
        final lessons = await FirebaseDataService().getAllLessons(limit: 300);
        return [
          for (final l in lessons)
            AssignableItem(id: l.id, title: l.getTitle(lang).trim().isEmpty ? l.id : l.getTitle(lang)),
        ];
      });

  @override
  Future<List<AssignableItem>> assignableSubjects(String lang) => _guard('pick_subjects', () async {
        final subjects = await FirebaseDataService().getSubjects();
        return [
          for (final s in subjects)
            AssignableItem(id: s.id, title: s.getTitle(lang).trim().isEmpty ? s.id : s.getTitle(lang)),
        ];
      });

  @override
  Future<List<AssignableItem>> assignableVariants(String lang) => _guard('pick_variants', () async {
        final snap = await _db
            .collection(Collections.examVariants)
            .where('status', isEqualTo: 'published')
            .limit(200)
            .get();
        final items = <AssignableItem>[];
        for (final d in snap.docs) {
          final m = d.data();
          final title = LocalizedText.fromJson(m['title']).resolve(lang);
          final number = JsonRead.integer(m, ['number']);
          items.add(AssignableItem(
            id: d.id,
            title: title.trim().isNotEmpty ? title : (number != null ? '#$number' : d.id),
            blueprintId: JsonRead.string(m, ['blueprint_id']),
            language: JsonRead.string(m, ['language']),
          ));
        }
        items.sort((a, b) {
          final byBlueprint = (a.blueprintId ?? '').compareTo(b.blueprintId ?? '');
          if (byBlueprint != 0) return byBlueprint;
          final byLang = (a.language ?? '').compareTo(b.language ?? '');
          return byLang != 0 ? byLang : a.title.compareTo(b.title);
        });
        return items;
      });
}
