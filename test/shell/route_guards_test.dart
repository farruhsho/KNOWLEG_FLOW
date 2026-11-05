import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/navigation/route_guards.dart';
import 'package:knowledge_flow/core/routes/route_paths.dart';

void main() {
  String? resolve(String location, {bool signedIn = false, bool admin = false}) =>
      RouteGuards.resolveRedirect(
        Uri.parse(location),
        signedIn: signedIn,
        adminVerified: admin,
      );

  group('legacy redirects (NAV-01 / NAV-06)', () {
    test('old literals map to the new locations', () {
      expect(RouteGuards.legacyRedirect('/dashboard'), RoutePaths.home);
      expect(RouteGuards.legacyRedirect('/dashboard/'), RoutePaths.home);
      expect(RouteGuards.legacyRedirect('/subjects'), RoutePaths.learn);
      expect(RouteGuards.legacyRedirect('/lessons/daily'), RoutePaths.dailyLesson);
      expect(RouteGuards.legacyRedirect('/payments'), RoutePaths.store);
      expect(RouteGuards.legacyRedirect('/mock-test/demo'), RoutePaths.exams);
      expect(RouteGuards.legacyRedirect('/mock-test/abc123'), RoutePaths.exams);
    });

    test('current routes are not rewritten', () {
      for (final path in [
        RoutePaths.home,
        RoutePaths.learn,
        RoutePaths.subject('math'),
        RoutePaths.lessonById('l1'),
        RoutePaths.quizById('q1'),
        RoutePaths.dailyLesson,
        RoutePaths.store,
        RoutePaths.exams,
      ]) {
        expect(RouteGuards.legacyRedirect(path), isNull, reason: path);
      }
    });

    test('legacy redirect wins before the auth guard', () {
      expect(resolve('/dashboard', signedIn: true), RoutePaths.home);
      // Signed out: rewritten first, the next pass then hits the guard.
      expect(resolve('/dashboard'), RoutePaths.home);
      expect(resolve(RoutePaths.home), RoutePaths.login);
    });
  });

  group('admin gate (SEC-003)', () {
    test('admin login is always reachable', () {
      expect(resolve(RoutePaths.adminLogin), isNull);
      expect(resolve(RoutePaths.adminLogin, signedIn: true), isNull);
    });

    test('admin area requires sign-in and a verified admin session', () {
      expect(resolve(RoutePaths.adminDashboard), RoutePaths.adminLogin);
      expect(resolve(RoutePaths.adminDashboard, signedIn: true), RoutePaths.adminLogin);
      expect(resolve('/admin/users', signedIn: false, admin: true), RoutePaths.adminLogin);
      expect(resolve(RoutePaths.adminDashboard, signedIn: true, admin: true), isNull);
      expect(resolve('/admin/questions', signedIn: true, admin: true), isNull);
    });

    test('paths that only look like admin are not gated as admin', () {
      expect(RouteGuards.isAdminArea('/administer'), isFalse);
      expect(RouteGuards.isAdminArea('/admin'), isTrue);
    });
  });

  group('pop fallback (UI-04 / NAV-02)', () {
    test('drill-downs fall back to the tab they belong to', () {
      expect(RouteGuards.popFallback(RoutePaths.subject('math')), RoutePaths.learn);
      expect(RouteGuards.popFallback(RoutePaths.lessonById('l1')), RoutePaths.learn);
      expect(RouteGuards.popFallback(RoutePaths.quizById('q1')), RoutePaths.learn);
      expect(RouteGuards.popFallback(RoutePaths.examRunFor('a1')), RoutePaths.exams);
      expect(RouteGuards.popFallback(RoutePaths.examHistory), RoutePaths.exams);
      expect(RouteGuards.popFallback(RoutePaths.settings), RoutePaths.profile);
      expect(RouteGuards.popFallback(RoutePaths.achievements), RoutePaths.profile);
      expect(RouteGuards.popFallback(RoutePaths.transactions), RoutePaths.profile);
      expect(RouteGuards.popFallback(RoutePaths.accountDelete), RoutePaths.profile);
      expect(RouteGuards.popFallback(RoutePaths.quickTest), RoutePaths.home);
      expect(RouteGuards.popFallback(RoutePaths.dailyLesson), RoutePaths.home);
      expect(RouteGuards.popFallback(RoutePaths.tutor), RoutePaths.home);
    });

    test('entry and admin screens have safe parents', () {
      expect(RouteGuards.popFallback(RoutePaths.signup), RoutePaths.login);
      expect(RouteGuards.popFallback(RoutePaths.adminLogin), RoutePaths.splash);
      expect(RouteGuards.popFallback('/admin/users'), RoutePaths.adminDashboard);
      expect(RouteGuards.popFallback(RoutePaths.adminDashboard), RoutePaths.adminLogin);
    });

    test('lookalike prefixes are not matched', () {
      expect(RouteGuards.popFallback('/subjectsx'), RoutePaths.home);
      expect(RouteGuards.popFallback('/quiz-results'), RoutePaths.home);
    });
  });

  group('student auth guard (NAV-04)', () {
    test('signed-out users may open only the public entry screens', () {
      for (final path in [
        RoutePaths.splash,
        RoutePaths.onboarding,
        RoutePaths.login,
        RoutePaths.signup,
      ]) {
        expect(resolve(path), isNull, reason: path);
      }
    });

    test('signed-out users are sent to login and keep the destination', () {
      final target = resolve(RoutePaths.quizById('q1'));
      final uri = Uri.parse(target!);
      expect(uri.path, RoutePaths.login);
      expect(uri.queryParameters[RouteGuards.fromParam], '/quiz/q1');

      expect(resolve(RoutePaths.home), RoutePaths.login);
      expect(Uri.parse(resolve(RoutePaths.settings)!).path, RoutePaths.login);
      expect(Uri.parse(resolve(RoutePaths.exams)!).path, RoutePaths.login);
    });

    test('signed-in users are bounced from login/signup', () {
      expect(resolve(RoutePaths.login, signedIn: true), RoutePaths.home);
      expect(resolve(RoutePaths.signup, signedIn: true), RoutePaths.home);
      expect(
        resolve('/login?from=%2Fquiz%2Fq1', signedIn: true),
        '/quiz/q1',
      );
    });

    test('signed-in users can open the app and onboarding', () {
      for (final path in [
        RoutePaths.splash,
        RoutePaths.onboarding,
        RoutePaths.home,
        RoutePaths.profile,
        RoutePaths.settings,
        RoutePaths.subject('math'),
      ]) {
        expect(resolve(path, signedIn: true), isNull, reason: path);
      }
    });

    test('unsafe `from` values are ignored', () {
      expect(RouteGuards.isSafeReturnLocation(null), isFalse);
      expect(RouteGuards.isSafeReturnLocation(''), isFalse);
      expect(RouteGuards.isSafeReturnLocation('https://evil.example'), isFalse);
      expect(RouteGuards.isSafeReturnLocation('//evil.example/x'), isFalse);
      expect(RouteGuards.isSafeReturnLocation(RoutePaths.login), isFalse);
      expect(RouteGuards.isSafeReturnLocation(RoutePaths.adminDashboard), isFalse);
      expect(RouteGuards.isSafeReturnLocation('/quiz/q1'), isTrue);
      expect(
        resolve('/login?from=https%3A%2F%2Fevil.example', signedIn: true),
        RoutePaths.home,
      );
    });
  });

  // Found in the web walkthrough: the boot screen wiped `#/pay/return`, so the
  // return from the payment provider (and any reload) landed on home.
  group('cold start deep link', () {
    test('a safe in-app route is carried through the splash as ?from=', () {
      expect(RouteGuards.coldStartLocation('/pay/return'), '${RoutePaths.splash}?from=%2Fpay%2Freturn');
      expect(RouteGuards.coldStartLocation('/exams'), '${RoutePaths.splash}?from=%2Fexams');
    });

    test('root, entry, admin and foreign locations start at the plain splash', () {
      for (final r in [null, '', '/', RoutePaths.login, RoutePaths.splash, '/admin/dashboard', '//evil.example', 'https://evil.example/x']) {
        expect(RouteGuards.coldStartLocation(r), RoutePaths.splash, reason: '$r');
      }
    });
  });
}
