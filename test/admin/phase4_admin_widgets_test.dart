import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/admin/application/admin_providers.dart';
import 'package:knowledge_flow/features/admin/application/paged_list.dart';
import 'package:knowledge_flow/features/admin/data/admin_firebase.dart';
import 'package:knowledge_flow/features/admin/data/admin_functions.dart';
import 'package:knowledge_flow/features/admin/data/models/admin_records.dart';
import 'package:knowledge_flow/features/admin/domain/admin_nav.dart';
import 'package:knowledge_flow/features/admin/domain/admin_role.dart';
import 'package:knowledge_flow/features/admin/domain/blueprint_spec.dart';
import 'package:knowledge_flow/features/admin/domain/exam_pool.dart';
import 'package:knowledge_flow/features/admin/domain/payment_order.dart';
import 'package:knowledge_flow/features/admin/domain/pricing_config.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/exam_pool_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/ops_pages.dart';
import 'package:knowledge_flow/features/admin/presentation/shell/admin_shell.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/admin_widgets.dart' show AdminPageBody;
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/providers/admin_access_provider.dart';

import 'phase4_fixtures.dart';

// --- Fakes ------------------------------------------------------------------

class _TestSession extends AdminSessionNotifier {
  _TestSession(this.role);
  final AdminRole role;

  @override
  AdminSession? build() => AdminSession(uid: 'u1', email: 'staff@ort.kg', role: role);
}

class _NoFunctions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAdminFunctions extends AdminFunctions {
  _FakeAdminFunctions() : super(_NoFunctions());

  final poolUpdates = <Map<String, Object>>[];
  final refunds = <({String orderId, String reason})>[];
  final webPricing = <Map<String, Object>>[];
  RefundOrderResult refundResult = const RefundOrderResult(status: 'refunded', creditsClawedBack: 1);

  @override
  Future<void> updateExamPool(Map<String, Object> update) async => poolUpdates.add(update);

  @override
  Future<RefundOrderResult> refundOrder(String orderId, String reason) async {
    refunds.add((orderId: orderId, reason: reason));
    return refundResult;
  }

  @override
  Future<void> updateWebPricing(Map<String, WebProductConfig> products) async =>
      webPricing.add(webPricingPayload(products));
}

PagedListNotifier<T> _paged<T>(List<T> items) =>
    PagedListNotifier<T>((after) async => AdminPage<T>(items, null, false));

PagedListNotifier<T> _failing<T>(Object error) => PagedListNotifier<T>((after) async => throw error);

final _blueprint = BlueprintSpec.fromJson({
  'id': 'ort_main_2026',
  'kind': 'main',
  'status': 'active',
  'title': {'ru': 'Основной тест ОРТ', 'ky': 'ЖРТнын негизги тести'},
  'languages': ['ru', 'ky'],
  'sections': [
    {
      'id': 'math',
      'order': 1,
      'title': {'ru': 'Математика', 'ky': 'Математика'},
      'question_count': 60,
      'parts': [
        {'id': 'p1', 'title': {'ru': 'Сравнение величин', 'ky': 'Чоңдуктарды салыштыруу'}, 'question_count': 30},
        {'id': 'p2', 'title': {'ru': 'Задачи', 'ky': 'Маселелер'}, 'question_count': 30},
      ],
    },
    {
      'id': 'reading',
      'order': 3,
      'title': {'ru': 'Чтение и понимание', 'ky': 'Окуу жана түшүнүү'},
      'question_count': 30,
      'parts': [
        {'id': 'p1', 'question_count': 30, 'item_type': 'text_based'},
      ],
    },
  ],
});

final _now = DateTime.now();

final _orders = [
  PaymentOrder(
    id: 'ord_paid_1',
    uid: 'student-uid-0123456789abcdef',
    productId: 'exam_single',
    credits: 1,
    amountSom: 100,
    provider: 'sandbox',
    status: 'paid',
    providerRef: 'sbx_ref_0123456789',
    granted: true,
    createdAt: _now.subtract(const Duration(hours: 2)),
    paidAt: _now.subtract(const Duration(hours: 2)),
    updatedAt: _now.subtract(const Duration(hours: 2)),
  ),
  PaymentOrder(
    id: 'ord_refunded',
    uid: 'student-2',
    productId: 'exam_pack_10',
    credits: 10,
    amountSom: 800,
    provider: 'sandbox',
    status: 'refunded',
    granted: true,
    createdAt: _now.subtract(const Duration(days: 2)),
    paidAt: _now.subtract(const Duration(days: 2)),
    refund: OrderRefund(at: _now.subtract(const Duration(days: 1)), source: 'admin', creditsClawedBack: 4, debtAdded: 6),
  ),
  PaymentOrder(
    id: 'ord_pending',
    uid: 'student-3',
    productId: 'exam_pack_5',
    credits: 5,
    amountSom: 450,
    provider: 'sandbox',
    status: 'pending',
    createdAt: _now.subtract(const Duration(minutes: 5)),
    expiresAt: _now.add(const Duration(hours: 23)),
  ),
];

List<Override> _base(
  AdminRole role, {
  _FakeAdminFunctions? functions,
  ExamPoolConfig pool = const ExamPoolConfig(freshEnabled: true, minReviewStatus: MinReviewStatus.methodologistApproved),
  PoolHealth? health,
  PagedListNotifier<PaymentOrder> Function()? orders,
  RevenueSummary? revenue,
  PricingConfig pricing = PricingConfig.defaults,
}) =>
    [
      adminSessionProvider.overrideWith(() => _TestSession(role)),
      adminFunctionsServiceProvider.overrideWithValue(functions ?? _FakeAdminFunctions()),
      adminBlueprintsProvider.overrideWith((ref) async => [_blueprint]),
      examPoolConfigProvider.overrideWith((ref) async => pool),
      examPoolHealthProvider.overrideWith((ref, k) async => health ?? PoolHealth.fromMap(healthResponse())),
      paymentOrdersPageProvider.overrideWith((ref, status) =>
          orders?.call() ?? _paged(status == null ? _orders : _orders.where((o) => o.status == status).toList())),
      purchasesPageProvider.overrideWith((ref, state) => _paged(const <PurchaseRecord>[])),
      revenueProvider.overrideWith((ref) async =>
          revenue ?? RevenueSummary.compute(_orders, now: _now)),
      pricingProvider.overrideWith((ref) async => pricing),
    ];

// --- Harness ----------------------------------------------------------------

ThemeData _theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.blue600, brightness: b),
      extensions: [b == Brightness.dark ? AppTokens.dark : AppTokens.light],
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
  String locale = 'ru',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Scrolls the page body (the vertical list of [AdminPageBody], never a tab
/// bar or a TabBarView) until [f] is visible.
Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  final scrollable = find
      .descendant(of: find.byType(AdminPageBody).first, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(f, 300, scrollable: scrollable);
  await tester.pumpAndSettle();
}

/// Scrolls to «Проверить пул» (below the settings card on a phone) and taps it.
Future<void> _checkPool(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('pool_check'));
  await _scrollTo(tester, button);
  await _tap(tester, button);
}

Widget _shell(AdminSection s, Widget page) => AdminShell(location: s.path, child: AdminGate(section: s, child: page));

void main() {
  group('navigation', () {
    testWidgets('the pool entry is in the methodologist sidebar', (tester) async {
      await _pump(tester, const AdminShell(location: '/admin/dashboard', child: SizedBox()),
          size: const Size(1280, 1400), overrides: _base(AdminRole.methodologist));
      expect(find.text('Пул заданий'), findsOneWidget);
      expect(find.text('Платежи'), findsNothing);
    });

    testWidgets('support sees payments but not the pool', (tester) async {
      await _pump(tester, const AdminShell(location: '/admin/dashboard', child: SizedBox()),
          size: const Size(1280, 1400), overrides: _base(AdminRole.support));
      expect(find.text('Пул заданий'), findsNothing);
      expect(find.text('Платежи'), findsOneWidget);
    });

    testWidgets('support opening the pool gets the no-access view', (tester) async {
      await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()), overrides: _base(AdminRole.support));
      expect(find.text('Нет доступа'), findsOneWidget);
      expect(find.byKey(const ValueKey('pool_check')), findsNothing);
    });
  });

  group('exam pool page at 360dp', () {
    for (final b in Brightness.values) {
      for (final locale in ['ru', 'ky']) {
        testWidgets('super admin, report (${b.name}, $locale)', (tester) async {
          await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()),
              brightness: b, locale: locale, overrides: _base(AdminRole.superAdmin));
          expect(find.byKey(const ValueKey('pool_fresh_switch')), findsOneWidget);
          await _checkPool(tester);
          await _scrollTo(tester, find.byKey(const ValueKey('pool_summary')));
          expect(find.text(locale == 'ru' ? 'Полностью разных вариантов: 0' : 'Толугу менен башка варианттар: 0'),
              findsOneWidget);
          await _scrollTo(tester, find.text('math.algebra'));
          expect(find.text('math.geometry'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('section and part titles come from the blueprint', (tester) async {
      await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()), overrides: _base(AdminRole.contentManager));
      await _checkPool(tester);
      await _scrollTo(tester, find.text('Задачи'));
      expect(find.text('не хватает на вариант'), findsWidgets);
      expect(find.text('Нужно в варианте: 30 · в пуле: 18 · не хватает: 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('methodologist sees the settings read-only', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()),
          overrides: _base(AdminRole.methodologist, functions: fn));
      expect(find.textContaining('может только супер-админ'), findsOneWidget);
      final sw = tester.widget<SwitchListTile>(find.byKey(const ValueKey('pool_fresh_switch')));
      expect(sw.onChanged, isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('pool_status_ai_verified')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pool_status_ai_verified')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fn.poolUpdates, isEmpty);
    });

    testWidgets('ai_verified needs the warning to be acknowledged', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      await _tap(tester, find.byKey(const ValueKey('pool_status_ai_verified')));
      expect(find.textContaining('проверено независимым AI-решателем, но не методистом'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('pool_ai_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await _tap(tester, find.byKey(const ValueKey('pool_ai_ack')));
      await _tap(tester, confirm);
      expect(fn.poolUpdates, [
        {'minReviewStatus': 'ai_verified'},
      ]);
      expect(find.text('Настройки пула сохранены'), findsOneWidget);
    });

    testWidgets('turning fresh variants off is confirmed and sent alone', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      await _tap(tester, find.byKey(const ValueKey('pool_fresh_switch')));
      expect(find.text('Выключить новые варианты?'), findsOneWidget);
      await _tap(tester, find.text('Применить'));
      expect(fn.poolUpdates, [
        {'freshEnabled': false},
      ]);
    });

    testWidgets('an active ai_verified floor is flagged', (tester) async {
      await _pump(tester, _shell(AdminSection.examPool, const ExamPoolPage()),
          brightness: Brightness.dark,
          overrides: _base(AdminRole.contentManager,
              pool: const ExamPoolConfig(freshEnabled: false, minReviewStatus: MinReviewStatus.aiVerified)));
      await _scrollTo(tester, find.byKey(const ValueKey('pool_ai_active')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a role refused by the callable gets a calm no-access text', (tester) async {
      await _pump(
        tester,
        _shell(AdminSection.examPool, const ExamPoolPage()),
        overrides: [
          ..._base(AdminRole.methodologist),
          examPoolHealthProvider.overrideWith((ref, k) async => throw FirebaseFunctionsException(
              code: 'permission-denied', message: 'm', details: const {'reason': 'FORBIDDEN_ROLE'})),
        ],
      );
      await _checkPool(tester);
      await _scrollTo(tester, find.textContaining('Отчёт о пуле доступен'));
      expect(tester.takeException(), isNull);
    });
  });

  group('payments: website orders and revenue', () {
    for (final b in Brightness.values) {
      for (final locale in ['ru', 'ky']) {
        testWidgets('support reads orders and revenue (${b.name}, $locale)', (tester) async {
          await _pump(tester, _shell(AdminSection.payments, const PaymentsPage()),
              brightness: b, locale: locale, overrides: _base(AdminRole.support));
          expect(find.byKey(const ValueKey('order_ord_paid_1')), findsOneWidget);
          await _tap(tester, find.byKey(const ValueKey('order_ord_paid_1')));
          expect(find.text('sbx_ref_0123456789'), findsOneWidget);
          expect(find.byKey(const ValueKey('order_refund')), findsNothing);
          expect(find.byKey(const ValueKey('order_open_user')), findsOneWidget);
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          await _tap(tester, find.text(locale == 'ru' ? 'Выручка' : 'Киреше'));
          expect(find.byKey(const ValueKey('revenue_total')), findsOneWidget);
          expect(find.text(locale == 'ru' ? '100 сом' : '100 сом'), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a refunded order shows the clawback and the debt', (tester) async {
      await _pump(tester, _shell(AdminSection.payments, const PaymentsPage()), overrides: _base(AdminRole.superAdmin));
      await _tap(tester, find.byKey(const ValueKey('order_ord_refunded')));
      expect(find.textContaining('отозвано кредитов: 4'), findsOneWidget);
      expect(find.textContaining('долг: 6'), findsOneWidget);
      expect(find.byKey(const ValueKey('order_refund')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('super admin refunds a paid order with a reason', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.payments, const PaymentsPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      await _tap(tester, find.byKey(const ValueKey('order_ord_paid_1')));
      await _tap(tester, find.byKey(const ValueKey('order_refund')));
      expect(find.text('Вернуть платёж?'), findsOneWidget);
      expect(find.textContaining('Провайдер вернёт пользователю 100 сом'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('refund_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('refund_reason')), '  ab ');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('refund_reason')), '  Двойная оплата  ');
      await tester.pump();
      await _tap(tester, confirm);
      expect(fn.refunds, [(orderId: 'ord_paid_1', reason: 'Двойная оплата')]);
      expect(find.text('Платёж возвращён. Отозвано кредитов: 1.'), findsOneWidget);
    });

    testWidgets('a provider that confirms later is reported as pending', (tester) async {
      final fn = _FakeAdminFunctions()..refundResult = const RefundOrderResult(status: 'pending');
      await _pump(tester, _shell(AdminSection.payments, const PaymentsPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      await _tap(tester, find.byKey(const ValueKey('order_ord_paid_1')));
      await _tap(tester, find.byKey(const ValueKey('order_refund')));
      await tester.enterText(find.byKey(const ValueKey('refund_reason')), 'Ошибка оплаты');
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('refund_confirm')));
      expect(find.textContaining('Возврат запрошен у провайдера'), findsOneWidget);
    });

    testWidgets('status filter lists only matching orders', (tester) async {
      await _pump(tester, _shell(AdminSection.payments, const PaymentsPage()), overrides: _base(AdminRole.support));
      await _tap(tester, find.byKey(const ValueKey('orders_status')));
      await _tap(tester, find.text('Ожидает оплаты').last);
      expect(find.byKey(const ValueKey('order_ord_pending')), findsOneWidget);
      expect(find.byKey(const ValueKey('order_ord_paid_1')), findsNothing);
    });

    testWidgets('rules that refuse payment_orders give a no-access state', (tester) async {
      await _pump(
        tester,
        _shell(AdminSection.payments, const PaymentsPage()),
        overrides: _base(AdminRole.support,
            orders: () => _failing<PaymentOrder>(
                FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: 'denied'))),
      );
      expect(find.textContaining('Нет доступа к заказам на сайте'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('revenue with no payments says so', (tester) async {
      await _pump(tester, _shell(AdminSection.payments, const PaymentsPage()),
          brightness: Brightness.dark,
          overrides: _base(AdminRole.support, revenue: RevenueSummary.compute(const [], now: _now)));
      await _tap(tester, find.text('Выручка'));
      expect(find.text('0 сом'), findsWidgets);
      expect(find.textContaining('оплат на сайте не было'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('pricing: website products', () {
    for (final b in Brightness.values) {
      for (final locale in ['ru', 'ky']) {
        testWidgets('web products editor fits 360dp (${b.name}, $locale)', (tester) async {
          await _pump(tester, _shell(AdminSection.pricing, const PricingPage()),
              brightness: b, locale: locale, overrides: _base(AdminRole.superAdmin));
          expect(find.byKey(const ValueKey('web_product_exam_single')), findsOneWidget);
          await _scrollTo(tester, find.byKey(const ValueKey('web_pricing_save')));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('enabling a pack keeps the base price and sends the whole map', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.pricing, const PricingPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      await _scrollTo(tester, find.byKey(const ValueKey('web_enabled_exam_pack_5')));
      await _tap(tester, find.byKey(const ValueKey('web_enabled_exam_pack_5')));
      await _tap(tester, find.byKey(const ValueKey('web_pricing_save')));
      expect(find.text('Сохранить цены на сайте?'), findsOneWidget);
      await _tap(tester, find.text('Сохранить').last);
      expect(fn.webPricing, [
        {
          'webProducts': {
            'exam_single': {'credits': 1, 'amount_som': 100, 'enabled': true},
            'exam_pack_5': {'credits': 5, 'amount_som': 450, 'enabled': true},
            'exam_pack_10': {'credits': 10, 'amount_som': 800, 'enabled': false},
          },
        },
      ]);
    });

    testWidgets('changing exam_single away from 100 som needs the typed price', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.pricing, const PricingPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      final credits = tester.widget<TextField>(find.byKey(const ValueKey('web_credits_exam_single')));
      expect(credits.enabled, isFalse, reason: '1 credit = 1 exam is fixed');
      await tester.enterText(find.byKey(const ValueKey('web_amount_exam_single')), '150');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web_base_changed')), findsOneWidget);
      expect(find.textContaining('Базовая цена согласуется с владельцем'), findsWidgets);
      await _scrollTo(tester, find.byKey(const ValueKey('web_pricing_save')));
      await _tap(tester, find.byKey(const ValueKey('web_pricing_save')));
      expect(find.text('Изменить базовую цену?'), findsOneWidget);
      final apply = find.byKey(const ValueKey('base_price_confirm_button'));
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('base_price_confirm')), '100');
      await tester.pump();
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('base_price_confirm')), '150');
      await tester.pump();
      await _tap(tester, apply);
      expect(fn.webPricing.single['confirmBasePriceChange'], isTrue);
      expect((fn.webPricing.single['webProducts'] as Map)['exam_single'], {'credits': 1, 'amount_som': 150, 'enabled': true});
    });

    testWidgets('invalid amounts are refused before any call', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(tester, _shell(AdminSection.pricing, const PricingPage()),
          overrides: _base(AdminRole.superAdmin, functions: fn));
      await tester.enterText(find.byKey(const ValueKey('web_amount_exam_single')), '0');
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const ValueKey('web_pricing_save')));
      await _tap(tester, find.byKey(const ValueKey('web_pricing_save')));
      expect(find.text('Цена — от 1 до 100000 сом.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fn.webPricing, isEmpty);
    });

    testWidgets('the Google Play tab keeps the credits editor', (tester) async {
      await _pump(tester, _shell(AdminSection.pricing, const PricingPage()), overrides: _base(AdminRole.superAdmin));
      await _tap(tester, find.text('Google Play'));
      expect(find.textContaining('Google Play Console'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
