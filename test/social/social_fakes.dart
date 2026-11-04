import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/social/application/social_providers.dart';
import 'package:knowledge_flow/features/social/data/referral_local_store.dart';
import 'package:knowledge_flow/features/social/data/social_repository.dart';
import 'package:knowledge_flow/features/social/domain/social_failure.dart';
import 'package:knowledge_flow/features/social/domain/social_models.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/shared/models/leaderboard_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory social backend for widget tests (no Firebase). Streams are
/// broadcast controllers seeded with the current value.
class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({
    this.profile = const SocialProfile(uid: 'me'),
    this.referralCode = 'K7M2QX',
    List<ReferralItem> referrals = const [],
    List<StudyGroup> groups = const [],
    Map<String, List<GroupMember>> members = const {},
    Map<String, List<GroupAssignment>> assignments = const {},
    Map<String, List<AssignmentSubmission>> submissions = const {},
  })  : _referrals = [...referrals],
        _groups = {for (final g in groups) g.id: g},
        _members = {for (final e in members.entries) e.key: [...e.value]},
        _assignments = {for (final e in assignments.entries) e.key: [...e.value]},
        _submissions = {for (final e in submissions.entries) e.key: [...e.value]};

  SocialProfile profile;
  String referralCode;
  final List<ReferralItem> _referrals;
  final Map<String, StudyGroup> _groups;
  final Map<String, List<GroupMember>> _members;
  final Map<String, List<GroupAssignment>> _assignments;
  final Map<String, List<AssignmentSubmission>> _submissions;
  List<FriendEntry> friends = [];
  Map<String, LeaderboardEntry> weeklyEntries = {};
  LeaderboardSnapshot? board;

  /// Next result of each callable: an exception to throw, or null for OK.
  Object? referralApplyError;
  Object? promoError;
  PromoRedeemResult promoResult = const PromoRedeemResult(credits: 2, balance: 5);
  Object? groupJoinError;
  String groupJoinResult = 'g2';
  GroupCreated groupCreateResult = const GroupCreated(groupId: 'g9', joinCode: 'JOIN99');

  int referralGetCodeCalls = 0;
  final appliedCodes = <String>[];
  final promoCodes = <String>[];
  final joinCodes = <String>[];
  final createdGroups = <String>[];
  final doneMarks = <(String, String, String)>[];
  final createdAssignments = <(String, AssignmentDraft)>[];
  final deletedAssignments = <(String, String)>[];
  final removedMembers = <(String, String)>[];
  final leftGroups = <String>[];
  List<AssignableItem> lessons = const [
    AssignableItem(id: 'l1', title: 'Квадратные уравнения'),
    AssignableItem(id: 'l2', title: 'Проценты'),
  ];

  final _tick = StreamController<void>.broadcast();

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    await for (final _ in _tick.stream) {
      yield read();
    }
  }

  void _changed() => _tick.add(null);

  @override
  Stream<SocialProfile> watchProfile(String uid) => _live(() => profile);

  @override
  Future<String> referralGetCode() async {
    referralGetCodeCalls++;
    return referralCode;
  }

  @override
  Future<void> referralApply(String code) async {
    appliedCodes.add(code);
    final e = referralApplyError;
    if (e != null) throw e;
  }

  @override
  Stream<List<ReferralItem>> watchReferrals(String uid) => _live(() => List.of(_referrals));

  @override
  Future<PromoRedeemResult> promoRedeem(String code) async {
    promoCodes.add(code);
    final e = promoError;
    if (e != null) throw e;
    return promoResult;
  }

  @override
  Stream<List<FriendEntry>> watchFriends(String uid) => _live(() => List.of(friends));

  @override
  Future<FriendAdded> friendAdd(String code) async => const FriendAdded(friendUid: 'f9', displayName: 'Айбек');

  @override
  Future<void> removeFriend(String uid, String friendUid) async {
    friends = friends.where((f) => f.uid != friendUid).toList();
    _changed();
  }

  @override
  Future<Map<String, LeaderboardEntry>> boardEntries(String boardId, List<String> uids) async =>
      {for (final u in uids) if (weeklyEntries[u] != null) u: weeklyEntries[u]!};

  @override
  Future<LeaderboardSnapshot> loadBoard(String boardId, {String? uid}) async =>
      board ?? LeaderboardSnapshot(boardId: boardId, top: const []);

  @override
  Future<List<StudyGroup>> loadGroups(List<String> groupIds) async =>
      [for (final id in groupIds) if (_groups[id] != null) _groups[id]!];

  @override
  Stream<StudyGroup?> watchGroup(String groupId) => _live(() => _groups[groupId]);

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) => _live(() => List.of(_members[groupId] ?? const []));

  @override
  Future<GroupCreated> groupCreate(String name) async {
    createdGroups.add(name);
    return groupCreateResult;
  }

  @override
  Future<String> groupJoin(String code) async {
    joinCodes.add(code);
    final e = groupJoinError;
    if (e != null) throw e;
    return groupJoinResult;
  }

  @override
  Future<void> groupLeave(String groupId) async => leftGroups.add(groupId);

  @override
  Future<void> groupRemoveMember(String groupId, String uid) async {
    removedMembers.add((groupId, uid));
    _members[groupId]?.removeWhere((m) => m.uid == uid);
    _changed();
  }

  @override
  Stream<List<GroupAssignment>> watchAssignments(String groupId) =>
      _live(() => List.of(_assignments[groupId] ?? const []));

  @override
  Stream<List<AssignmentSubmission>> watchSubmissions(String groupId, String assignmentId) =>
      _live(() => List.of(_submissions['$groupId/$assignmentId'] ?? const []));

  @override
  Stream<AssignmentSubmission?> watchMySubmission(String groupId, String assignmentId, String uid) => _live(() {
        for (final s in _submissions['$groupId/$assignmentId'] ?? const <AssignmentSubmission>[]) {
          if (s.uid == uid) return s;
        }
        return null;
      });

  @override
  Future<void> markAssignmentDone(String groupId, String assignmentId, String uid) async {
    doneMarks.add((groupId, assignmentId, uid));
    (_submissions['$groupId/$assignmentId'] ??= []).add(AssignmentSubmission(uid: uid, doneAt: DateTime(2026, 11, 4)));
    _changed();
  }

  @override
  Future<void> createAssignment(String groupId, AssignmentDraft draft, {required String uid}) async {
    if (!draft.isValid) throw const SocialFailure(SocialFailureKind.validation);
    createdAssignments.add((groupId, draft));
    (_assignments[groupId] ??= []).add(GroupAssignment(
      id: 'a${createdAssignments.length + 100}',
      title: draft.title,
      kind: draft.kind,
      refId: draft.refId,
      dueAt: draft.dueAt,
      createdBy: uid,
    ));
    _changed();
  }

  @override
  Future<void> deleteAssignment(String groupId, String assignmentId) async {
    deletedAssignments.add((groupId, assignmentId));
    _assignments[groupId]?.removeWhere((a) => a.id == assignmentId);
    _changed();
  }

  @override
  Future<List<AssignableItem>> assignableLessons(String lang) async => lessons;

  @override
  Future<List<AssignableItem>> assignableSubjects(String lang) async =>
      const [AssignableItem(id: 'math', title: 'Математика')];

  @override
  Future<List<AssignableItem>> assignableVariants(String lang) async => const [
        AssignableItem(id: 'v1', title: 'Вариант 1', blueprintId: 'ort_main_2026', language: 'ru'),
      ];

  void dispose() => _tick.close();
}

/// Pumps [home] on a 360×640 phone with the social providers faked. Every
/// other in-app path renders a stub "ROUTE path" page so navigation can be
/// asserted.
Future<GoRouter> pumpSocial(
  WidgetTester tester,
  Widget home, {
  required FakeSocialRepository repo,
  String? uid = 'me',
  Brightness brightness = Brightness.light,
  String locale = 'ru',
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(
        path: '/:a/:b',
        builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri.path}')),
      ),
      GoRoute(
        path: '/:a/:b/:c',
        builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri.path}')),
      ),
      GoRoute(
        path: '/:a/:b/:c/:d',
        builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri.path}')),
      ),
      GoRoute(
        path: '/:a',
        builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri.path}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      socialRepositoryProvider.overrideWithValue(repo),
      socialUidProvider.overrideWithValue(uid),
      referralLocalStoreProvider.overrideWithValue(ReferralLocalStore(sp)),
      if (now != null) socialClockProvider.overrideWithValue(() => now),
      ...overrides,
    ],
    child: MaterialApp.router(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
      ),
      routerConfig: router,
    ),
  ));
  await tester.pump();
  await tester.pump();
  return router;
}
