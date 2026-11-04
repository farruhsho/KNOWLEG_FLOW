import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/admin/admin_routes.dart';
import 'package:knowledge_flow/features/admin/application/admin_providers.dart';
import 'package:knowledge_flow/features/admin/application/paged_list.dart';
import 'package:knowledge_flow/features/admin/data/admin_firebase.dart';
import 'package:knowledge_flow/features/admin/data/admin_functions.dart';
import 'package:knowledge_flow/features/admin/data/models/admin_records.dart';
import 'package:knowledge_flow/features/admin/data/repositories/growth_repositories.dart';
import 'package:knowledge_flow/features/admin/domain/achievements_config.dart';
import 'package:knowledge_flow/features/admin/domain/admin_nav.dart';
import 'package:knowledge_flow/features/admin/domain/admin_role.dart';
import 'package:knowledge_flow/features/admin/domain/notification_draft.dart';
import 'package:knowledge_flow/features/admin/domain/promo_code.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/admin_achievements_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/admin_notifications_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/promo_codes_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/users_page.dart';
import 'package:knowledge_flow/features/admin/presentation/shell/admin_shell.dart';
import 'package:knowledge_flow/features/onboarding/data/kg_regions_provider.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/providers/admin_access_provider.dart';
import 'package:knowledge_flow/shared/models/region_model.dart';

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

  final notificationCalls = <Map<String, dynamic>>[];
  final promoCalls = <Map<String, dynamic>>[];
  Object? error;

  /// Thrown only by real (non dry-run) sends.
  Object? sendError;
  int recipients = 42;

  @override
  Future<NotificationSendResult> sendNotification(NotificationDraft draft, {required bool dryRun}) async {
    notificationCalls.add(draft.toCallable(dryRun: dryRun));
    if (error != null) throw error!;
    if (!dryRun && sendError != null) throw sendError!;
    return NotificationSendResult(
      recipients: recipients,
      sent: dryRun ? 0 : recipients - 1,
      failed: dryRun ? 0 : 1,
      notificationId: dryRun ? null : 'n1',
    );
  }

  @override
  Future<void> upsertPromoCode(PromoCodeDraft draft) async => promoCalls.add(draft.toCallable());
}

class _FakeAchievementsRepo implements AchievementsConfigRepository {
  final saved = <Map<String, dynamic>>[];

  @override
  Future<AchievementsConfig> load() async => AchievementsConfig.empty;

  @override
  Future<void> save(AchievementsConfig config) async => saved.add(config.toFirestore());
}

PagedListNotifier<T> _paged<T>(List<T> items) =>
    PagedListNotifier<T>((after) async => AdminPage<T>(items, null, false));

final _regions = [
  const RegionData(
    id: 'chuy',
    oblast: 'Чуйская область',
    title: {'ru': 'Чуйская область', 'ky': 'Чүй облусу'},
    districts: [],
  ),
  const RegionData(
    id: 'naryn',
    oblast: 'Нарынская область',
    title: {'ru': 'Нарынская область', 'ky': 'Нарын облусу'},
    districts: [],
  ),
];

// --- Harness ----------------------------------------------------------------

ThemeData _theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.blue600, brightness: b),
      extensions: [b == Brightness.dark ? AppTokens.dark : AppTokens.light],
    );

List<Override> _base(
  AdminRole role, {
  _FakeAdminFunctions? functions,
  List<NotificationRecord> history = const [],
  List<PromoCodeRecord> promos = const [],
  AchievementsConfig achievements = AchievementsConfig.empty,
  _FakeAchievementsRepo? achievementsRepo,
}) =>
    [
      adminSessionProvider.overrideWith(() => _TestSession(role)),
      adminFunctionsServiceProvider.overrideWithValue(functions ?? _FakeAdminFunctions()),
      notificationsPageProvider.overrideWith((ref) => _paged(history)),
      promoCodesPageProvider.overrideWith((ref) => _paged(promos)),
      achievementsConfigProvider.overrideWith((ref) async => achievements),
      achievementsConfigRepoProvider.overrideWithValue(achievementsRepo ?? _FakeAchievementsRepo()),
      kgRegionsProvider.overrideWith((ref) async => _regions),
    ];

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

Finder _field(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.enterText(_field(key), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

List<String> _paths(List<RouteBase> routes) => [
      for (final r in routes) ...[
        if (r is GoRoute) r.path,
        ..._paths(r.routes),
      ],
    ];

void main() {
  group('phase 3 navigation (§2 matrix)', () {
    const phase3 = [AdminSection.notifications, AdminSection.promoCodes, AdminSection.achievements];

    test('paths are the RoutePaths constants and are routed', () {
      expect(AdminSection.notifications.path, RoutePaths.adminNotifications);
      expect(AdminSection.promoCodes.path, RoutePaths.adminPromoCodes);
      expect(AdminSection.achievements.path, RoutePaths.adminAchievements);
      final routed = _paths(adminRoutes).toSet();
      expect(routed, containsAll(
          [RoutePaths.adminNotifications, RoutePaths.adminPromoCodes, RoutePaths.adminAchievements]));
      for (final s in phase3) {
        expect(s.path.startsWith('/admin/'), isTrue);
        expect(AdminSection.forPath(s.path), s);
      }
    });

    test('visibility per role', () {
      Set<AdminSection> visible(AdminRole r) =>
          AdminSection.visibleSections(r).where(phase3.contains).toSet();
      expect(visible(AdminRole.superAdmin), phase3.toSet());
      // send_notifications + manage_achievements, but no grant_credits.
      expect(visible(AdminRole.contentManager), {AdminSection.notifications, AdminSection.achievements});
      expect(visible(AdminRole.methodologist), isEmpty);
      expect(visible(AdminRole.moderator), isEmpty);
      expect(visible(AdminRole.support), isEmpty);
    });

    test('each entry follows exactly its permission', () {
      for (final r in AdminRole.values) {
        expect(AdminSection.notifications.visibleTo(r), r.can(AdminPermission.sendNotifications), reason: r.wire);
        expect(AdminSection.promoCodes.visibleTo(r), r.can(AdminPermission.grantCredits), reason: r.wire);
        expect(AdminSection.achievements.visibleTo(r), r.can(AdminPermission.manageAchievements), reason: r.wire);
      }
    });

    final labels = {'Рассылки', 'Промокоды', 'Достижения'};
    final expected = <AdminRole, Set<String>>{
      AdminRole.superAdmin: labels,
      AdminRole.contentManager: {'Рассылки', 'Достижения'},
      AdminRole.methodologist: {},
      AdminRole.moderator: {},
      AdminRole.support: {},
    };
    for (final e in expected.entries) {
      testWidgets('sidebar for ${e.key.wire}', (tester) async {
        await _pump(
          tester,
          const AdminShell(location: '/admin/dashboard', child: SizedBox()),
          size: const Size(1280, 1400),
          overrides: _base(e.key),
        );
        for (final label in labels) {
          expect(find.text(label), e.value.contains(label) ? findsOneWidget : findsNothing,
              reason: '${e.key.wire}: $label');
        }
      });
    }

    testWidgets('phone drawer of a content manager', (tester) async {
      await _pump(
        tester,
        const AdminShell(location: '/admin/notifications', child: SizedBox()),
        size: const Size(360, 900),
        overrides: _base(AdminRole.contentManager),
      );
      expect(find.text('Рассылки'), findsOneWidget); // app bar title
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Достижения'), findsOneWidget);
      expect(find.text('Промокоды'), findsNothing);
    });

    testWidgets('a content manager opening promo codes gets the no-access view', (tester) async {
      await _pump(
        tester,
        const AdminShell(
          location: '/admin/promo-codes',
          child: AdminGate(section: AdminSection.promoCodes, child: PromoCodesPage()),
        ),
        overrides: _base(AdminRole.contentManager),
      );
      expect(find.text('Нет доступа'), findsOneWidget);
      expect(find.byKey(const ValueKey('promo_create')), findsNothing);
    });
  });

  group('layouts at 360dp (light and dark)', () {
    final now = DateTime.now();
    for (final b in Brightness.values) {
      testWidgets('notifications composer and history (${b.name})', (tester) async {
        await _pump(
          tester,
          const AdminShell(location: '/admin/notifications', child: AdminNotificationsPage()),
          brightness: b,
          overrides: _base(AdminRole.superAdmin, history: [
            NotificationRecord(
              id: 'n1',
              title: const {'ru': 'Новый пробный экзамен по математике уже доступен в приложении', 'ky': 'Жаңы'},
              body: const {'ru': 'Текст', 'ky': 'Текст'},
              audience: const NotificationAudience(NotificationAudienceKind.region, 'Чуйская область'),
              recipients: 1200,
              sent: 1180,
              failed: 20,
              createdBy: 'admin-uid-0123456789',
              createdAt: now,
            ),
          ]),
        );
        expect(find.text('Новая рассылка'), findsOneWidget);
        await tester.tap(find.text('История'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Регион: Чуйская область'), findsOneWidget);
        expect(find.text('ошибок: 20'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('promo codes list and editor (${b.name})', (tester) async {
        await _pump(
          tester,
          const AdminShell(location: '/admin/promo-codes', child: PromoCodesPage()),
          brightness: b,
          overrides: _base(AdminRole.superAdmin, promos: [
            PromoCodeRecord(
              code: 'SCHOOL2026ABCDEFGHIJ',
              credits: 10,
              maxRedemptions: 100000,
              redemptions: 99999,
              expiresAt: now.add(const Duration(days: 30)),
              active: true,
              note: 'Партнёрская кампания с длинным описанием для школ Чуйской области',
            ),
            const PromoCodeRecord(code: 'OLD1', credits: 1, active: false),
          ]),
        );
        expect(find.textContaining('финансовая операция'), findsOneWidget);
        expect(find.text('Активен'), findsOneWidget);
        expect(find.text('Отключён'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('promo_create')));
        await tester.pumpAndSettle();
        expect(find.text('Новый промокод'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('achievements editor (${b.name})', (tester) async {
        await _pump(
          tester,
          const AdminShell(location: '/admin/achievements', child: AdminAchievementsPage()),
          brightness: b,
          overrides: _base(AdminRole.contentManager),
        );
        expect(find.textContaining('Пороги и правила выдачи остаются на сервере'), findsOneWidget);
        expect(find.byKey(const ValueKey('ach_first_lesson')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('whole composer and achievements editor are 360dp wide without overflow (${b.name})',
          (tester) async {
        await _pump(
          tester,
          const AdminShell(location: '/admin/notifications', child: AdminNotificationsPage()),
          brightness: b,
          size: const Size(360, 1600),
          overrides: _base(AdminRole.superAdmin),
          locale: 'ky',
        );
        // Every audience variant, with the longest (Kyrgyz) labels.
        for (final kind in ['Тил боюнча', 'Аймак боюнча', 'Топ']) {
          await _tap(tester, find.widgetWithText(ChoiceChip, kind));
        }
        await _tap(tester, find.byKey(const ValueKey('notif_check')));
        expect(find.text('Алуучулар: 42'), findsNothing); // group id still empty → validation
        expect(tester.takeException(), isNull);

        await _pump(
          tester,
          const AdminShell(location: '/admin/achievements', child: AdminAchievementsPage()),
          brightness: b,
          size: const Size(360, 9000),
          overrides: _base(AdminRole.superAdmin,
              achievements: const AchievementsConfig(disabled: {'reader', 'exam_champion'})),
          locale: 'ky',
        );
        expect(find.byKey(const ValueKey('ach_exam_champion')), findsOneWidget);
        expect(find.text('Өчүрүлгөн'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('user detail growth card (${b.name})', (tester) async {
        await _pump(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              child: UserGrowthCard(
                user: AdminUserRecord(
                  uid: 'u1',
                  name: '',
                  email: '',
                  referralCode: 'ABC234',
                  referredBy: 'inviter-uid-with-a-long-identifier-0001',
                  groupIds: ['g1', 'g2', 'g3'],
                ),
              ),
            ),
          ),
          brightness: b,
          overrides: [
            ..._base(AdminRole.support),
            adminReferralsCountProvider.overrideWith((ref, uid) async => 7),
            adminGroupNameProvider.overrideWith((ref, gid) async => switch (gid) {
                  'g1' => '11-А класс, школа-гимназия №5 имени Чингиза Айтматова',
                  'g2' => '',
                  _ => null,
                }),
          ],
        );
        expect(find.text('ABC234'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('Группы (3)'), findsOneWidget);
        expect(find.textContaining('школа-гимназия'), findsOneWidget);
        expect(find.text('g2'), findsOneWidget);
        expect(find.text('Группа не найдена (удалена?)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Kyrgyz CMS strings are real Kyrgyz', (tester) async {
      await _pump(
        tester,
        const AdminShell(location: '/admin/notifications', child: AdminNotificationsPage()),
        size: const Size(360, 1600),
        overrides: _base(AdminRole.superAdmin),
        locale: 'ky',
      );
      expect(find.text('Билдирүүлөр'), findsOneWidget);
      expect(find.text('Камтууну текшерүү'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('notification composer flow', () {
    Future<_FakeAdminFunctions> fill(WidgetTester tester, {Object? error}) async {
      final fn = _FakeAdminFunctions()..error = error;
      await _pump(
        tester,
        const Scaffold(body: AdminNotificationsPage()),
        size: const Size(360, 1600),
        overrides: _base(AdminRole.contentManager, functions: fn),
      );
      await _type(tester, 'notif_title_ru', 'Новый вариант');
      await _type(tester, 'notif_body_ru', 'Пробный экзамен уже доступен.');
      await _type(tester, 'notif_title_ky', 'Жаңы вариант');
      await _type(tester, 'notif_body_ky', 'Сынамык экзамен даяр.');
      return fn;
    }

    // FilledButton.icon builds a FilledButton subclass: look it up by key.
    FilledButton sendButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('notif_send')));

    testWidgets('validation blocks the reach check until both languages are filled', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(
        tester,
        const Scaffold(body: AdminNotificationsPage()),
        size: const Size(360, 1600),
        overrides: _base(AdminRole.contentManager, functions: fn),
      );
      await _type(tester, 'notif_title_ru', 'Только по-русски');
      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      expect(fn.notificationCalls, isEmpty);
      expect(find.text('Заполните тексты на обоих языках и выберите аудиторию.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('notif_title_ky')));
      await tester.pumpAndSettle();
      expect(find.text('Обязательное поле'), findsWidgets);
    });

    testWidgets('reach check, stale check, confirmed send', (tester) async {
      final fn = await fill(tester);
      expect(sendButton(tester).onPressed, isNull, reason: 'no reach check yet');

      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      expect(fn.notificationCalls.single['dryRun'], isTrue);
      expect(fn.notificationCalls.single['audience'], {'kind': 'all'});
      expect(find.text('Получателей: 42'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);

      // Any change invalidates the check.
      await _type(tester, 'notif_body_ky', 'Сынамык экзамен даяр!');
      expect(find.text('Текст или аудитория изменились — проверьте охват ещё раз.'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);

      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      await _tap(tester, find.byKey(const ValueKey('notif_send')));
      expect(find.text('Отправить рассылку?'), findsOneWidget);
      expect(find.textContaining('42'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Отправить').last);
      await tester.pumpAndSettle();

      expect(fn.notificationCalls.length, 3);
      final sent = fn.notificationCalls.last;
      expect(sent['dryRun'], isFalse);
      expect(sent['body'], {'ru': 'Пробный экзамен уже доступен.', 'ky': 'Сынамык экзамен даяр!'});
      await tester.ensureVisible(find.textContaining('отправлено: 41'));
      expect(find.textContaining('отправлено: 41'), findsOneWidget);
      // The finished broadcast cannot be sent twice without a new check.
      expect(sendButton(tester).onPressed, isNull);
    });

    testWidgets('a failed send (e.g. timeout) needs a new reach check before retrying', (tester) async {
      final fn = await fill(tester);
      fn.sendError = FirebaseFunctionsException(code: 'deadline-exceeded', message: 'timeout');
      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      await _tap(tester, find.byKey(const ValueKey('notif_send')));
      await tester.tap(find.widgetWithText(FilledButton, 'Отправить').last);
      await tester.pumpAndSettle();
      expect(fn.notificationCalls.where((c) => c['dryRun'] == false), hasLength(1));
      expect(sendButton(tester).onPressed, isNull);
      expect(find.text('Проверьте охват, чтобы узнать, сколько человек получат уведомление.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      final fn = await fill(tester);
      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      await _tap(tester, find.byKey(const ValueKey('notif_send')));
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(fn.notificationCalls.where((c) => c['dryRun'] == false), isEmpty);
    });

    testWidgets('region audience sends the canonical oblast', (tester) async {
      final fn = await fill(tester);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'По региону'));
      await _tap(tester, find.byType(DropdownButtonFormField<String?>));
      await tester.tap(find.text('Нарынская область').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      expect(fn.notificationCalls.single['audience'], {'kind': 'region', 'value': 'Нарынская область'});
    });

    testWidgets('the daily limit is explained clearly', (tester) async {
      final fn = await fill(
        tester,
        error: FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'limit',
          details: {'reason': 'LIMIT_REACHED'},
        ),
      );
      await _tap(tester, find.byKey(const ValueKey('notif_check')));
      expect(fn.notificationCalls, hasLength(1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Лимит рассылок на сегодня исчерпан').first);
      expect(find.textContaining('Лимит рассылок на сегодня исчерпан (3 в сутки)'), findsWidgets);
    });
  });

  group('promo code editor', () {
    testWidgets('rejects a bad code, then creates a valid one after confirmation', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(
        tester,
        const Scaffold(body: PromoCodesPage()),
        size: const Size(400, 900),
        overrides: _base(AdminRole.superAdmin, functions: fn),
      );
      await tester.tap(find.byKey(const ValueKey('promo_create')));
      await tester.pumpAndSettle();
      final code = find.descendant(
          of: find.byKey(const ValueKey('promo_code_field')), matching: find.byType(EditableText));
      await tester.enterText(find.byKey(const ValueKey('promo_code_field')), 'ab-1');
      await tester.pump();
      // Filtered and upper-cased while typing.
      expect(tester.widget<EditableText>(code).controller.text, 'AB1');
      await _tap(tester, find.byKey(const ValueKey('promo_submit')));
      expect(find.text('4–20 символов: только A–Z и 0–9'), findsOneWidget);
      expect(fn.promoCalls, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('promo_code_field')), 'school5');
      await tester.enterText(find.byKey(const ValueKey('promo_max_field')), '50');
      await _tap(tester, find.byKey(const ValueKey('promo_submit')));
      expect(find.text('Создать промокод?'), findsOneWidget);
      expect(find.textContaining('SCHOOL5'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(fn.promoCalls.single, {
        'code': 'SCHOOL5',
        'credits': 1,
        'maxRedemptions': 50,
        'active': true,
        'note': '',
      });
    });

    testWidgets('deactivate keeps the other fields', (tester) async {
      final fn = _FakeAdminFunctions();
      await _pump(
        tester,
        const Scaffold(body: PromoCodesPage()),
        overrides: _base(AdminRole.superAdmin, functions: fn, promos: const [
          PromoCodeRecord(code: 'ORT2026', credits: 3, maxRedemptions: 10, redemptions: 4, active: true, note: 'n'),
        ]),
      );
      await tester.tap(find.byTooltip('Отключить'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Отключить'));
      await tester.pumpAndSettle();
      expect(fn.promoCalls.single,
          {'code': 'ORT2026', 'credits': 3, 'maxRedemptions': 10, 'active': false, 'note': 'n'});
      expect(find.text('Отключён'), findsOneWidget);
    });
  });

  group('achievements editor', () {
    testWidgets('toggle and texts are saved with only the allowed keys', (tester) async {
      final repo = _FakeAchievementsRepo();
      await _pump(
        tester,
        const Scaffold(body: AdminAchievementsPage()),
        // Tall enough that the lazy list builds every card.
        size: const Size(400, 7000),
        overrides: _base(
          AdminRole.contentManager,
          achievementsRepo: repo,
          achievements: AchievementsConfig.fromMap(const {
            'titles': {
              'reader': {'ru': 'Книжный червь', 'ky': 'Китеп сүйүүчү'},
            },
          }),
        ),
      );
      // Existing override is shown in the preview.
      await tester.ensureVisible(find.byKey(const ValueKey('ach_reader')));
      await tester.pumpAndSettle();
      expect(find.text('Книжный червь'), findsWidgets);

      await _tap(tester, find.byKey(const ValueKey('ach_switch_streak_7')));
      await _type(tester, 'ach_xp_100_title_ru', 'Сотня');
      await _tap(tester, find.byKey(const ValueKey('ach_save')));
      // Only one language: blocked.
      expect(repo.saved, isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('ach_xp_100_title_ky')));
      await tester.pumpAndSettle();
      expect(find.text('Заполните оба языка или оставьте оба пустыми'), findsOneWidget);

      await _type(tester, 'ach_xp_100_title_ky', 'Жүздүк');
      await _tap(tester, find.byKey(const ValueKey('ach_save')));
      expect(repo.saved.single, {
        'titles': {
          'xp_100': {'ru': 'Сотня', 'ky': 'Жүздүк'},
          'reader': {'ru': 'Книжный червь', 'ky': 'Китеп сүйүүчү'},
        },
        'descriptions': <String, Object>{},
        'disabled': ['streak_7'],
      });
      expect(repo.saved.single.keys.toSet(), kAchievementsConfigKeys);
    });
  });

  test('paged list keeps its item type: first page, load more, refresh', () async {
    final pages = [
      ['a', 'b'],
      ['c'],
    ];
    var calls = 0;
    final n = PagedListNotifier<String>((after) async {
      final i = calls++ % 2;
      return AdminPage<String>(pages[i], null, i == 0);
    });
    await Future<void>.delayed(Duration.zero);
    // Regression: a const PagedState() was PagedState<Never> and the first
    // non-empty page threw a TypeError in every admin list.
    expect(n.state.error, isNull);
    expect(n.state.items, ['a', 'b']);
    expect(n.state.hasMore, isTrue);
    await n.loadMore();
    expect(n.state.items, ['a', 'b', 'c']);
    expect(n.state.hasMore, isFalse);
    await n.refresh();
    expect(n.state.error, isNull);
    expect(n.state.items, ['a', 'b']);
    n.replaceWhere((x) => x == 'a', (_) => 'A');
    expect(n.state.items, ['A', 'b']);
    n.dispose();
  });

  test('users/{uid} phase-3 fields are read from the snake_case document', () {
    final u = AdminUserRecord.fromMap('u9', {
      'email': 'a@b.kg',
      'referral_code': 'XY23ZQ',
      'referred_by': 'u1',
      'group_ids': ['g1', ' g2 ', 'g1', 3, ''],
    });
    expect(u.referralCode, 'XY23ZQ');
    expect(u.referredBy, 'u1');
    expect(u.groupIds, ['g1', 'g2']);
    final empty = AdminUserRecord.fromMap('u10', const {});
    expect([empty.referralCode, empty.referredBy, empty.groupIds], [null, null, isEmpty]);
  });
}
