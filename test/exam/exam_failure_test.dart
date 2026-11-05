import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/backend/callable_platform.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/data/exam_remote_datasource.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_start.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/exam_common.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/l10n/app_localizations_ky.dart';
import 'package:knowledge_flow/l10n/app_localizations_ru.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(extensions: [AppTokens.light]),
      home: Scaffold(body: child),
    );

void main() {
  group('USER_BANNED (contract D5)', () {
    test('maps to a terminal failure with a clear message', () {
      expect(ExamFailureKind.fromReason('USER_BANNED'), ExamFailureKind.userBanned);
      expect(ExamFailureKind.userBanned.isRetryable, isFalse);
      expect(ExamFailureKind.userBanned.isTerminal, isTrue);
      final ru = examFailureMessage(
          AppLocalizationsRu(), const ExamFailure(ExamFailureKind.userBanned));
      expect(ru, contains('заблокирован'));
      final ky = examFailureMessage(
          AppLocalizationsKy(), const ExamFailure(ExamFailureKind.userBanned));
      expect(ky, contains('бөгөттөлгөн'));
    });

    testWidgets('error view offers no pointless retry', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => ExamMessageView.error(
          context,
          error: const ExamFailure(ExamFailureKind.userBanned),
          onRetry: () {},
        ),
      )));
      expect(find.textContaining('заблокирован модератором'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
    });
  });

  group('unsupported platform (contract D7, APPCHECK-01)', () {
    // Exams use the app-wide App Check gate (lib/core/backend/
    // callable_platform.dart), the same one as the tutor and account
    // deletion — not a gate of their own.
    test('web is supported only when built with an App Check site key', () {
      bool on(TargetPlatform p, {bool web = false, String key = ''}) =>
          callablesSupportedOn(isWeb: web, platform: p, webSiteKey: key);
      expect(on(TargetPlatform.android), isTrue);
      expect(on(TargetPlatform.iOS), isTrue);
      expect(on(TargetPlatform.macOS), isTrue);
      expect(on(TargetPlatform.windows), isFalse);
      expect(on(TargetPlatform.linux), isFalse);
      expect(on(TargetPlatform.windows, web: true), isFalse,
          reason: 'web without APP_CHECK_WEB_SITE_KEY gets no App Check token');
      expect(on(TargetPlatform.android, web: true), isFalse);
      expect(on(TargetPlatform.windows, web: true, key: '6Lc_key'), isTrue);
    });

    test('examCallablesSupportedProvider follows the shared gate', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      bool readGate() {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        return container.read(examCallablesSupportedProvider);
      }

      for (final p in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = p;
        expect(readGate(), callablesSupportedOnThisPlatform, reason: '$p');
        expect(
            readGate(),
            callablesSupportedOn(
                isWeb: kIsWeb, platform: p, webSiteKey: appCheckWebSiteKey),
            reason: '$p');
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(readGate(), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(readGate(), isTrue);
    });

    test('the platform message no longer sends desktop users to the browser', () {
      for (final l in [AppLocalizationsRu(), AppLocalizationsKy()]) {
        final msg = examFailureMessage(
            l, const ExamFailure(ExamFailureKind.platformUnsupported));
        expect(msg, isNot(contains('браузер')));
        expect(msg, contains('Android'));
      }
    });

    test('the data source fails fast without touching Firebase', () async {
      const remote = FirebaseExamRemoteDataSource(platformSupported: false);
      await expectLater(
        remote.start(const ExamStartRequest.library(variantId: 'v1', clientAppVersion: '1')),
        throwsA(isA<ExamFailure>()
            .having((f) => f.kind, 'kind', ExamFailureKind.platformUnsupported)),
      );
      await expectLater(
        remote.getReview('a1'),
        throwsA(isA<ExamFailure>()
            .having((f) => f.kind, 'kind', ExamFailureKind.platformUnsupported)),
      );
    });

    testWidgets('error view explains the platform and offers no retry', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => ExamMessageView.error(
          context,
          error: const ExamFailure(ExamFailureKind.platformUnsupported),
          onRetry: () {},
        ),
      )));
      expect(find.textContaining('На этом устройстве пробные экзамены недоступны'),
          findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
    });
  });
}
