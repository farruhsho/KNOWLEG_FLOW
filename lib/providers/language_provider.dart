import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language provider for managing app language (RU/KG/EN)
class LanguageNotifier extends StateNotifier<String> {
  static const String _languageKey = 'app_language';
  final SharedPreferences _prefs;

  LanguageNotifier(this._prefs) : super(_prefs.getString(_languageKey) ?? 'ru');

  /// Change language and persist to shared preferences
  Future<void> setLanguage(String languageCode) async {
    if (languageCode == state) return;
    
    // Validate language code
    if (!['ru', 'ky', 'en'].contains(languageCode)) {
      throw ArgumentError('Invalid language code: $languageCode');
    }

    await _prefs.setString(_languageKey, languageCode);
    state = languageCode;
  }

  /// Get current language
  String get currentLanguage => state;

  /// Check if language is Russian
  bool get isRussian => state == 'ru';

  /// Check if language is Kyrgyz
  bool get isKyrgyz => state == 'ky';

  /// Check if language is English
  bool get isEnglish => state == 'en';
}

/// Provider for language state
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  throw UnimplementedError('languageProvider must be overridden with SharedPreferences');
});

/// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});
