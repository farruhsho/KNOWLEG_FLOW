import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/social/domain/social_models.dart';
import 'package:knowledge_flow/features/social/presentation/pages/groups_page.dart';

import 'social_fakes.dart';

/// Like the real backend: `groupCreate` / `groupJoin` add the group to
/// `users/{uid}.group_ids`, and the profile stream emits that change while the
/// dialog is still open. The groups page then swaps its empty state for the
/// list, which unmounts the widget that opened the dialog.
class _ServerLikeRepo extends FakeSocialRepository {
  _ServerLikeRepo()
      : super(
          profile: const SocialProfile(uid: 'me'),
          groups: const [
            StudyGroup(id: 'g9', name: 'Новая группа', ownerUid: 'me', joinCode: 'JOIN99', memberCount: 1),
            StudyGroup(id: 'g2', name: 'Учебный центр «Билим»', ownerUid: 'teacher', joinCode: 'BILIM2', memberCount: 12),
          ],
        );

  final _profiles = StreamController<SocialProfile>.broadcast();

  @override
  Stream<SocialProfile> watchProfile(String uid) async* {
    yield profile;
    yield* _profiles.stream;
  }

  void _addGroup(String id) {
    profile = SocialProfile(uid: 'me', groupIds: [...profile.groupIds, id]);
    _profiles.add(profile);
  }

  @override
  Future<GroupCreated> groupCreate(String name) async {
    final created = await super.groupCreate(name);
    _addGroup(created.groupId);
    return created;
  }

  @override
  Future<String> groupJoin(String code) async {
    final id = await super.groupJoin(code);
    _addGroup(id);
    return id;
  }

  @override
  void dispose() {
    _profiles.close();
    super.dispose();
  }
}

void main() {
  // Found in the emulator walkthrough: after creating the first group,
  // "Открыть группу" did nothing, because the opener was already unmounted.
  testWidgets('first group: "Открыть группу" opens it although the page switched to the list', (tester) async {
    final repo = _ServerLikeRepo();
    addTearDown(repo.dispose);
    await pumpSocial(tester, const GroupsPage(), repo: repo);
    await tester.pump();
    expect(find.text('Вы пока не состоите в группах'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('groups_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('group_name_field')), 'Новая группа');
    await tester.tap(find.byKey(const ValueKey('group_create_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Группа создана'), findsOneWidget);
    expect(find.text('JOIN99'), findsOneWidget);
    // Behind the dialog the page already shows the list.
    expect(find.text('Новая группа', skipOffstage: false), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('group_created_open')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /groups/g9'), findsOneWidget);
  });

  testWidgets('first group: joining by code opens it although the page switched to the list', (tester) async {
    final repo = _ServerLikeRepo();
    addTearDown(repo.dispose);
    await pumpSocial(tester, const GroupsPage(), repo: repo);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('groups_join')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('group_code_field')), 'bilim2');
    await tester.tap(find.byKey(const ValueKey('group_join_submit')));
    await tester.pumpAndSettle();

    expect(repo.joinCodes, ['BILIM2']);
    expect(find.text('ROUTE /groups/g2'), findsOneWidget);
  });
}
