import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/exam/data/exam_remote_datasource.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
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

  group('unsupported platform (contract D7)', () {
    test('only Windows / Linux desktop builds are unsupported', () {
      bool on(TargetPlatform p, {bool web = false}) =>
          examCallablesSupported(isWeb: web, platform: p, desktopOverride: false);
      expect(on(TargetPlatform.android), isTrue);
      expect(on(TargetPlatform.iOS), isTrue);
      expect(on(TargetPlatform.macOS), isTrue);
      expect(on(TargetPlatform.windows, web: true), isTrue, reason: 'web build');
      expect(on(TargetPlatform.windows), isFalse);
      expect(on(TargetPlatform.linux), isFalse);
      expect(
          examCallablesSupported(
              isWeb: false, platform: TargetPlatform.windows, desktopOverride: true),
          isTrue,
          reason: 'developer override for emulator / unenforced backends');
    });

    test('the data source fails fast without touching Firebase', () async {
      const remote = FirebaseExamRemoteDataSource(platformSupported: false);
      await expectLater(
        remote.start(variantId: 'v1', clientAppVersion: '1'),
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
