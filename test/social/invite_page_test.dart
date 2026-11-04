import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/social/domain/social_models.dart';
import 'package:knowledge_flow/features/social/presentation/pages/invite_page.dart';
import 'package:knowledge_flow/features/social/presentation/widgets/pending_referral_card.dart';

import 'social_fakes.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

FirebaseFunctionsException _reason(String reason) =>
    FirebaseFunctionsException(message: 'x', code: 'failed-precondition', details: {'reason': reason});

void main() {
  late FakeSocialRepository repo;
  String? clipboard;

  setUp(() {
    repo = FakeSocialRepository(
      referrals: [
        ReferralItem(uid: 'r1', status: ReferralStatus.rewarded, displayName: 'Айбек', rewardedAt: DateTime(2026, 11, 1)),
        const ReferralItem(uid: 'r2', status: ReferralStatus.joined, displayName: ''),
      ],
    );
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
  });

  tearDown(() {
    repo.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('shows my code (one server call, then cached), copy and share text', (tester) async {
    await pumpSocial(tester, const InvitePage(), repo: repo);
    await tester.pump();

    expect(find.text('Пригласить друзей'), findsOneWidget);
    expect(find.text('K7M2QX'), findsOneWidget);
    expect(repo.referralGetCodeCalls, 1);

    await tester.tap(find.text('Скопировать код'));
    await tester.pump();
    expect(clipboard, 'K7M2QX');
    expect(find.text('Код скопирован'), findsOneWidget);

    await tester.tap(find.text('Скопировать приглашение'));
    await tester.pump();
    expect(clipboard, contains('K7M2QX'));
    expect(clipboard, contains('+1 кредит'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached code: no callable on the next visit', (tester) async {
    await pumpSocial(tester, const InvitePage(), repo: repo, prefs: {'social_my_referral_code_v1:me': 'ABC234'});
    await tester.pump();
    expect(find.text('ABC234'), findsOneWidget);
    expect(repo.referralGetCodeCalls, 0);
  });

  testWidgets('honest reward explanation and the referral list', (tester) async {
    await pumpSocial(tester, const InvitePage(), repo: repo);
    await tester.pump();
    expect(find.textContaining('впервые оплатит пробный экзамен'), findsOneWidget);
    expect(find.textContaining('Одна регистрация награды не даёт'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Айбек'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Присоединились: 2 · наград: 1'), findsOneWidget);
    expect(find.textContaining('Награда получена: +1 кредит'), findsOneWidget);
    expect(find.text('Ученик'), findsOneWidget, reason: 'no name → neutral label');
    expect(find.textContaining('Присоединился. Награда'), findsOneWidget);
  });

  testWidgets('entering a friend\'s code: format check, own code, server errors, success', (tester) async {
    await pumpSocial(tester, const InvitePage(), repo: repo);
    await tester.pump();
    final field = find.byKey(const ValueKey('friend_code_field'));
    final apply = find.byKey(const ValueKey('apply_friend_code'));
    await _scrollTo(tester, apply);

    // Malformed: no server call.
    await tester.enterText(field, 'abc');
    await tester.tap(apply);
    await tester.pump();
    expect(find.textContaining('6 букв и цифр'), findsOneWidget);
    expect(repo.appliedCodes, isEmpty);

    // My own code.
    await tester.enterText(field, 'k7m2qx');
    await tester.tap(apply);
    await tester.pump();
    expect(find.text('Это ваш собственный код. Введите код друга.'), findsOneWidget);
    expect(repo.appliedCodes, isEmpty);

    // Server: unknown code.
    repo.referralApplyError = _reason('CODE_INVALID');
    await tester.enterText(field, 'HJK234');
    await tester.tap(apply);
    await tester.pump();
    await tester.pump();
    expect(repo.appliedCodes, ['HJK234']);
    expect(find.text('Такого кода нет. Проверьте его и попробуйте ещё раз.'), findsOneWidget);

    // Server: account not new any more.
    repo.referralApplyError = _reason('REFERRAL_NOT_ALLOWED');
    await tester.tap(apply);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('только в новом аккаунте'), findsOneWidget);

    // Server: already referred.
    repo.referralApplyError = _reason('ALREADY_REDEEMED');
    await tester.tap(apply);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('уже вводили код друга'), findsOneWidget);

    // Success.
    repo.referralApplyError = null;
    await tester.tap(apply);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('friend_code_field')), findsNothing);
    expect(find.textContaining('Код друга применён'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cyrillic look-alikes typed on a Russian keyboard are converted', (tester) async {
    await pumpSocial(tester, const InvitePage(), repo: repo);
    await tester.pump();
    final field = find.byKey(const ValueKey('friend_code_field'));
    await _scrollTo(tester, find.byKey(const ValueKey('apply_friend_code')));
    await tester.enterText(field, 'нк7 м2р');
    await tester.tap(find.byKey(const ValueKey('apply_friend_code')));
    await tester.pump();
    await tester.pump();
    expect(repo.appliedCodes, ['HK7M2P']);
  });

  testWidgets('already referred: no input, a plain statement instead', (tester) async {
    repo.profile = const SocialProfile(uid: 'me', referredBy: 'friend');
    await pumpSocial(tester, const InvitePage(), repo: repo);
    await tester.pump();
    await _scrollTo(tester, find.text('Вы присоединились по коду друга.'));
    expect(find.text('Вы присоединились по коду друга.'), findsOneWidget);
    expect(find.byKey(const ValueKey('friend_code_field')), findsNothing);
  });

  testWidgets('signed out: sign-in prompt, nothing loaded', (tester) async {
    await pumpSocial(tester, const InvitePage(), repo: repo, uid: null);
    expect(find.text('Войдите, чтобы приглашать друзей и вступать в группы.'), findsOneWidget);
    expect(repo.referralGetCodeCalls, 0);
  });

  for (final locale in ['ky', 'en']) {
    testWidgets('[$locale] dark mode on a 360dp phone renders without overflow', (tester) async {
      await pumpSocial(tester, const InvitePage(), repo: repo, brightness: Brightness.dark, locale: locale);
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('apply_friend_code')), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home card applies a code typed during onboarding only after a tap', (tester) async {
    await pumpSocial(
      tester,
      const Scaffold(body: PendingReferralCard()),
      repo: repo,
      prefs: {'social_pending_referral_code_v1': 'HJK234'},
    );
    expect(find.text('Код друга HJK234'), findsOneWidget);
    expect(repo.appliedCodes, isEmpty, reason: 'never applied silently');

    repo.referralApplyError = _reason('REFERRAL_NOT_ALLOWED');
    await tester.tap(find.byKey(const ValueKey('pending_referral_apply')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('только в новом аккаунте'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending_referral_apply')), findsNothing, reason: 'retrying cannot help');

    await tester.tap(find.text('Не применять'));
    await tester.pump();
    expect(find.text('Код друга HJK234'), findsNothing);
  });
}
