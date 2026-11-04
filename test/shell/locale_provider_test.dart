import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> containerWith(
    Map<String, Object> prefs, {
    Locale? device,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(instance),
      deviceLocaleProvider.overrideWithValue(device),
    ]);
    addTearDown(container.dispose);
    return (container, instance);
  }

  group('resolveInitialLanguageCode', () {
    test('saved value wins', () {
      expect(
        resolveInitialLanguageCode(saved: 'ky', legacy: 'en', device: const Locale('ru')),
        'ky',
      );
    });

    test('legacy value is used when nothing is saved', () {
      expect(resolveInitialLanguageCode(legacy: 'ky', device: const Locale('ru')), 'ky');
    });

    test('device locale is used only for ky / ru', () {
      expect(resolveInitialLanguageCode(device: const Locale('ky', 'KG')), 'ky');
      expect(resolveInitialLanguageCode(device: const Locale('ru', 'RU')), 'ru');
      expect(resolveInitialLanguageCode(device: const Locale('en', 'US')), 'ru');
      expect(resolveInitialLanguageCode(device: const Locale('de')), 'ru');
    });

    test('defaults to Russian and ignores unsupported saved values', () {
      expect(resolveInitialLanguageCode(), 'ru');
      expect(resolveInitialLanguageCode(saved: 'fr', legacy: 'xx'), 'ru');
    });
  });

  group('LocaleController', () {
    test('migrates the legacy app_language value once (LANG-01)', () async {
      final (container, prefs) = await containerWith({
        LocalePrefsKeys.legacy: 'ky',
      }, device: const Locale('ru'));

      expect(container.read(localeProvider), const Locale('ky'));
      expect(prefs.getString(LocalePrefsKeys.current), 'ky');
      expect(prefs.containsKey(LocalePrefsKeys.legacy), isFalse);
    });

    test('keeps app_locale over a stale legacy value and drops the legacy key',
        () async {
      final (container, prefs) = await containerWith({
        LocalePrefsKeys.current: 'en',
        LocalePrefsKeys.legacy: 'ky',
      });

      expect(container.read(localeProvider), const Locale('en'));
      expect(prefs.getString(LocalePrefsKeys.current), 'en');
      expect(prefs.containsKey(LocalePrefsKeys.legacy), isFalse);
    });

    test('falls back to the device language, then Russian', () async {
      final (kyDevice, _) = await containerWith({}, device: const Locale('ky'));
      expect(kyDevice.read(localeProvider), const Locale('ky'));

      final (enDevice, _) = await containerWith({}, device: const Locale('en'));
      expect(enDevice.read(localeProvider), const Locale('ru'));
    });

    test('setLanguageCode changes the live locale and persists it', () async {
      final (container, prefs) = await containerWith({});
      await container.read(localeProvider.notifier).setLanguageCode('ky');

      expect(container.read(localeProvider), const Locale('ky'));
      expect(prefs.getString(LocalePrefsKeys.current), 'ky');
    });

    test('rejects unsupported languages', () async {
      final (container, _) = await containerWith({});
      expect(
        () => container.read(localeProvider.notifier).setLanguageCode('de'),
        throwsArgumentError,
      );
    });

    test('contentLanguageProvider maps the UI language to ru / ky', () async {
      final (container, _) = await containerWith({LocalePrefsKeys.current: 'ky'});
      expect(container.read(contentLanguageProvider), 'ky');

      await container.read(localeProvider.notifier).setLanguageCode('en');
      expect(container.read(contentLanguageProvider), 'ru');

      await container.read(localeProvider.notifier).setLanguageCode('ru');
      expect(container.read(contentLanguageProvider), 'ru');
    });
  });
}
