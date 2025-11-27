/// User settings and preferences
class UserSettingsModel {
  final String userId;
  final String language; // 'ru', 'ky', 'en'
  final String? region; // Oblast/District
  final DateTime? regionLastUpdated; // For once-per-year limit
  final bool notificationsEnabled;
  final bool soundEnabled;
  final String theme; // 'light', 'dark', 'system'

  UserSettingsModel({
    required this.userId,
    this.language = 'ru',
    this.region,
    this.regionLastUpdated,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.theme = 'system',
  });

  /// Check if user can update region (once per year)
  bool canUpdateRegion() {
    if (regionLastUpdated == null) return true;
    final now = DateTime.now();
    final difference = now.difference(regionLastUpdated!);
    return difference.inDays >= 365;
  }

  factory UserSettingsModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserSettingsModel(
      userId: id,
      language: data['language'] ?? 'ru',
      region: data['region'],
      regionLastUpdated: data['regionLastUpdated'] != null
          ? DateTime.parse(data['regionLastUpdated'])
          : null,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      soundEnabled: data['soundEnabled'] ?? true,
      theme: data['theme'] ?? 'system',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'language': language,
      'region': region,
      'regionLastUpdated': regionLastUpdated?.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'theme': theme,
    };
  }

  UserSettingsModel copyWith({
    String? language,
    String? region,
    DateTime? regionLastUpdated,
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? theme,
  }) {
    return UserSettingsModel(
      userId: userId,
      language: language ?? this.language,
      region: region ?? this.region,
      regionLastUpdated: regionLastUpdated ?? this.regionLastUpdated,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      theme: theme ?? this.theme,
    );
  }

  /// Get language display name
  String getLanguageName() {
    switch (language) {
      case 'ru':
        return 'Русский';
      case 'ky':
        return 'Кыргызча';
      case 'en':
        return 'English';
      default:
        return 'Русский';
    }
  }

  /// Get available regions (Kyrgyzstan oblasts)
  static List<String> getAvailableRegions() {
    return [
      'Бишкек',
      'Ош',
      'Чуйская область',
      'Ошская область',
      'Джалал-Абадская область',
      'Иссык-Кульская область',
      'Нарынская область',
      'Таласская область',
      'Баткенская область',
    ];
  }
}
