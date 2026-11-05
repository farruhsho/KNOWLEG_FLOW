import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/admin/application/admin_providers.dart';
import 'package:knowledge_flow/features/admin/data/admin_firebase.dart';
import 'package:knowledge_flow/features/admin/domain/admin_nav.dart';
import 'package:knowledge_flow/features/admin/domain/admin_role.dart';
import 'package:knowledge_flow/features/admin/domain/pricing_config.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/admin_login_page.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/ops_pages.dart';
import 'package:knowledge_flow/features/admin/presentation/shell/admin_shell.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/math_markdown.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/providers/admin_access_provider.dart';

/// Layout smoke tests on a 360×640 phone (light and dark) and a desktop
/// width. Any RenderFlex overflow fails the test.

class _FakeAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSession extends AdminSessionNotifier {
  _TestSession(this.role);
  final AdminRole role;

  @override
  AdminSession? build() => AdminSession(uid: 'u1', email: 'staff@ort.kg', role: role);
}

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
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
}

List<Override> _session(AdminRole role) => [
      adminSessionProvider.overrideWith(() => _TestSession(role)),
      adminStatProvider.overrideWith((ref, stat) async => 1234),
      pricingProvider.overrideWith((ref) async => PricingConfig.defaults),
    ];

void main() {
  for (final b in Brightness.values) {
    testWidgets('login fits a 360x640 phone (${b.name})', (tester) async {
      await _pump(
        tester,
        const AdminLoginPage(),
        brightness: b,
        overrides: [adminAuthProvider.overrideWithValue(_FakeAuth())],
      );
      expect(find.text('Админ-панель'), findsOneWidget);
      expect(find.text('Забыли пароль?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard in the shell on a phone (${b.name})', (tester) async {
      await _pump(
        tester,
        const AdminShell(location: '/admin/dashboard', child: AdminDashboardPage()),
        brightness: b,
        overrides: _session(AdminRole.superAdmin),
      );
      expect(find.text('1234'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone uses a drawer filtered by role', (tester) async {
    await _pump(
      tester,
      const AdminShell(location: '/admin/users', child: SizedBox()),
      overrides: _session(AdminRole.support),
    );
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Платежи'), findsOneWidget);
    expect(find.text('Журнал действий'), findsOneWidget);
    expect(find.text('Тарифы'), findsNothing);
    expect(find.text('Банк экзамена'), findsNothing);
  });

  testWidgets('desktop shows a permanent sidebar', (tester) async {
    await _pump(
      tester,
      const AdminShell(location: '/admin/exam-bank', child: SizedBox()),
      size: const Size(1280, 800),
      overrides: _session(AdminRole.methodologist),
    );
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.text('Черновики ИИ'), findsOneWidget);
    expect(find.text('Платежи'), findsNothing);
  });

  testWidgets('pricing page warns about Play Console prices', (tester) async {
    await _pump(
      tester,
      const AdminShell(location: '/admin/pricing', child: PricingPage()),
      overrides: _session(AdminRole.superAdmin),
      brightness: Brightness.dark,
    );
    // Phase 4 (§10.3): the website prices open first; Play credits are the
    // second tab.
    expect(find.textContaining('config/pricing.web_products'), findsOneWidget);
    await tester.tap(find.text('Google Play'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google Play Console'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forbidden section shows the no-access view', (tester) async {
    await _pump(
      tester,
      const AdminShell(
        location: '/admin/pricing',
        child: AdminGateHost(),
      ),
      overrides: _session(AdminRole.support),
    );
    expect(find.text('Нет доступа'), findsOneWidget);
  });

  testWidgets('math markdown renders long formulas without overflow', (tester) async {
    await _pump(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: MathMarkdownText(
            r'## Формула' '\n'
            r'Корни: $x_{1,2} = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$ и **важно**' '\n'
            r'$$\int_0^1 x^2\,dx + \sum_{k=1}^{100} \frac{1}{k^2} + \prod_{i=1}^{n} (1 + \frac{1}{i})$$',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

/// Pricing behind its gate, as the router builds it.
class AdminGateHost extends StatelessWidget {
  const AdminGateHost({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminGate(section: AdminSection.pricing, child: PricingPage());
}
