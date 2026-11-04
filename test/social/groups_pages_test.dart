import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/social/domain/social_models.dart';
import 'package:knowledge_flow/features/social/presentation/pages/group_detail_page.dart';
import 'package:knowledge_flow/features/social/presentation/pages/groups_page.dart';
import 'package:knowledge_flow/shared/models/leaderboard_model.dart';

import 'social_fakes.dart';

FirebaseFunctionsException _reason(String reason) =>
    FirebaseFunctionsException(message: 'x', code: 'failed-precondition', details: {'reason': reason});

const _owned = StudyGroup(id: 'g1', name: '11 «Б», школа № 5', ownerUid: 'me', joinCode: 'JOIN11', memberCount: 3);
const _joined = StudyGroup(id: 'g2', name: 'Учебный центр «Билим»', ownerUid: 'teacher', joinCode: 'BILIM2', memberCount: 12);

final _now = DateTime(2026, 11, 4, 12);

FakeSocialRepository _repo({List<String> groupIds = const ['g1', 'g2']}) => FakeSocialRepository(
      profile: SocialProfile(uid: 'me', groupIds: groupIds),
      groups: const [_owned, _joined],
      members: const {
        'g1': [
          GroupMember(uid: 'me', displayName: 'Учитель', role: GroupRole.owner),
          GroupMember(uid: 's1', displayName: 'Айбек'),
          GroupMember(uid: 's2', displayName: 'Нурай'),
        ],
        'g2': [
          GroupMember(uid: 'teacher', displayName: 'Учитель', role: GroupRole.owner),
          GroupMember(uid: 'me', displayName: 'Я'),
        ],
      },
      assignments: {
        'g1': [
          GroupAssignment(
            id: 'a1',
            title: 'Повторить степени',
            kind: AssignmentKind.lesson,
            refId: 'l1',
            dueAt: DateTime(2026, 11, 10),
          ),
        ],
        'g2': [
          GroupAssignment(
            id: 'b1',
            title: 'Вариант 1 до пятницы',
            kind: AssignmentKind.examVariant,
            refId: 'v1',
            dueAt: DateTime(2026, 11, 1),
          ),
          const GroupAssignment(id: 'b2', title: 'Практика по математике', kind: AssignmentKind.practice, refId: 'math'),
        ],
      },
      submissions: {
        'g1/a1': [AssignmentSubmission(uid: 's1', doneAt: DateTime(2026, 11, 3))],
      },
    );

void main() {
  group('groups list', () {
    testWidgets('my groups with member counts and the owner badge', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupsPage(), repo: repo);
      await tester.pump();
      expect(find.text('11 «Б», школа № 5'), findsOneWidget);
      expect(find.text('3 участника · Владелец'), findsOneWidget);
      expect(find.text('12 участников'), findsOneWidget);
      expect(find.text('Можно состоять не больше чем в 5 группах.'), findsOneWidget);

      await tester.tap(find.text('Учебный центр «Билим»'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /groups/g2'), findsOneWidget);
    });

    testWidgets('empty: explanation and both actions', (tester) async {
      final repo = _repo(groupIds: const []);
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupsPage(), repo: repo);
      await tester.pump();
      expect(find.text('Вы пока не состоите в группах'), findsOneWidget);
      expect(find.byKey(const ValueKey('groups_join')), findsOneWidget);
      expect(find.byKey(const ValueKey('groups_create')), findsOneWidget);
    });

    testWidgets('join by code: errors inline, success opens the group', (tester) async {
      final repo = _repo(groupIds: const []);
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupsPage(), repo: repo);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('groups_join')));
      await tester.pumpAndSettle();

      repo.groupJoinError = _reason('CODE_INVALID');
      await tester.enterText(find.byKey(const ValueKey('group_code_field')), 'bilim2');
      await tester.tap(find.byKey(const ValueKey('group_join_submit')));
      await tester.pump();
      await tester.pump();
      expect(repo.joinCodes, ['BILIM2']);
      expect(find.text('Такого кода нет. Проверьте его и попробуйте ещё раз.'), findsOneWidget);

      repo.groupJoinError = _reason('LIMIT_REACHED');
      await tester.tap(find.byKey(const ValueKey('group_join_submit')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Достигнут лимит: не больше 5 групп.'), findsOneWidget);

      repo.groupJoinError = null;
      await tester.tap(find.byKey(const ValueKey('group_join_submit')));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /groups/g2'), findsOneWidget);
    });

    testWidgets('create: name check, then the join code to share', (tester) async {
      final repo = _repo(groupIds: const []);
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupsPage(), repo: repo);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('groups_create')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('group_create_submit')));
      await tester.pump();
      expect(find.text('Введите название до 60 символов.'), findsOneWidget);
      expect(repo.createdGroups, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('group_name_field')), '  10   «А» ');
      await tester.tap(find.byKey(const ValueKey('group_create_submit')));
      await tester.pumpAndSettle();
      expect(repo.createdGroups, ['10 «А»']);
      expect(find.text('Группа создана'), findsOneWidget);
      expect(find.text('JOIN99'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('group_created_open')));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /groups/g9'), findsOneWidget);
    });

    testWidgets('[ky] dark 360dp without overflow', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupsPage(), repo: repo, locale: 'ky', brightness: Brightness.dark);
      await tester.pump();
      expect(find.text('12 мүчө'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('group detail — member', () {
    testWidgets('assignments open their target; "mark as done" writes my submission', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g2'), repo: repo, now: _now);
      await tester.pump();

      expect(find.text('Учебный центр «Билим»'), findsOneWidget);
      expect(find.text('Код для вступления: BILIM2'), findsOneWidget);
      expect(find.text('Вариант 1 до пятницы'), findsOneWidget);
      expect(find.text('Просрочено'), findsOneWidget, reason: 'due 1 Nov, not done');
      // Members do not manage assignments.
      expect(find.byKey(const ValueKey('assignment_add')), findsNothing);
      expect(find.byKey(const ValueKey('assignment_delete_b1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('assignment_done_b1')));
      await tester.pump();
      await tester.pump();
      expect(repo.doneMarks, [('g2', 'b1', 'me')]);
      expect(find.byKey(const ValueKey('assignment_done_b1')), findsNothing);
      expect(find.textContaining('Выполнено'), findsWidgets);
      expect(find.text('Просрочено'), findsNothing);

      await tester.tap(find.text('Открыть').first);
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /exams/variant/v1'), findsOneWidget);
    });

    testWidgets('practice assignment opens the subject practice', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g2'), repo: repo, now: _now);
      await tester.pump();
      await tester.tap(find.text('Открыть').last);
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /quiz/math'), findsOneWidget);
    });

    testWidgets('members tab: no remove buttons; rating tab: weekly group league', (tester) async {
      final repo = _repo()
        ..board = const LeaderboardSnapshot(
          boardId: 'group_g2_weekly_2026-W45',
          top: [
            LeaderboardEntry(uid: 'teacher', displayName: 'Учитель', xp: 300),
            LeaderboardEntry(uid: 'me', displayName: 'Я', xp: 120),
          ],
        );
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g2'), repo: repo, now: _now);
      await tester.pump();

      await tester.tap(find.text('Участники'));
      await tester.pumpAndSettle();
      expect(find.text('Я (вы)'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_remove_teacher')), findsNothing);

      await tester.tap(find.text('Рейтинг'));
      await tester.pumpAndSettle();
      expect(find.text('300 XP'), findsOneWidget);
      expect(find.text('Я (вы)'), findsOneWidget);
    });

    testWidgets('leave: confirmation, then back', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g2'), repo: repo, now: _now);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('group_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти из группы'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Вернуться можно по коду'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Выйти из группы'));
      await tester.pumpAndSettle();
      expect(repo.leftGroups, ['g2']);
    });
  });

  group('group detail — owner', () {
    testWidgets('sees each member\'s status, can remove members and cannot leave a non-empty group',
        (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g1'), repo: repo, now: _now);
      await tester.pump();

      expect(find.text('Выполнили: 1 из 2'), findsOneWidget);
      await tester.tap(find.text('Выполнили: 1 из 2'));
      await tester.pumpAndSettle();
      expect(find.text('Айбек'), findsOneWidget);
      expect(find.text('Нурай'), findsOneWidget);
      expect(find.text('Не выполнено'), findsOneWidget);

      // Leaving is blocked while there are members.
      await tester.tap(find.byKey(const ValueKey('group_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти из группы'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Владелец может выйти, только когда'), findsOneWidget);
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(repo.leftGroups, isEmpty);

      await tester.tap(find.text('Участники'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member_remove_me')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('member_remove_s2')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pumpAndSettle();
      expect(repo.removedMembers, [('g1', 's2')]);
      expect(find.text('Нурай'), findsNothing);
    });

    testWidgets('creates an assignment: pick a lesson by search, title prefilled, due date', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g1'), repo: repo, now: _now);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('assignment_add')));
      await tester.pumpAndSettle();
      expect(find.text('Новое задание'), findsOneWidget);

      // Nothing picked yet.
      await tester.tap(find.byKey(const ValueKey('assignment_save')));
      await tester.pump();
      expect(find.text('Выберите, что задать.'), findsOneWidget);
      expect(repo.createdAssignments, isEmpty);

      await tester.tap(find.byKey(const ValueKey('assignment_pick_target')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('assignment_picker_search')), 'проц');
      await tester.pumpAndSettle();
      expect(find.text('Квадратные уравнения'), findsNothing);
      await tester.tap(find.text('Проценты'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('assignment_save')));
      await tester.tap(find.byKey(const ValueKey('assignment_save')));
      await tester.pumpAndSettle();
      expect(repo.createdAssignments, hasLength(1));
      final (gid, draft) = repo.createdAssignments.single;
      expect(gid, 'g1');
      expect(draft.kind, AssignmentKind.lesson);
      expect(draft.refId, 'l2');
      expect(draft.title, 'Проценты');
      expect(draft.dueAt, DateTime(2026, 11, 11, 23, 59), reason: 'a week from now by default');
      expect(find.text('Задание добавлено'), findsOneWidget);
    });

    testWidgets('exam variant picker shows the direction, not the raw blueprint id', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g1'), repo: repo, now: _now);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assignment_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assignment_kind_exam_variant')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assignment_pick_target')));
      await tester.pumpAndSettle();
      expect(find.text('Вариант 1'), findsOneWidget);
      expect(find.textContaining('ort_main_2026'), findsNothing);
    });

    testWidgets('deletes an assignment after confirmation', (tester) async {
      final repo = _repo();
      addTearDown(repo.dispose);
      await pumpSocial(tester, const GroupDetailPage(groupId: 'g1'), repo: repo, now: _now);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assignment_delete_a1')));
      await tester.pumpAndSettle();
      expect(find.text('Удалить задание «Повторить степени»?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pumpAndSettle();
      expect(repo.deletedAssignments, [('g1', 'a1')]);
      expect(find.text('Повторить степени'), findsNothing);
      expect(find.text('Заданий пока нет.'), findsOneWidget);
    });

    for (final locale in ['ru', 'ky', 'en']) {
      testWidgets('[$locale] dark 360dp without overflow', (tester) async {
        final repo = _repo();
        addTearDown(repo.dispose);
        await pumpSocial(tester, const GroupDetailPage(groupId: 'g1'),
            repo: repo, now: _now, locale: locale, brightness: Brightness.dark);
        await tester.pump();
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a group that is no longer readable shows a clear state', (tester) async {
    final repo = _repo();
    addTearDown(repo.dispose);
    await pumpSocial(tester, const GroupDetailPage(groupId: 'gone'), repo: repo, now: _now);
    await tester.pump();
    expect(find.text('Эта группа вам больше недоступна.'), findsOneWidget);
  });
}
