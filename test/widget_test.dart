import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:knowledge_flow/main.dart';
import 'package:knowledge_flow/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boot smoke test without Firebase: the Firebase bootstrap is replaced by a
/// failing future, so the app must show the boot error screen with a retry
/// button (BOOT-02) instead of hanging on a spinner. Full flows with real
/// Firebase belong in integration_test/ with the emulator.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a failed Firebase start shows an error screen with retry',
      (tester) async {
    SharedPreferences.setMockInitialValues({LocalePrefsKeys.current: 'ru'});
    final prefs = await SharedPreferences.getInstance();
    var attempts = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firebaseBootstrapProvider.overrideWith((ref) async {
            attempts++;
            throw Exception('Firebase unavailable in tests');
          }),
        ],
        child: const OrtMasterApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось запустить приложение'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Не удалось запустить приложение'), findsOneWidget);
  });
}
