import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';
import 'package:knowledge_flow/features/account/data/account_deletion_service.dart';
import 'package:knowledge_flow/features/account/domain/account_deletion.dart';
import 'package:knowledge_flow/features/account/presentation/pages/account_delete_page.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';

class _FakeUser extends Fake implements User {
  @override
  String? get email => 'student@example.test';
}

class _FakeDeletionService extends AccountDeletionService {
  _FakeDeletionService({
    this.signedIn = true,
    this.reauthMethods = const [ReauthMethod.password],
    List<Object?>? deleteScript,
  }) : deleteScript = deleteScript ?? [null];

  final bool signedIn;
  final List<ReauthMethod> reauthMethods;

  /// `null` = success, otherwise thrown. The last entry repeats.
  final List<Object?> deleteScript;

  final List<String> passwords = [];
  int googleCalls = 0;
  int deleteCalls = 0;
  AccountDeleteFailure? passwordFailure;

  @override
  User? get currentUser => signedIn ? _FakeUser() : null;

  @override
  List<ReauthMethod> methods() => reauthMethods;

  @override
  Future<void> reauthWithPassword(String password) async {
    passwords.add(password);
    if (passwordFailure != null) throw AccountDeleteException(passwordFailure!);
  }

  @override
  Future<void> reauthWithGoogle() async => googleCalls++;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    final next = deleteScript.length > 1 ? deleteScript.removeAt(0) : deleteScript.first;
    if (next != null) throw next;
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _FakeDeletionService service, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: RoutePaths.accountDelete,
      routes: [
        GoRoute(path: RoutePaths.splash, builder: (_, __) => const Scaffold(body: Text('SPLASH'))),
        GoRoute(path: RoutePaths.login, builder: (_, __) => const Scaffold(body: Text('LOGIN'))),
        GoRoute(path: RoutePaths.accountDelete, builder: (_, __) => const AccountDeletePage()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [accountDeletionServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          brightness: brightness,
          extensions: [brightness == Brightness.dark ? AppTokens.dark : AppTokens.light],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder deleteButton() => find.ancestor(
        of: find.text('Удалить аккаунт навсегда'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );

  Future<void> typeConfirmation(WidgetTester tester, String text) async {
    final field = find.byType(TextField);
    await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(field, text);
    await tester.pump();
  }

  testWidgets('explains what is deleted and what is kept', (tester) async {
    await pumpPage(tester, _FakeDeletionService());
    expect(find.text('Что будет удалено'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Что сохранится'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('записи о покупках'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('button stays disabled until the confirmation word is typed', (tester) async {
    final service = _FakeDeletionService();
    await pumpPage(tester, service);

    await typeConfirmation(tester, 'удали');
    await tester.scrollUntilVisible(deleteButton(), 200, scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(deleteButton()).onPressed, isNull);

    await typeConfirmation(tester, 'удалить');
    await tester.scrollUntilVisible(deleteButton(), 200, scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(deleteButton()).onPressed, isNotNull);
    expect(service.deleteCalls, 0);
  });

  testWidgets('password re-auth → accountDelete → back to splash', (tester) async {
    final service = _FakeDeletionService();
    await pumpPage(tester, service);

    await typeConfirmation(tester, 'УДАЛИТЬ');
    await tester.scrollUntilVisible(deleteButton(), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(deleteButton());
    // The page shows a spinner while the dialog is open: no pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Re-authentication dialog.
    expect(find.text('Подтвердите, что это вы'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'secret-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
    await tester.pumpAndSettle();

    expect(service.passwords, ['secret-pass']);
    expect(service.deleteCalls, 1);
    expect(find.text('SPLASH'), findsOneWidget);
  });

  testWidgets('requires-recent-login → re-auth again and retry once', (tester) async {
    final service = _FakeDeletionService(
      reauthMethods: const [ReauthMethod.google],
      deleteScript: [const AccountDeleteException(AccountDeleteFailure.requiresRecentLogin), null],
    );
    await pumpPage(tester, service);

    await typeConfirmation(tester, 'УДАЛИТЬ');
    await tester.scrollUntilVisible(deleteButton(), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(service.googleCalls, 2);
    expect(service.deleteCalls, 2);
    expect(find.text('SPLASH'), findsOneWidget);
  });

  testWidgets('a backend error is shown and the user can try again', (tester) async {
    final service = _FakeDeletionService(
      reauthMethods: const [ReauthMethod.google],
      deleteScript: [const AccountDeleteException(AccountDeleteFailure.network)],
    );
    await pumpPage(tester, service);

    await typeConfirmation(tester, 'УДАЛИТЬ');
    await tester.scrollUntilVisible(deleteButton(), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('Нет соединения'), findsOneWidget);
    expect(tester.widget<FilledButton>(deleteButton()).onPressed, isNotNull);
    expect(find.text('SPLASH'), findsNothing);
  });

  testWidgets('signed out → offers to sign in instead of deleting', (tester) async {
    await pumpPage(tester, _FakeDeletionService(signedIn: false));
    await tester.scrollUntilVisible(find.text('Войти'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('dark mode on a small phone renders without overflow', (tester) async {
    await pumpPage(tester, _FakeDeletionService(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
