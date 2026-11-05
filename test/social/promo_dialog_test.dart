import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/billing/presentation/widgets/promo_code_dialog.dart';
import 'package:knowledge_flow/features/social/domain/social_models.dart';

import 'social_fakes.dart';

FirebaseFunctionsException _reason(String reason) =>
    FirebaseFunctionsException(message: 'x', code: 'failed-precondition', details: {'reason': reason});

/// Opens the dialog from a button so the result can be observed.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  PromoRedeemResult? result;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  final r = await showPromoCodeDialog(context);
                  setState(() => result = r);
                },
                child: const Text('OPEN'),
              ),
              Text('RESULT ${result?.credits}'),
            ],
          ),
        ),
      );
}

void main() {
  late FakeSocialRepository repo;
  setUp(() => repo = FakeSocialRepository());
  tearDown(() => repo.dispose());

  Future<void> open(WidgetTester tester, {String locale = 'ru', Brightness brightness = Brightness.light}) async {
    await pumpSocial(tester, const _Host(), repo: repo, locale: locale, brightness: brightness);
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  Future<void> redeem(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(const ValueKey('promo_code_field')), code);
    await tester.tap(find.byKey(const ValueKey('promo_redeem')));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('redeems a code and shows the credited amount and balance', (tester) async {
    await open(tester);
    expect(find.text('Ввести промокод'), findsOneWidget);
    await redeem(tester, ' ort-2026 ');
    expect(repo.promoCodes, ['ORT2026'], reason: 'normalised before sending');
    expect(find.text('Зачислено 2 кредита'), findsOneWidget);
    expect(find.text('Кредитов на аккаунте: 5'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('RESULT 2'), findsOneWidget);
  });

  testWidgets('malformed code: message, no server call (attempts are rate-limited)', (tester) async {
    await open(tester);
    await redeem(tester, 'ab');
    expect(find.text('Промокод — от 4 до 20 латинских букв и цифр.'), findsOneWidget);
    expect(repo.promoCodes, isEmpty);
  });

  const cases = {
    'CODE_INVALID': 'Такого кода нет. Проверьте его и попробуйте ещё раз.',
    'CODE_EXPIRED': 'Срок действия промокода истёк.',
    'CODE_EXHAUSTED': 'Промокод закончился: все активации уже использованы.',
    'ALREADY_REDEEMED': 'Вы уже использовали этот промокод.',
    'RATE_LIMITED': 'Слишком много попыток за сегодня. Попробуйте завтра.',
  };
  cases.forEach((reason, message) {
    testWidgets('$reason → clear message, dialog stays open', (tester) async {
      repo.promoError = _reason(reason);
      await open(tester);
      await redeem(tester, 'PROMO10');
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const ValueKey('promo_code_field')), findsOneWidget);
      expect(find.text('Зачислено 2 кредита'), findsNothing);
    });
  });

  testWidgets('cancel returns nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('RESULT null'), findsOneWidget);
    expect(repo.promoCodes, isEmpty);
  });

  testWidgets('[ky] dark mode renders without overflow', (tester) async {
    repo.promoError = _reason('CODE_EXHAUSTED');
    await open(tester, locale: 'ky', brightness: Brightness.dark);
    await redeem(tester, 'PROMO10');
    expect(find.text('Промокод түгөндү: бардык активациялар колдонулуп бүткөн.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
