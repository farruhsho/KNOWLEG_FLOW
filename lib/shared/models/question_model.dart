import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../core/utils/content_locale.dart';
import '../../core/utils/json_read.dart';

/// Practice question from the legacy `questions` collection.
///
/// Parsing is deliberately tolerant: documents were written by several
/// generations of admin code and by hand in the console, so both snake_case
/// (canonical, ARCHITECTURE.md principle 4) and camelCase keys are accepted.
/// A question without a usable answer key is **not** silently graded with
/// 'A' any more — [isGradable] is false and practice skips it (FB-05).
class QuestionModel extends Equatable {
  final String id;
  final String subjectId;
  final String sectionId; // ORT section (math, verbal, reading, grammar, …)
  final String? topicId;
  final String? lessonId;

  // Multi-language content
  final Map<String, String> stem; // Question text (Markdown + $LaTeX$)
  final List<OptionModel> options;
  final String correctAnswer; // Option id; '' when the document has no key
  final List<String>? correctAnswers; // For multiple choice

  // Question properties
  final QuestionType type;
  final int difficulty; // 1-3
  final int points; // Points for correct answer

  // Media
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final List<String>? attachments;

  // Explanation
  final Map<String, String> explanation;
  final Map<String, String>? hint;
  final String? solutionVideoUrl;

  // Metadata
  final List<String> tags;
  final String? source; // Where question came from
  final bool isAiGenerated;
  final bool isVerified;
  final bool isActive;

  // Statistics
  final QuestionStats? stats;

  // Audit
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;

  // Legacy support
  final String category; // 'main', 'subject', 'language' for ORT sections
  final List<double>? embedding; // Vector embedding for duplicate detection

  const QuestionModel({
    required this.id,
    required this.subjectId,
    required this.sectionId,
    this.topicId,
    this.lessonId,
    required this.stem,
    required this.options,
    required this.correctAnswer,
    this.correctAnswers,
    required this.type,
    required this.difficulty,
    this.points = 1,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    this.attachments,
    required this.explanation,
    this.hint,
    this.solutionVideoUrl,
    this.tags = const [],
    this.source,
    this.isAiGenerated = false,
    this.isVerified = false,
    this.isActive = true,
    this.stats,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    this.category = 'subject',
    this.embedding,
  });

  /// Parses a Firestore document. Never throws on odd field types; a missing
  /// answer key yields `correctAnswer == ''` (see [isGradable]).
  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = JsonRead.asMap(raw) ?? const <String, dynamic>{};
    return QuestionModel.fromMap(doc.id, data);
  }

  /// Returns null for documents that cannot be graded (no data, no answer
  /// key, fewer than two options, or a key that matches no option).
  static QuestionModel? tryFromFirestore(DocumentSnapshot doc) {
    try {
      final q = QuestionModel.fromFirestore(doc);
      return q.isGradable ? q : null;
    } catch (_) {
      return null;
    }
  }

  /// Shared tolerant parser for Firestore maps and JSON exports.
  factory QuestionModel.fromMap(String id, Map<String, dynamic> data) {
    final language = JsonRead.string(data, ['language', 'lang']) ?? 'ru';
    final options = OptionModel.listFrom(
      JsonRead.any(data, ['options', 'answers', 'choices']),
      defaultLang: language,
    );
    final now = DateTime.now();
    return QuestionModel(
      id: JsonRead.string(data, ['id']) ?? id,
      subjectId: JsonRead.stringOr(data, ['subject_id', 'subjectId', 'subject']),
      sectionId: JsonRead.stringOr(data, ['section_id', 'sectionId', 'section']),
      topicId: JsonRead.string(data, ['topic_id', 'topicId', 'topic']),
      lessonId: JsonRead.string(data, ['lesson_id', 'lessonId']),
      stem: JsonRead.localized(
        JsonRead.any(data, ['stem', 'question', 'question_text', 'text']),
        defaultLang: language,
      ),
      options: options,
      correctAnswer: _parseCorrectAnswer(data, options),
      correctAnswers: () {
        final list = JsonRead.stringList(data, ['correct_answers', 'correctAnswers']);
        return list.isEmpty ? null : list;
      }(),
      type: QuestionTypeX.parse(JsonRead.string(data, ['type', 'item_type', 'itemType'])),
      difficulty: normalizeDifficulty(JsonRead.integer(data, ['difficulty', 'level'])),
      points: (JsonRead.integer(data, ['points', 'points_per_question']) ?? 1).clamp(1, 10),
      imageUrl: JsonRead.string(data, ['image_url', 'imageUrl', 'image_path', 'imagePath']),
      videoUrl: JsonRead.string(data, ['video_url', 'videoUrl']),
      audioUrl: JsonRead.string(data, ['audio_url', 'audioUrl']),
      attachments: () {
        final list = JsonRead.stringList(data, ['attachments']);
        return list.isEmpty ? null : list;
      }(),
      explanation: JsonRead.localized(
        JsonRead.any(data, ['explanation', 'explanations', 'solution']),
        defaultLang: language,
      ),
      hint: () {
        final h = JsonRead.localized(JsonRead.any(data, ['hint']), defaultLang: language);
        return h.isEmpty ? null : h;
      }(),
      solutionVideoUrl: JsonRead.string(data, ['solution_video_url', 'solutionVideoUrl']),
      tags: JsonRead.stringList(data, ['tags']),
      source: JsonRead.string(data, ['source']) ??
          JsonRead.string(JsonRead.map(data, ['source']) ?? const {}, ['kind']),
      isAiGenerated: JsonRead.boolean(data, ['is_ai_generated', 'isAiGenerated']) ?? false,
      isVerified: JsonRead.boolean(data, ['is_verified', 'isVerified']) ?? false,
      isActive: JsonRead.boolean(data, ['is_active', 'isActive']) ?? true,
      stats: () {
        final s = JsonRead.map(data, ['stats']);
        return s == null ? null : QuestionStats.fromMap(s);
      }(),
      createdAt: JsonRead.date(data, ['created_at', 'createdAt']) ?? now,
      updatedAt: JsonRead.date(data, ['updated_at', 'updatedAt']) ?? now,
      createdBy: JsonRead.stringOr(data, ['created_by', 'createdBy']),
      updatedBy: JsonRead.string(data, ['updated_by', 'updatedBy']),
      category: JsonRead.stringOr(data, ['category'], 'subject'),
      embedding: () {
        final e = JsonRead.any(data, ['embedding']);
        if (e is! List) return null;
        return e.whereType<num>().map((n) => n.toDouble()).toList();
      }(),
    );
  }

  /// Difficulty is a 1–3 scale (1 easy, 2 medium, 3 hard). Legacy documents
  /// used 1–5; anything out of range is clamped (EXAM-16).
  static int normalizeDifficulty(int? raw) => (raw ?? 1).clamp(1, 3);

  static String _parseCorrectAnswer(Map<String, dynamic> data, List<OptionModel> options) {
    final v = JsonRead.any(data, ['correct_answer', 'correctAnswer', 'correct', 'answer', 'correct_option', 'correctOption']);
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is int && v >= 0 && v < options.length) return options[v].id;
    // Admin-style options carrying an is_correct flag.
    final raw = JsonRead.any(data, ['options', 'answers', 'choices']);
    if (raw is List) {
      for (var i = 0; i < raw.length && i < options.length; i++) {
        final m = JsonRead.asMap(raw[i]);
        if (m != null && (JsonRead.boolean(m, ['is_correct', 'isCorrect', 'correct']) ?? false)) {
          return options[i].id;
        }
      }
    }
    return '';
  }

  /// True when the question can be shown and graded honestly.
  bool get isGradable =>
      correctAnswer.isNotEmpty &&
      options.length >= 2 &&
      options.any((o) => o.id == correctAnswer) &&
      stem.values.any((s) => s.trim().isNotEmpty);

  Map<String, dynamic> toFirestore() {
    return {
      'subject_id': subjectId,
      'section_id': sectionId,
      'topic_id': topicId,
      'lesson_id': lessonId,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correct_answer': correctAnswer,
      'correct_answers': correctAnswers,
      // Canonical snake_case; the parser also reads camelCase (EXAM-13).
      'type': type.wireName,
      'difficulty': difficulty,
      'points': points,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'audio_url': audioUrl,
      'attachments': attachments,
      'explanation': explanation,
      'hint': hint,
      'solution_video_url': solutionVideoUrl,
      'tags': tags,
      'source': source,
      'is_ai_generated': isAiGenerated,
      'is_verified': isVerified,
      'is_active': isActive,
      'stats': stats?.toMap(),
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'category': category,
      'embedding': embedding,
    };
  }

  // JSON serialization for export/import (camelCase keys, ISO dates).
  factory QuestionModel.fromJson(Map<String, dynamic> json) =>
      QuestionModel.fromMap(JsonRead.stringOr(json, ['id']), json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'sectionId': sectionId,
      'topicId': topicId,
      'lessonId': lessonId,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correctAnswer': correctAnswer,
      'correctAnswers': correctAnswers,
      'type': type.wireName,
      'difficulty': difficulty,
      'points': points,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'attachments': attachments,
      'explanation': explanation,
      'hint': hint,
      'solutionVideoUrl': solutionVideoUrl,
      'tags': tags,
      'source': source,
      'isAiGenerated': isAiGenerated,
      'isVerified': isVerified,
      'isActive': isActive,
      'stats': stats?.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'category': category,
      'embedding': embedding,
    };
  }

  /// Localized stem: [locale] → ru → ky → en.
  String getStem(String locale) => pickLocalized(stem, locale);

  /// Localized explanation ('' when the question has none).
  String getExplanation(String locale) =>
      explanation.isEmpty ? '' : pickLocalized(explanation, locale);

  /// Localized hint.
  String? getHint(String locale) {
    final h = hint;
    if (h == null || h.isEmpty) return null;
    return pickLocalized(h, locale);
  }

  /// Get correct percentage from stats
  double get correctPercentage {
    if (stats == null || stats!.totalAttempts == 0) return 0;
    return stats!.percentageCorrect;
  }

  /// Check if question is problematic (low success rate)
  bool get isProblematic => stats != null && stats!.isProblematic;

  /// Copy with modifications
  QuestionModel copyWith({
    String? id,
    String? subjectId,
    String? sectionId,
    String? topicId,
    String? lessonId,
    Map<String, String>? stem,
    List<OptionModel>? options,
    String? correctAnswer,
    List<String>? correctAnswers,
    QuestionType? type,
    int? difficulty,
    int? points,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<String>? attachments,
    Map<String, String>? explanation,
    Map<String, String>? hint,
    String? solutionVideoUrl,
    List<String>? tags,
    String? source,
    bool? isAiGenerated,
    bool? isVerified,
    bool? isActive,
    QuestionStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? category,
    List<double>? embedding,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      sectionId: sectionId ?? this.sectionId,
      topicId: topicId ?? this.topicId,
      lessonId: lessonId ?? this.lessonId,
      stem: stem ?? this.stem,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      attachments: attachments ?? this.attachments,
      explanation: explanation ?? this.explanation,
      hint: hint ?? this.hint,
      solutionVideoUrl: solutionVideoUrl ?? this.solutionVideoUrl,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      category: category ?? this.category,
      embedding: embedding ?? this.embedding,
    );
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        sectionId,
        topicId,
        lessonId,
        stem,
        options,
        correctAnswer,
        correctAnswers,
        type,
        difficulty,
        points,
        imageUrl,
        videoUrl,
        audioUrl,
        attachments,
        explanation,
        hint,
        solutionVideoUrl,
        tags,
        source,
        isAiGenerated,
        isVerified,
        isActive,
        stats,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
        category,
        embedding,
      ];
}

class OptionModel extends Equatable {
  final String id; // 'A', 'B', 'C', 'D', 'E'
  final Map<String, String> text;

  const OptionModel({
    required this.id,
    required this.text,
  });

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  factory OptionModel.fromMap(Map<String, dynamic> map, {int index = 0, String defaultLang = 'ru'}) {
    final id = JsonRead.string(map, ['id', 'key', 'letter', 'label']);
    return OptionModel(
      id: (id == null || id.isEmpty)
          ? (index < _letters.length ? _letters[index] : '${index + 1}')
          : id,
      text: JsonRead.localized(JsonRead.any(map, ['text', 'value', 'content']), defaultLang: defaultLang),
    );
  }

  /// Parses an options array made of maps or plain strings.
  static List<OptionModel> listFrom(Object? raw, {String defaultLang = 'ru'}) {
    if (raw is! List) return const [];
    final out = <OptionModel>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      final m = JsonRead.asMap(e);
      if (m != null) {
        out.add(OptionModel.fromMap(m, index: i, defaultLang: defaultLang));
      } else if (e is String) {
        out.add(OptionModel(
          id: i < _letters.length ? _letters[i] : '${i + 1}',
          text: {defaultLang: e},
        ));
      }
    }
    return out;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
    };
  }

  /// Localized option text: [locale] → ru → ky → en.
  String getText(String locale) => pickLocalized(text, locale);

  @override
  List<Object?> get props => [id, text];
}

/// Question types enum
enum QuestionType {
  singleChoice, // Standard A-E choice
  multipleChoice, // Multiple correct answers
  analogy, // A:B = C:?
  completion, // Fill in blank
  matching, // Match pairs
  ordering, // Put in order
  trueFalse, // True/False
  textBased, // Based on reading passage
  quantitativeComparison, // ORT math part I: compare column A and B
}

extension QuestionTypeX on QuestionType {
  /// Canonical snake_case name stored in Firestore.
  String get wireName {
    switch (this) {
      case QuestionType.singleChoice:
        return 'single_choice';
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.analogy:
        return 'analogy';
      case QuestionType.completion:
        return 'completion';
      case QuestionType.matching:
        return 'matching';
      case QuestionType.ordering:
        return 'ordering';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.textBased:
        return 'text_based';
      case QuestionType.quantitativeComparison:
        return 'quantitative_comparison';
    }
  }

  /// Parses snake_case, camelCase, `QuestionType.x` and legacy aliases.
  /// Unknown or missing values fall back to single choice.
  static QuestionType parse(String? raw) {
    if (raw == null) return QuestionType.singleChoice;
    var s = raw.trim();
    if (s.startsWith('QuestionType.')) s = s.substring('QuestionType.'.length);
    // Normalise camelCase / kebab-case to snake_case.
    s = s
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .replaceAll('-', '_')
        .toLowerCase();
    switch (s) {
      case 'single_choice':
      case 'single':
      case 'mcq':
        return QuestionType.singleChoice;
      case 'multiple_choice':
      case 'multiple':
        return QuestionType.multipleChoice;
      case 'analogy':
      case 'analogies':
        return QuestionType.analogy;
      case 'completion':
      case 'sentence_completion':
      case 'fill_blank':
      case 'fill_in':
      case 'fill':
        return QuestionType.completion;
      case 'matching':
        return QuestionType.matching;
      case 'ordering':
        return QuestionType.ordering;
      case 'true_false':
      case 'tf':
        return QuestionType.trueFalse;
      case 'text_based':
      case 'reading':
        return QuestionType.textBased;
      case 'quantitative_comparison':
      case 'comparison':
        return QuestionType.quantitativeComparison;
      default:
        return QuestionType.singleChoice;
    }
  }
}

/// Question statistics model
class QuestionStats extends Equatable {
  final int totalAttempts;
  final int correctAttempts;
  final double avgTimeSeconds;
  final Map<String, int> answerDistribution;
  final DateTime? lastAttemptAt;

  const QuestionStats({
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.avgTimeSeconds = 0,
    this.answerDistribution = const {},
    this.lastAttemptAt,
  });

  /// Calculate success rate
  double get successRate =>
      totalAttempts > 0 ? correctAttempts / totalAttempts : 0;

  /// Get percentage correct
  double get percentageCorrect => successRate * 100;

  /// Check if question is problematic (low success rate)
  bool get isProblematic => percentageCorrect < 30 && totalAttempts > 10;

  factory QuestionStats.fromMap(Map<String, dynamic> map) {
    final dist = JsonRead.map(map, ['answer_distribution', 'answerDistribution']) ?? const {};
    return QuestionStats(
      totalAttempts: JsonRead.intOr(map, ['total_attempts', 'totalAttempts'], 0),
      correctAttempts: JsonRead.intOr(map, ['correct_attempts', 'correctAttempts'], 0),
      avgTimeSeconds: JsonRead.decimal(map, ['avg_time_seconds', 'avgTimeSeconds']) ?? 0,
      answerDistribution: {
        for (final e in dist.entries)
          if (JsonRead.toInt(e.value) != null) e.key: JsonRead.toInt(e.value)!,
      },
      lastAttemptAt: JsonRead.date(map, ['last_attempt_at', 'lastAttemptAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_attempts': totalAttempts,
      'correct_attempts': correctAttempts,
      'avg_time_seconds': avgTimeSeconds,
      'answer_distribution': answerDistribution,
      'last_attempt_at':
          lastAttemptAt != null ? Timestamp.fromDate(lastAttemptAt!) : null,
    };
  }

  /// Create a copy with updated values
  QuestionStats copyWith({
    int? totalAttempts,
    int? correctAttempts,
    double? avgTimeSeconds,
    Map<String, int>? answerDistribution,
    DateTime? lastAttemptAt,
  }) {
    return QuestionStats(
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctAttempts: correctAttempts ?? this.correctAttempts,
      avgTimeSeconds: avgTimeSeconds ?? this.avgTimeSeconds,
      answerDistribution: answerDistribution ?? this.answerDistribution,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  @override
  List<Object?> get props => [
        totalAttempts,
        correctAttempts,
        avgTimeSeconds,
        answerDistribution,
        lastAttemptAt,
      ];
}
