import 'package:cloud_firestore/cloud_firestore.dart';

import 'region_model.dart';
import 'user_model.dart';

/// User settings and preferences, read from / written to the `users/{uid}`
/// document (MODEL-01).
///
/// It used to invent its own camelCase shape (`regionLastUpdated` as an ISO
/// string, `region` as a plain string) that would have overwritten the real
/// `users` fields written by [UserModel]. It now uses the same snake_case
/// fields and still understands the old shape when reading.
class UserSettingsModel {
  final String userId;
  final String language; // 'ru', 'ky', 'en' → users.preferred_language
  /// Oblast name shown in settings UIs.
  final String? region;
  /// Full region (oblast/district/settlement) when known; preserved on write.
  final RegionModel? regionDetail;
  final DateTime? regionLastUpdated; // For once-per-year limit
  final bool notificationsEnabled;
  final bool soundEnabled;
  final String theme; // 'light', 'dark', 'system'

  UserSettingsModel({
    required this.userId,
    this.language = 'ru',
    this.region,
    this.regionDetail,
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
    final regionDetail = UserModel.parseRegion(data['region']);
    bool flag(String snake, String camel, bool fallback) {
      final v = data[snake] ?? data[camel];
      return v is bool ? v : fallback;
    }

    return UserSettingsModel(
      userId: id,
      language: UserModel.parseString(data['preferred_language']) ??
          UserModel.parseString(data['language']) ??
          'ru',
      region: regionDetail?.oblast,
      regionDetail: regionDetail,
      regionLastUpdated: UserModel.parseDate(
        data['region_last_updated'] ?? data['regionLastUpdated'],
      ),
      notificationsEnabled:
          flag('notifications_enabled', 'notificationsEnabled', true),
      soundEnabled: flag('sound_enabled', 'soundEnabled', true),
      theme: UserModel.parseString(data['theme']) ?? 'system',
    );
  }

  /// Fields for a merge/update of `users/{uid}`.
  Map<String, dynamic> toFirestore() {
    RegionModel? regionMap;
    if (region != null && region!.isNotEmpty) {
      final detail = regionDetail;
      regionMap = detail != null && detail.oblast == region
          ? detail
          : RegionModel(oblast: region!, district: '', settlement: '');
    }
    return {
      'preferred_language': language,
      if (regionMap != null) 'region': regionMap.toMap(),
      if (regionLastUpdated != null)
        'region_last_updated': Timestamp.fromDate(regionLastUpdated!),
      'notifications_enabled': notificationsEnabled,
      'sound_enabled': soundEnabled,
      'theme': theme,
    };
  }

  UserSettingsModel copyWith({
    String? language,
    String? region,
    RegionModel? regionDetail,
    DateTime? regionLastUpdated,
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? theme,
  }) {
    return UserSettingsModel(
      userId: userId,
      language: language ?? this.language,
      region: region ?? this.region,
      regionDetail: regionDetail ?? this.regionDetail,
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

  /// Oblast-level regions as stored in `assets/data/kg_regions.json`.
  static List<String> getAvailableRegions() {
    return [
      'Бишкек',
      'Ош',
      'Чуйская область',
      'Ошская область',
      'Джалал-Абадская область',
      'Ысык-Кульская область',
      'Нарынская область',
      'Таласская область',
      'Баткенская область',
    ];
  }
}
