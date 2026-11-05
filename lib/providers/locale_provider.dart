import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app-wide [SharedPreferences] instance. `main()` loads it once before
/// `runApp` and overrides this provider, so every read below is synchronous
/// (no locale "flash" after the first frame).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the loaded instance',
  );
});

/// UI languages the app ships ARB files for.
const List<String> kSupportedLanguageCodes = ['ru', 'ky', 'en'];

/// Languages exam/learning content exists in (ORT is taken in ru or ky).
const List<String> kContentLanguageCodes = ['ru', 'ky'];

/// Preference keys. `app_locale` is the single source of truth; the legacy
/// `app_language` key (written by the old LanguageToggleWidget that the app
/// never read — LANG-01) is migrated into it once and then removed.
abstract final class LocalePrefsKeys {
  static const current = 'app_locale';
  static const legacy = 'app_language';
}

/// The OS locale. Overridable in tests.
final deviceLocaleProvider = Provider<Locale?>((ref) {
  try {
    return PlatformDispatcher.instance.locale;
  } catch (_) {
    return null;
  }
});

/// Decides the starting UI language.
///
/// Order: saved `app_locale` → legacy `app_language` → device language when
/// it is Kyrgyz or Russian → Russian.
@visibleForTesting
String resolveInitialLanguageCode({
  String? saved,
  String? legacy,
  Locale? device,
}) {
  if (saved != null && kSupportedLanguageCodes.contains(saved)) return saved;
  if (legacy != null && kSupportedLanguageCodes.contains(legacy)) return legacy;
  final deviceCode = device?.languageCode.toLowerCase();
  if (deviceCode == 'ky' || deviceCode == 'ru') return deviceCode!;
  // Kyrgyz devices sometimes report "kir" / "kg"-style codes.
  if (deviceCode == 'kir') return 'ky';
  return 'ru';
}

/// The one locale controller for the app. MaterialApp.locale watches it, and
/// every language picker writes through it.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(LocalePrefsKeys.current);
    final legacy = prefs.getString(LocalePrefsKeys.legacy);
    final code = resolveInitialLanguageCode(
      saved: saved,
      legacy: legacy,
      device: ref.watch(deviceLocaleProvider),
    );
    if (legacy != null) {
      // One-time migration: persist under the canonical key, drop the old one.
      if (saved == null && kSupportedLanguageCodes.contains(legacy)) {
        prefs.setString(LocalePrefsKeys.current, legacy);
      }
      prefs.remove(LocalePrefsKeys.legacy);
    }
    return Locale(code);
  }

  /// Changes the live app locale and persists it.
  Future<void> setLocale(Locale locale) =>
      setLanguageCode(locale.languageCode);

  Future<void> setLanguageCode(String languageCode) async {
    final code = languageCode.toLowerCase();
    if (!kSupportedLanguageCodes.contains(code)) {
      throw ArgumentError.value(languageCode, 'languageCode', 'Unsupported');
    }
    if (state.languageCode != code) state = Locale(code);
    await ref.read(sharedPreferencesProvider).setString(
          LocalePrefsKeys.current,
          code,
        );
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// Maps any UI language to the language exam/learning content is served in:
/// Kyrgyz UI → 'ky', everything else → 'ru'.
String contentLanguageFor(String uiLanguageCode) =>
    uiLanguageCode == 'ky' ? 'ky' : 'ru';

/// Current content language code ('ru' | 'ky') for other packages: exam
/// variants, lessons, AI tutor replies.
final contentLanguageProvider = Provider<String>((ref) {
  final code = ref.watch(localeProvider.select((l) => l.languageCode));
  return contentLanguageFor(code);
});

extension ContentLanguageX on WidgetRef {
  /// Shorthand for `ref.watch(contentLanguageProvider)`.
  String get contentLanguage => watch(contentLanguageProvider);
}
