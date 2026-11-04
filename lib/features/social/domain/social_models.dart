import 'package:flutter/foundation.dart';

import '../../../core/utils/json_read.dart';

/// The social part of `users/{uid}` (privileged fields are written only by
/// the server; the client reads them).
@immutable
class SocialProfile {
  final String uid;
  final String? referralCode;
  final String? referredBy;
  final List<String> groupIds;
  final String displayName;

  /// `users/{uid}.region.oblast` — the stored (canonical) region value.
  final String? regionOblast;

  const SocialProfile({
    required this.uid,
    this.referralCode,
    this.referredBy,
    this.groupIds = const [],
    this.displayName = '',
    this.regionOblast,
  });

  bool get wasReferred => referredBy != null && referredBy!.isNotEmpty;

  factory SocialProfile.fromMap(String uid, Map<String, dynamic>? m) {
    final d = m ?? const <String, dynamic>{};
    final region = JsonRead.map(d, ['region']);
    final ids = JsonRead.stringList(d, ['group_ids']).where((s) => s.isNotEmpty).toSet().toList();
    return SocialProfile(
      uid: uid,
      referralCode: JsonRead.string(d, ['referral_code']),
      referredBy: JsonRead.string(d, ['referred_by']),
      groupIds: List.unmodifiable(ids),
      displayName: JsonRead.stringOr(d, ['name', 'display_name', 'displayName']),
      regionOblast: region == null
          ? JsonRead.string(d, ['region'])
          : JsonRead.string(region, ['oblast']),
    );
  }
}

enum ReferralStatus {
  joined,
  rewarded;

  static ReferralStatus parse(Object? v) => v == 'rewarded' ? rewarded : joined;
}

/// `referrals/{referrerUid}/items/{uid}` — one invited friend.
@immutable
class ReferralItem {
  final String uid;
  final ReferralStatus status;
  final String displayName;
  final DateTime? joinedAt;
  final DateTime? rewardedAt;

  const ReferralItem({
    required this.uid,
    required this.status,
    this.displayName = '',
    this.joinedAt,
    this.rewardedAt,
  });

  factory ReferralItem.fromMap(String uid, Map<String, dynamic> m) => ReferralItem(
        uid: uid,
        status: ReferralStatus.parse(m['status']),
        displayName: JsonRead.stringOr(m, ['display_name']),
        joinedAt: JsonRead.date(m, ['joined_at']),
        rewardedAt: JsonRead.date(m, ['rewarded_at']),
      );
}

/// Answer of `promoRedeem`.
@immutable
class PromoRedeemResult {
  final int credits;
  final int? balance;

  const PromoRedeemResult({required this.credits, this.balance});

  factory PromoRedeemResult.fromMap(Map<String, dynamic> m) => PromoRedeemResult(
        credits: JsonRead.intOr(m, ['credits'], 0),
        balance: JsonRead.integer(m, ['balance']),
      );
}

/// `friends/{uid}/list/{friendUid}`.
@immutable
class FriendEntry {
  final String uid;
  final String displayName;
  final DateTime? addedAt;

  const FriendEntry({required this.uid, this.displayName = '', this.addedAt});

  factory FriendEntry.fromMap(String uid, Map<String, dynamic> m) => FriendEntry(
        uid: uid,
        displayName: JsonRead.stringOr(m, ['display_name']),
        addedAt: JsonRead.date(m, ['added_at']),
      );
}

/// `groups/{gid}` (a class or a learning centre).
@immutable
class StudyGroup {
  final String id;
  final String name;
  final String ownerUid;
  final String joinCode;
  final int memberCount;
  final DateTime? createdAt;

  const StudyGroup({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.joinCode = '',
    this.memberCount = 0,
    this.createdAt,
  });

  bool isOwner(String? uid) => uid != null && uid == ownerUid;

  factory StudyGroup.fromMap(String id, Map<String, dynamic> m) => StudyGroup(
        id: id,
        name: JsonRead.stringOr(m, ['name']),
        ownerUid: JsonRead.stringOr(m, ['owner_uid']),
        joinCode: JsonRead.stringOr(m, ['join_code']),
        memberCount: JsonRead.intOr(m, ['member_count'], 0),
        createdAt: JsonRead.date(m, ['created_at']),
      );
}

enum GroupRole {
  owner,
  member;

  static GroupRole parse(Object? v) => v == 'owner' ? owner : member;
}

/// `groups/{gid}/members/{uid}`.
@immutable
class GroupMember {
  final String uid;
  final String displayName;
  final GroupRole role;
  final DateTime? joinedAt;

  const GroupMember({
    required this.uid,
    this.displayName = '',
    this.role = GroupRole.member,
    this.joinedAt,
  });

  factory GroupMember.fromMap(String uid, Map<String, dynamic> m) => GroupMember(
        uid: uid,
        displayName: JsonRead.stringOr(m, ['display_name']),
        role: GroupRole.parse(m['role']),
        joinedAt: JsonRead.date(m, ['joined_at']),
      );
}

/// What a homework assignment points at.
enum AssignmentKind {
  lesson,
  practice,
  examVariant;

  /// Value stored in `assignments/{aid}.kind`.
  String get wire => switch (this) {
        lesson => 'lesson',
        practice => 'practice',
        examVariant => 'exam_variant',
      };

  static AssignmentKind? parse(Object? v) => switch (v) {
        'lesson' => lesson,
        'practice' => practice,
        'exam_variant' => examVariant,
        _ => null,
      };
}

/// `groups/{gid}/assignments/{aid}` (FR-LRN-6).
@immutable
class GroupAssignment {
  final String id;
  final String title;
  final AssignmentKind kind;
  final String refId;
  final DateTime? dueAt;
  final String createdBy;
  final DateTime? createdAt;

  const GroupAssignment({
    required this.id,
    required this.title,
    required this.kind,
    required this.refId,
    this.dueAt,
    this.createdBy = '',
    this.createdAt,
  });

  bool isOverdue(DateTime now) => dueAt != null && dueAt!.isBefore(now);

  /// Null when the stored kind is unknown (newer app version wrote it).
  static GroupAssignment? fromMap(String id, Map<String, dynamic> m) {
    final kind = AssignmentKind.parse(m['kind']);
    if (kind == null) return null;
    return GroupAssignment(
      id: id,
      title: JsonRead.stringOr(m, ['title']),
      kind: kind,
      refId: JsonRead.stringOr(m, ['ref_id']),
      dueAt: JsonRead.date(m, ['due_at']),
      createdBy: JsonRead.stringOr(m, ['created_by']),
      createdAt: JsonRead.date(m, ['created_at']),
    );
  }
}

/// Fields of a new assignment (the owner fills them in).
@immutable
class AssignmentDraft {
  /// Upper bound for the title; the rules reject longer ones.
  static const maxTitleLength = 100;

  final String title;
  final AssignmentKind kind;
  final String refId;
  final DateTime dueAt;

  const AssignmentDraft({
    required this.title,
    required this.kind,
    required this.refId,
    required this.dueAt,
  });

  bool get isValid =>
      title.trim().isNotEmpty &&
      title.trim().length <= maxTitleLength &&
      (kind == AssignmentKind.practice || refId.trim().isNotEmpty);
}

/// `groups/{gid}/assignments/{aid}/submissions/{uid}`.
@immutable
class AssignmentSubmission {
  final String uid;
  final DateTime? doneAt;
  final double? scorePercent;

  const AssignmentSubmission({required this.uid, this.doneAt, this.scorePercent});

  factory AssignmentSubmission.fromMap(String uid, Map<String, dynamic> m) =>
      AssignmentSubmission(
        uid: uid,
        doneAt: JsonRead.date(m, ['done_at']),
        scorePercent: JsonRead.decimal(m, ['score_percent']),
      );
}

/// Answer of `groupCreate`.
@immutable
class GroupCreated {
  final String groupId;
  final String joinCode;
  const GroupCreated({required this.groupId, required this.joinCode});
}

/// Answer of `friendAdd`.
@immutable
class FriendAdded {
  final String? friendUid;
  final String displayName;
  const FriendAdded({this.friendUid, this.displayName = ''});
}

/// An item the group owner can assign (lesson, practice subject or exam
/// variant), shown in the assignment picker.
@immutable
class AssignableItem {
  final String id;
  final String title;

  /// Exam variants only: the blueprint (direction) and the variant language.
  final String? blueprintId;
  final String? language;

  const AssignableItem({required this.id, required this.title, this.blueprintId, this.language});

  /// Case-insensitive match on title or id.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) || id.toLowerCase().contains(q);
  }
}
