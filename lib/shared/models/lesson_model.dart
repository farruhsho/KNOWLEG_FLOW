import '../../core/utils/content_locale.dart';
import '../../core/utils/json_read.dart';

/// A lesson from the `lessons` collection.
///
/// Two shapes are supported:
/// * **legacy** — a localized `content` blob (plain text / light Markdown);
/// * **structured** — `summary`, `sections[{title, body}]`, `formulas`,
///   `examples[{problem, solution}]`, `common_mistakes`, `practice_question_ids`,
///   `video_url`, `pdf_url`, `images`.
///
/// Localized fields may be either a `{ru, ky, en}` map or a plain string;
/// list fields may be a list of localized items or a `{ru: [...], ky: [...]}`
/// map of lists. Parsing never throws on an odd document (CMS-21).
class LessonModel {
  final String id;
  final String subjectId;
  final Map<String, String> title; // ru, ky, en
  final Map<String, String> content;
  final List<String> mediaUrls;
  final int estimatedTimeMinutes;
  final List<String> tags;
  final int order;
  final String createdBy;
  final DateTime createdAt;

  // Structured content (all optional).
  final Map<String, String> summary;
  final List<LessonSection> sections;
  final List<LessonFormula> formulas;
  final List<LessonExample> examples;
  final List<Map<String, String>> commonMistakes;
  final List<String> practiceQuestionIds;
  final String? videoUrl;
  final String? pdfUrl;
  final List<String> images;
  final String? topicId;
  final bool isActive;

  LessonModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.content,
    this.mediaUrls = const [],
    required this.estimatedTimeMinutes,
    this.tags = const [],
    required this.order,
    required this.createdBy,
    required this.createdAt,
    this.summary = const {},
    this.sections = const [],
    this.formulas = const [],
    this.examples = const [],
    this.commonMistakes = const [],
    this.practiceQuestionIds = const [],
    this.videoUrl,
    this.pdfUrl,
    this.images = const [],
    this.topicId,
    this.isActive = true,
  });

  String getTitle(String locale) => pickLocalized(title, locale);
  String getContent(String locale) => pickLocalized(content, locale);
  String getSummary(String locale) => pickLocalized(summary, locale);

  /// True when the lesson carries any structured block.
  bool get hasStructuredContent =>
      summary.isNotEmpty ||
      sections.isNotEmpty ||
      formulas.isNotEmpty ||
      examples.isNotEmpty ||
      commonMistakes.isNotEmpty;

  /// Parses a lesson map. [id] is the document id and wins over a missing
  /// or empty `id` field.
  factory LessonModel.fromFirestore(Map<String, dynamic> data, {String? id}) {
    final lang = JsonRead.string(data, ['language', 'lang']) ?? 'ru';
    final dataId = JsonRead.string(data, ['id']);
    final media = JsonRead.stringList(data, ['mediaUrls', 'media_urls']);
    final video = JsonRead.string(data, ['video_url', 'videoUrl']);
    return LessonModel(
      id: (dataId == null || dataId.isEmpty) ? (id ?? '') : dataId,
      subjectId: JsonRead.stringOr(data, ['subject_id', 'subjectId']),
      title: JsonRead.localized(JsonRead.any(data, ['title', 'name']), defaultLang: lang),
      content: JsonRead.localized(JsonRead.any(data, ['content', 'body', 'text']), defaultLang: lang),
      mediaUrls: media,
      estimatedTimeMinutes: JsonRead.integer(data, [
            'estimatedTimeMinutes',
            'estimated_time_minutes',
            'estimatedTime',
            'duration_minutes',
          ]) ??
          15,
      tags: JsonRead.stringList(data, ['tags']),
      order: JsonRead.integer(data, ['order', 'position']) ?? 0,
      createdBy: JsonRead.stringOr(data, ['createdBy', 'created_by'], 'admin'),
      createdAt: JsonRead.date(data, ['createdAt', 'created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      summary: JsonRead.localized(JsonRead.any(data, ['summary']), defaultLang: lang),
      sections: _localizedItems(JsonRead.any(data, ['sections']), lang)
          .map(LessonSection.fromMaps)
          .where((s) => !s.isEmpty)
          .toList(),
      formulas: _formulas(JsonRead.any(data, ['formulas']), lang),
      examples: _localizedItems(JsonRead.any(data, ['examples']), lang)
          .map(LessonExample.fromMaps)
          .where((e) => !e.isEmpty)
          .toList(),
      commonMistakes: _localizedStrings(
          JsonRead.any(data, ['common_mistakes', 'commonMistakes']), lang),
      practiceQuestionIds: JsonRead.stringList(
          data, ['practice_question_ids', 'practiceQuestionIds', 'question_ids']),
      videoUrl: video ?? (media.isNotEmpty ? media.first : null),
      pdfUrl: JsonRead.string(data, ['pdf_url', 'pdfUrl']),
      images: JsonRead.stringList(data, ['images', 'image_urls']),
      topicId: JsonRead.string(data, ['topic_id', 'topicId']),
      isActive: JsonRead.boolean(data, ['is_active', 'isActive']) ?? true,
    );
  }

  /// Normalises a list field into a list of `{field: {lang: text}}` items.
  ///
  /// Accepts `[{title: {ru, ky}, body: {ru, ky}}]`, `[{title: "..", body: ".."}]`
  /// and `{ru: [{title, body}], ky: [{title, body}]}` (merged by index).
  static List<Map<String, Map<String, String>>> _localizedItems(Object? raw, String lang) {
    final out = <Map<String, Map<String, String>>>[];
    if (raw is List) {
      for (final e in raw) {
        final m = JsonRead.asMap(e);
        if (m == null) {
          if (e is String && e.isNotEmpty) out.add({'body': {lang: e}});
          continue;
        }
        out.add({
          for (final entry in m.entries)
            entry.key: JsonRead.localized(entry.value, defaultLang: lang),
        });
      }
      return out;
    }
    final byLang = JsonRead.asMap(raw);
    if (byLang != null) {
      for (final langEntry in byLang.entries) {
        final list = langEntry.value;
        if (list is! List) continue;
        final code = langEntry.key == 'kg' ? 'ky' : langEntry.key;
        for (var i = 0; i < list.length; i++) {
          while (out.length <= i) {
            out.add({});
          }
          final m = JsonRead.asMap(list[i]);
          if (m == null) {
            if (list[i] is String) {
              (out[i]['body'] ??= {})[code] = list[i] as String;
            }
            continue;
          }
          for (final f in m.entries) {
            if (f.value is String) (out[i][f.key] ??= {})[code] = f.value as String;
          }
        }
      }
    }
    return out;
  }

  static List<Map<String, String>> _localizedStrings(Object? raw, String lang) {
    return _localizedItems(raw, lang)
        .map((m) => m['body'] ?? m['text'] ?? m['title'] ?? const <String, String>{})
        .where((m) => m.isNotEmpty)
        .toList();
  }

  static List<LessonFormula> _formulas(Object? raw, String lang) {
    if (raw is List) {
      final out = <LessonFormula>[];
      for (final e in raw) {
        if (e is String && e.trim().isNotEmpty) {
          out.add(LessonFormula(latex: e.trim(), title: const {}));
          continue;
        }
        final m = JsonRead.asMap(e);
        if (m == null) continue;
        final latex = JsonRead.string(m, ['latex', 'formula', 'tex']);
        if (latex == null || latex.trim().isEmpty) continue;
        out.add(LessonFormula(
          latex: latex.trim(),
          title: JsonRead.localized(JsonRead.any(m, ['title', 'name', 'description']), defaultLang: lang),
        ));
      }
      return out;
    }
    return const [];
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      // Legacy key kept for existing readers; snake_case added (principle 4).
      'subjectId': subjectId,
      'subject_id': subjectId,
      'title': title,
      'content': content,
      'mediaUrls': mediaUrls,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'tags': tags,
      'order': order,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      if (summary.isNotEmpty) 'summary': summary,
      if (sections.isNotEmpty) 'sections': sections.map((s) => s.toMap()).toList(),
      if (formulas.isNotEmpty) 'formulas': formulas.map((f) => f.toMap()).toList(),
      if (examples.isNotEmpty) 'examples': examples.map((e) => e.toMap()).toList(),
      if (commonMistakes.isNotEmpty) 'common_mistakes': commonMistakes,
      if (practiceQuestionIds.isNotEmpty) 'practice_question_ids': practiceQuestionIds,
      if (videoUrl != null) 'video_url': videoUrl,
      if (pdfUrl != null) 'pdf_url': pdfUrl,
      if (images.isNotEmpty) 'images': images,
      if (topicId != null) 'topic_id': topicId,
    };
  }

  LessonModel copyWith({
    String? id,
    String? subjectId,
    Map<String, String>? title,
    Map<String, String>? content,
    List<String>? mediaUrls,
    int? estimatedTimeMinutes,
    List<String>? tags,
    int? order,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return LessonModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
      tags: tags ?? this.tags,
      order: order ?? this.order,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      summary: summary,
      sections: sections,
      formulas: formulas,
      examples: examples,
      commonMistakes: commonMistakes,
      practiceQuestionIds: practiceQuestionIds,
      videoUrl: videoUrl,
      pdfUrl: pdfUrl,
      images: images,
      topicId: topicId,
      isActive: isActive,
    );
  }
}

class LessonSection {
  final Map<String, String> title;
  final Map<String, String> body;
  const LessonSection({required this.title, required this.body});

  factory LessonSection.fromMaps(Map<String, Map<String, String>> m) => LessonSection(
        title: m['title'] ?? m['heading'] ?? const {},
        body: m['body'] ?? m['content'] ?? m['text'] ?? const {},
      );

  bool get isEmpty => title.isEmpty && body.isEmpty;
  Map<String, dynamic> toMap() => {'title': title, 'body': body};
}

class LessonFormula {
  final String latex;
  final Map<String, String> title;
  const LessonFormula({required this.latex, required this.title});
  Map<String, dynamic> toMap() => {'latex': latex, if (title.isNotEmpty) 'title': title};
}

class LessonExample {
  final Map<String, String> problem;
  final Map<String, String> solution;
  const LessonExample({required this.problem, required this.solution});

  factory LessonExample.fromMaps(Map<String, Map<String, String>> m) => LessonExample(
        problem: m['problem'] ?? m['question'] ?? m['title'] ?? const {},
        solution: m['solution'] ?? m['answer'] ?? m['body'] ?? const {},
      );

  bool get isEmpty => problem.isEmpty && solution.isEmpty;
  Map<String, dynamic> toMap() => {'problem': problem, 'solution': solution};
}
