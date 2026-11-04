/// `config/achievements` — ARCHITECTURE.md §9.4:
/// `{titles: {id: {ru, ky}}, descriptions: {id: {ru, ky}}, disabled: [id]}`.
///
/// Written directly by roles with `manage_achievements` (the rules allow only
/// these three top-level keys), read by every signed-in user. Thresholds and
/// the award logic stay in the server code; this document only overrides the
/// texts and hides achievements.
///
/// Pure Dart so the serialization (only allowed keys, only known ids, only
/// ru/ky) is unit-tested.
library;

import 'localized_text.dart' show normalizeLocaleKey;

/// Achievement ids the server awards (§1.7). Order = display order.
const List<String> kAchievementIds = [
  'first_lesson',
  'xp_100',
  'streak_7',
  'days_30',
  'accuracy_90',
  'math_expert',
  'analogies_master',
  'reader',
  'exam_champion',
];

/// The only top-level keys the rules accept on `config/achievements`.
const Set<String> kAchievementsConfigKeys = {'titles', 'descriptions', 'disabled'};

/// Locales stored per text.
const List<String> kAchievementLocales = ['ru', 'ky'];

/// Longest title / description, in code points.
const int kAchievementTitleMax = 60;
const int kAchievementDescriptionMax = 200;

enum AchievementField { title, description }

enum AchievementIssueKind {
  /// Longer than [kAchievementTitleMax] / [kAchievementDescriptionMax].
  tooLong,

  /// Overridden in one language only: both or neither.
  missingTranslation,
}

class AchievementIssue {
  final String id;
  final AchievementField field;
  final AchievementIssueKind kind;

  /// The offending locale (too long) or the missing one.
  final String locale;

  const AchievementIssue(this.id, this.field, this.kind, this.locale);

  @override
  bool operator ==(Object other) =>
      other is AchievementIssue &&
      other.id == id &&
      other.field == field &&
      other.kind == kind &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(id, field, kind, locale);

  @override
  String toString() => 'AchievementIssue($id, ${field.name}, ${kind.name}, $locale)';
}

/// `{ru, ky}` with trimmed, non-empty values only; anything else is dropped.
Map<String, String> _readTexts(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    if (k is! String || v is! String) return;
    final locale = normalizeLocaleKey(k);
    final text = v.trim();
    if (!kAchievementLocales.contains(locale) || text.isEmpty) return;
    // An explicit `ky` wins over a legacy `kg`.
    if (k.trim().toLowerCase() == 'kg' && out.containsKey('ky')) return;
    out[locale] = text;
  });
  return out;
}

Map<String, Map<String, String>> _readById(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final id in kAchievementIds)
      if (_readTexts(raw[id]).isNotEmpty) id: _readTexts(raw[id]),
  };
}

class AchievementsConfig {
  /// id → {ru, ky} overrides (missing = the app's built-in text).
  final Map<String, Map<String, String>> titles;
  final Map<String, Map<String, String>> descriptions;

  /// Hidden achievements.
  final Set<String> disabled;

  /// `false` when the document does not exist yet.
  final bool exists;

  const AchievementsConfig({
    this.titles = const {},
    this.descriptions = const {},
    this.disabled = const {},
    this.exists = true,
  });

  static const AchievementsConfig empty = AchievementsConfig(exists: false);

  /// Tolerant reader: unknown ids, unknown locales, non-string and empty
  /// values are ignored.
  factory AchievementsConfig.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return empty;
    final disabled = <String>{};
    final d = raw['disabled'];
    if (d is List) {
      for (final id in d) {
        if (id is String && kAchievementIds.contains(id)) disabled.add(id);
      }
    }
    return AchievementsConfig(
      titles: _readById(raw['titles']),
      descriptions: _readById(raw['descriptions']),
      disabled: disabled,
    );
  }

  String text(AchievementField field, String id, String locale) =>
      (field == AchievementField.title ? titles : descriptions)[id]?[locale] ?? '';

  bool isEnabled(String id) => !disabled.contains(id);

  /// The document to write — exactly [kAchievementsConfigKeys], only known
  /// ids (in [kAchievementIds] order), only ru/ky, trimmed, empty values and
  /// empty entries omitted. Written with `set()` (no merge) so stale keys
  /// never survive.
  Map<String, dynamic> toFirestore() {
    Map<String, Map<String, String>> clean(Map<String, Map<String, String>> src) {
      final out = <String, Map<String, String>>{};
      for (final id in kAchievementIds) {
        final texts = <String, String>{
          for (final l in kAchievementLocales)
            if ((src[id]?[l] ?? '').trim().isNotEmpty) l: src[id]![l]!.trim(),
        };
        if (texts.isNotEmpty) out[id] = texts;
      }
      return out;
    }

    return {
      'titles': clean(titles),
      'descriptions': clean(descriptions),
      'disabled': [
        for (final id in kAchievementIds)
          if (disabled.contains(id)) id,
      ],
    };
  }

  /// Both languages or neither for each overridden text; length limits.
  List<AchievementIssue> validate() {
    final issues = <AchievementIssue>[];
    for (final id in kAchievementIds) {
      for (final field in AchievementField.values) {
        final max = field == AchievementField.title ? kAchievementTitleMax : kAchievementDescriptionMax;
        final present = [
          for (final l in kAchievementLocales)
            if (text(field, id, l).trim().isNotEmpty) l,
        ];
        if (present.isNotEmpty && present.length < kAchievementLocales.length) {
          for (final l in kAchievementLocales) {
            if (!present.contains(l)) {
              issues.add(AchievementIssue(id, field, AchievementIssueKind.missingTranslation, l));
            }
          }
        }
        for (final l in present) {
          if (text(field, id, l).trim().runes.length > max) {
            issues.add(AchievementIssue(id, field, AchievementIssueKind.tooLong, l));
          }
        }
      }
    }
    return issues;
  }

  /// Builds a config from editor values: `texts[field][id][locale]`.
  factory AchievementsConfig.fromEditor({
    required Map<String, Map<String, String>> titles,
    required Map<String, Map<String, String>> descriptions,
    required Set<String> disabled,
  }) =>
      AchievementsConfig(
        titles: titles,
        descriptions: descriptions,
        disabled: {for (final id in disabled) if (kAchievementIds.contains(id)) id},
      );
}
