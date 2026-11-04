import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/social/presentation/widgets/friends_league.dart';

import 'social_fakes.dart';

FirebaseFunctionsException _details(String code, Map<String, Object> details) =>
    FirebaseFunctionsException(message: 'x', code: code, details: details);

const _ownCodeText = 'Это ваш собственный код. Введите код друга.';

Future<void> _openAddDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('friends_add')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const ValueKey('friend_add_field')), code);
  await tester.tap(find.byKey(const ValueKey('friend_add_submit')));
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeSocialRepository repo;

  setUp(() => repo = FakeSocialRepository());
  tearDown(() => repo.dispose());

  testWidgets('first visit (own code not loaded yet): own code is caught before any server call', (tester) async {
    await pumpSocial(tester, const Scaffold(body: FriendsLeagueView()), repo: repo);
    await tester.pump();
    expect(repo.referralGetCodeCalls, 0, reason: 'nothing loaded the own code before the dialog');

    await _openAddDialog(tester);
    await _submit(tester, 'k7m2qx');
    expect(find.text(_ownCodeText), findsOneWidget);
    expect(repo.friendCodes, isEmpty);
    expect(repo.referralGetCodeCalls, 1);
  });

  testWidgets('own code unknown on the device: the server answer (why: self) still reads "your own code"',
      (tester) async {
    repo.referralGetCodeError = _details('unavailable', const {});
    repo.friendAddError = _details('invalid-argument', {'reason': 'VALIDATION_FAILED', 'why': 'self', 'field': 'code'});
    await pumpSocial(tester, const Scaffold(body: FriendsLeagueView()), repo: repo);
    await tester.pump();

    await _openAddDialog(tester);
    await _submit(tester, 'K7M2QX');
    expect(repo.friendCodes, ['K7M2QX']);
    expect(find.text(_ownCodeText), findsOneWidget);
    expect(find.textContaining('Сервер не принял данные'), findsNothing);
  });

  testWidgets('daily attempt limit, then a friend\'s code is added', (tester) async {
    await pumpSocial(tester, const Scaffold(body: FriendsLeagueView()), repo: repo);
    await tester.pump();
    await _openAddDialog(tester);

    repo.friendAddError = _details('resource-exhausted', {'reason': 'RATE_LIMITED', 'what': 'code_attempts'});
    await _submit(tester, 'HJK234');
    expect(find.text('Слишком много попыток за сегодня. Попробуйте завтра.'), findsOneWidget);

    repo.friendAddError = null;
    await tester.tap(find.byKey(const ValueKey('friend_add_submit')));
    await tester.pumpAndSettle();
    expect(repo.friendCodes, ['HJK234', 'HJK234']);
    expect(find.byKey(const ValueKey('friend_add_field')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
