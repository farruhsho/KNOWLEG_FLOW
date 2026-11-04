import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_provider.dart';

// Compatibility shim. The app used to have two language providers that never
// talked to each other (LANG-01 / UI-02): `languageProvider` ('app_language')
// was written by the language picker while MaterialApp read `localeProvider`
// ('app_locale'). Everything now goes through [localeProvider]; the legacy
// preference is migrated by LocaleController on first read.
export 'locale_provider.dart'
    show sharedPreferencesProvider, localeProvider, contentLanguageProvider;

/// Read-only view of the current UI language code ('ru' | 'ky' | 'en').
/// To change the language use `ref.read(localeProvider.notifier)`.
@Deprecated('Use localeProvider or contentLanguageProvider')
final languageProvider = Provider<String>(
  (ref) => ref.watch(localeProvider.select((l) => l.languageCode)),
);
