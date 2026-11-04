import 'package:flutter/foundation.dart';

import '../../../core/utils/json_read.dart';
import '../../../l10n/app_localizations.dart';
import 'achievement_catalog.dart';

/// Editable copy for achievements, `config/achievements` (ARCHITECTURE §9.4):
/// `{titles: {id: {ru, ky}}, descriptions: {id: {ru, ky}}, disabled: [id]}`.
/// Thresholds and unlocking stay on the server; this only changes what the
/// student reads and which achievements are shown.
@immutable
class AchievementConfig {
  final Map<String, Map<String, String>> titles;
  final Map<String, Map<String, String>> descriptions;
  final Set<String> disabled;

  const AchievementConfig({
    this.titles = const {},
    this.descriptions = const {},
    this.disabled = const {},
  });

  static const empty = AchievementConfig();

  factory AchievementConfig.fromMap(Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    Map<String, Map<String, String>> texts(String key) {
      final raw = JsonRead.map(d, [key]) ?? const <String, dynamic>{};
      return {
        for (final e in raw.entries)
          if (e.value is Map)
            e.key: {
              for (final t in (e.value as Map).entries)
                if (t.value is String && (t.value as String).trim().isNotEmpty)
                  t.key.toString(): (t.value as String).trim(),
            },
      };
    }

    return AchievementConfig(
      titles: texts('titles'),
      descriptions: texts('descriptions'),
      disabled: JsonRead.stringList(d, ['disabled']).toSet(),
    );
  }

  /// The configured text in [lang] (`ru`/`ky`), else the built-in string.
  /// English has no configured copy and always uses the built-in string.
  String title(AchievementDef def, AppLocalizations l, String lang) =>
      _pick(titles[def.id], lang) ?? def.title(l);

  String description(AchievementDef def, AppLocalizations l, String lang) =>
      _pick(descriptions[def.id], lang) ?? def.description(l);

  /// [all] without the disabled ids, in catalog order.
  List<AchievementDef> visible(List<AchievementDef> all) =>
      [for (final a in all) if (!disabled.contains(a.id)) a];

  static String? _pick(Map<String, String>? texts, String lang) {
    if (texts == null || (lang != 'ru' && lang != 'ky')) return null;
    final v = texts[lang];
    return (v == null || v.isEmpty) ? null : v;
  }
}
