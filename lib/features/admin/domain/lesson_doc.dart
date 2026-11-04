import 'exam_question.dart' show readDateTolerant;
import 'localized_text.dart';

/// Structured lesson stored in `lessons/{id}` (single lessons collection —
/// CMS-13/FB-21: the duplicate `daily_lessons` manager is gone).
///
/// Structured fields (snake_case):
/// `title{ru,ky}`, `summary{}`, `sections[{title{}, body{}}]` (Markdown +
/// LaTeX in `$...$`), `formulas[{latex, caption{}}]`,
/// `examples[{problem{}, solution{}}]`, `common_mistakes[{}]`,
/// `practice_question_ids[]` (ids in `questions`), `video_url`, `pdf_url`,
/// `images[]` (Storage paths `lesson_media/{lessonId}/...` or URLs),
/// `topic_id`, `is_published`.
///
/// Legacy mirrors kept for the current student `LessonModel.fromFirestore`
/// (which casts strictly): `id`, `subjectId`, `content{}` (generated from
/// summary + sections), `order` (int), `estimatedTimeMinutes`, `mediaUrls`,
/// `createdBy`, `createdAt` (ISO string — a Timestamp there would crash it).
///
/// CMS-12: localized maps are merged per locale on save, so translations the
/// editor did not touch survive.
class LessonSection {
  final Map<String, String> title;
  final Map<String, String> body;
  const LessonSection({this.title = const {}, this.body = const {}});

  factory LessonSection.fromMap(Object? raw) => raw is Map
      ? LessonSection(title: readLocalized(raw['title']), body: readLocalized(raw['body']))
      : const LessonSection();

  Map<String, dynamic> toMap() => {'title': title, 'body': body};
  bool get isEmpty => title.isEmpty && body.isEmpty;
}

class LessonFormula {
  final String latex;
  final Map<String, String> caption;
  const LessonFormula({this.latex = '', this.caption = const {}});

  factory LessonFormula.fromMap(Object? raw) {
    if (raw is String) return LessonFormula(latex: raw);
    if (raw is! Map) return const LessonFormula();
    return LessonFormula(
      latex: (raw['latex'] ?? raw['tex'] ?? '').toString(),
      caption: readLocalized(raw['caption'] ?? raw['description']),
    );
  }

  Map<String, dynamic> toMap() => {'latex': latex, 'caption': caption};
  bool get isEmpty => latex.trim().isEmpty && caption.isEmpty;
}

class LessonExample {
  final Map<String, String> problem;
  final Map<String, String> solution;
  const LessonExample({this.problem = const {}, this.solution = const {}});

  factory LessonExample.fromMap(Object? raw) => raw is Map
      ? LessonExample(
          problem: readLocalized(raw['problem'] ?? raw['question']),
          solution: readLocalized(raw['solution'] ?? raw['answer']),
        )
      : const LessonExample();

  Map<String, dynamic> toMap() => {'problem': problem, 'solution': solution};
  bool get isEmpty => problem.isEmpty && solution.isEmpty;
}

List<T> _list<T>(Object? raw, T Function(Object?) f) =>
    raw is List ? [for (final e in raw) f(e)] : <T>[];

List<String> _strings(Object? raw) => raw is List
    ? [
        for (final e in raw)
          if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
      ]
    : <String>[];

int _int(Object? v, int fallback) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

abstract final class LessonIssue {
  static const subjectRequired = 'subject_required';
  static const titleRequired = 'title_required';
  static const contentRequired = 'content_required';
  static const minutesRange = 'minutes_range';
  static const orderRange = 'order_range';
  static const urlInvalid = 'url_invalid';
}

bool isHttpUrl(String s) {
  final u = Uri.tryParse(s.trim());
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}

class LessonDoc {
  final String id;
  final String subjectId;
  final String? topicId;
  final int order;
  final int estimatedMinutes;
  final bool isPublished;
  final Map<String, String> title;
  final Map<String, String> summary;
  final List<LessonSection> sections;
  final List<LessonFormula> formulas;
  final List<LessonExample> examples;
  final List<Map<String, String>> commonMistakes;
  final List<String> practiceQuestionIds;
  final String? videoUrl;
  final String? pdfUrl;
  final List<String> images;

  /// The document as read (unknown and legacy fields survive a save).
  final Map<String, dynamic> raw;

  const LessonDoc({
    required this.id,
    required this.subjectId,
    this.topicId,
    this.order = 0,
    this.estimatedMinutes = 20,
    this.isPublished = true,
    this.title = const {},
    this.summary = const {},
    this.sections = const [],
    this.formulas = const [],
    this.examples = const [],
    this.commonMistakes = const [],
    this.practiceQuestionIds = const [],
    this.videoUrl,
    this.pdfUrl,
    this.images = const [],
    this.raw = const {},
  });

  factory LessonDoc.fromMap(String id, Map<String, dynamic> d) {
    var sections = _list(d['sections'], LessonSection.fromMap)
        .where((s) => !s.isEmpty)
        .toList();
    // Legacy lesson (only a `content` body): edit it as a single section so the
    // next save migrates it to the structured schema without losing text.
    if (sections.isEmpty) {
      final content = readLocalized(d['content']);
      if (content.isNotEmpty) sections = [LessonSection(body: content)];
    }
    final video = (d['video_url'] ?? d['videoUrl'])?.toString();
    final pdf = (d['pdf_url'] ?? d['pdfUrl'])?.toString();
    return LessonDoc(
      id: id,
      subjectId: (d['subject_id'] ?? d['subjectId'] ?? d['subject'] ?? '').toString(),
      topicId: (d['topic_id'] ?? d['topicId'])?.toString(),
      order: _int(d['order'], 0),
      estimatedMinutes:
          _int(d['estimatedTimeMinutes'] ?? d['estimated_minutes'] ?? d['estimatedMinutes'], 20),
      isPublished: (d['is_published'] ?? d['isPublished'] ?? true) == true,
      title: readLocalized(d['title']),
      summary: readLocalized(d['summary']),
      sections: sections,
      formulas: _list(d['formulas'], LessonFormula.fromMap).where((f) => !f.isEmpty).toList(),
      examples: _list(d['examples'], LessonExample.fromMap).where((e) => !e.isEmpty).toList(),
      commonMistakes: _list(d['common_mistakes'] ?? d['commonMistakes'], readLocalized)
          .where((m) => m.isNotEmpty)
          .toList(),
      practiceQuestionIds: _strings(d['practice_question_ids'] ?? d['practiceQuestionIds']),
      videoUrl: (video == null || video.isEmpty) ? null : video,
      pdfUrl: (pdf == null || pdf.isEmpty) ? null : pdf,
      images: _strings(d['images']),
      raw: d,
    );
  }

  LessonDoc copyWith({
    String? subjectId,
    String? topicId,
    bool clearTopic = false,
    int? order,
    int? estimatedMinutes,
    bool? isPublished,
    Map<String, String>? title,
    Map<String, String>? summary,
    List<LessonSection>? sections,
    List<LessonFormula>? formulas,
    List<LessonExample>? examples,
    List<Map<String, String>>? commonMistakes,
    List<String>? practiceQuestionIds,
    String? videoUrl,
    bool clearVideo = false,
    String? pdfUrl,
    bool clearPdf = false,
    List<String>? images,
  }) =>
      LessonDoc(
        id: id,
        subjectId: subjectId ?? this.subjectId,
        topicId: clearTopic ? null : (topicId ?? this.topicId),
        order: order ?? this.order,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        isPublished: isPublished ?? this.isPublished,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        sections: sections ?? this.sections,
        formulas: formulas ?? this.formulas,
        examples: examples ?? this.examples,
        commonMistakes: commonMistakes ?? this.commonMistakes,
        practiceQuestionIds: practiceQuestionIds ?? this.practiceQuestionIds,
        videoUrl: clearVideo ? null : (videoUrl ?? this.videoUrl),
        pdfUrl: clearPdf ? null : (pdfUrl ?? this.pdfUrl),
        images: images ?? this.images,
        raw: raw,
      );

  List<String> validate() {
    final issues = <String>[];
    if (subjectId.trim().isEmpty) issues.add(LessonIssue.subjectRequired);
    if ((title['ru'] ?? '').trim().isEmpty && (title['ky'] ?? '').trim().isEmpty) {
      issues.add(LessonIssue.titleRequired);
    }
    if (summary.isEmpty && sections.every((s) => s.body.isEmpty)) {
      issues.add(LessonIssue.contentRequired);
    }
    if (estimatedMinutes < 1 || estimatedMinutes > 240) issues.add(LessonIssue.minutesRange);
    if (order < 0 || order > 10000) issues.add(LessonIssue.orderRange);
    for (final u in [videoUrl, pdfUrl]) {
      if (u != null && u.isNotEmpty && !isHttpUrl(u) && !u.startsWith('lesson_media/')) {
        issues.add(LessonIssue.urlInvalid);
        break;
      }
    }
    return issues;
  }

  /// Markdown body per locale for the legacy `content` field.
  Map<String, String> legacyContent() {
    final locales = <String>{
      ...summary.keys,
      for (final s in sections) ...s.body.keys,
    };
    final out = <String, String>{};
    for (final l in locales) {
      final parts = <String>[];
      final sm = summary[l];
      if (sm != null && sm.trim().isNotEmpty) parts.add(sm.trim());
      for (final s in sections) {
        final b = s.body[l];
        if (b == null || b.trim().isEmpty) continue;
        final t = s.title[l];
        parts.add(t != null && t.trim().isNotEmpty ? '## ${t.trim()}\n\n${b.trim()}' : b.trim());
      }
      if (parts.isNotEmpty) out[l] = parts.join('\n\n');
    }
    // Never drop a legacy translation the structured fields do not cover.
    final legacy = readLocalized(raw['content']);
    legacy.forEach((k, v) => out.putIfAbsent(k, () => v));
    return out;
  }

  /// Fields to write (merged into the existing document by the repository).
  Map<String, dynamic> toWrite({required String actor, DateTime? now}) {
    final created = raw['createdAt'];
    final createdIso = created is String && DateTime.tryParse(created) != null
        ? created
        : (readDateTolerant(created) ?? readDateTolerant(raw['created_at']) ?? now ?? DateTime.now())
            .toUtc()
            .toIso8601String();
    final legacyMedia = raw['mediaUrls'];
    return {
      'id': id,
      'subjectId': subjectId,
      'subject_id': subjectId,
      'topic_id': topicId,
      'title': title,
      'summary': summary,
      'sections': [for (final s in sections) s.toMap()],
      'formulas': [for (final f in formulas) f.toMap()],
      'examples': [for (final e in examples) e.toMap()],
      'common_mistakes': commonMistakes,
      'practice_question_ids': practiceQuestionIds,
      'video_url': videoUrl,
      'pdf_url': pdfUrl,
      'images': images,
      'is_published': isPublished,
      'content': legacyContent(),
      'mediaUrls': legacyMedia is List
          ? legacyMedia
          : [for (final i in images) if (isHttpUrl(i)) i],
      'estimatedTimeMinutes': estimatedMinutes,
      'order': order,
      'createdBy': (raw['createdBy'] is String) ? raw['createdBy'] : actor,
      'createdAt': createdIso,
    };
  }
}
