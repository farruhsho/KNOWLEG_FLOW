import 'package:flutter/foundation.dart';

import 'exam_blueprint.dart';
import 'exam_question.dart';
import 'json_utils.dart';
import 'localized_text.dart';

/// Questions and timing of the section the server has opened.
@immutable
class SectionPayload {
  final String sectionId;

  /// Server deadline, epoch ms (server clock).
  final int deadlineAtMs;
  final int durationSec;
  final List<ExamQuestion> questions;
  final Map<String, ExamPassage> passages;

  const SectionPayload({
    required this.sectionId,
    required this.deadlineAtMs,
    required this.durationSec,
    required this.questions,
    this.passages = const {},
  });

  factory SectionPayload.fromJson(Object? json) {
    final m = asJsonMap(json);
    final passages = <String, ExamPassage>{};
    asJsonMap(m['passages']).forEach((id, p) {
      passages[id] = ExamPassage.fromJson(id, p);
    });
    return SectionPayload(
      sectionId: asString(pick(m, const ['sectionId', 'section_id'])) ?? '',
      deadlineAtMs:
          asEpochMs(pick(m, const ['deadlineAt', 'deadline_at'])) ?? 0,
      durationSec: asInt(pick(m, const ['durationSec', 'duration_sec'])) ?? 0,
      questions: asJsonList(m['questions'])
          .map(ExamQuestion.fromJson)
          .where((q) => q.id.isNotEmpty)
          .toList(growable: false),
      passages: Map.unmodifiable(passages),
    );
  }

  Map<String, dynamic> toJson() => {
        'sectionId': sectionId,
        'deadlineAt': deadlineAtMs,
        'durationSec': durationSec,
        'questions': questions.map((q) => q.toJson()).toList(),
        'passages': passages.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// `ExamSessionPayload` returned by `examStart` / `examGetState` /
/// `examSubmitSection.next` (ARCHITECTURE §3).
@immutable
class ExamSessionPayload {
  final String attemptId;
  final String variantId;
  final ExamBlueprint? blueprint;
  final String? blueprintId;
  final String status;
  final int currentSectionIndex;
  final SectionPayload? section;
  final int serverNowMs;
  final String? entitlementSource;
  final String? language;
  final LocalizedText variantTitle;

  /// Present when `examGetState` is called for an already completed attempt.
  final ExamResult? result;

  const ExamSessionPayload({
    required this.attemptId,
    required this.variantId,
    required this.blueprint,
    required this.status,
    required this.currentSectionIndex,
    required this.section,
    required this.serverNowMs,
    this.blueprintId,
    this.entitlementSource,
    this.language,
    this.variantTitle = LocalizedText.empty,
    this.result,
  });

  bool get isCompleted => status == 'completed' || status == 'expired';

  factory ExamSessionPayload.fromJson(Object? json) {
    final m = asJsonMap(json);
    final bp = m['blueprint'];
    final blueprint = bp is Map ? ExamBlueprint.fromJson(bp) : null;
    final sec = m['section'];
    final res = m['result'];
    return ExamSessionPayload(
      attemptId: asString(pick(m, const ['attemptId', 'attempt_id'])) ?? '',
      variantId: asString(pick(m, const ['variantId', 'variant_id'])) ?? '',
      blueprint: blueprint,
      blueprintId: asString(pick(m, const ['blueprintId', 'blueprint_id'])) ??
          blueprint?.id,
      status: asString(m['status']) ?? 'in_progress',
      currentSectionIndex:
          asInt(pick(m, const ['currentSectionIndex', 'current_section_index'])) ??
              0,
      section: sec is Map ? SectionPayload.fromJson(sec) : null,
      serverNowMs: asEpochMs(pick(m, const ['serverNow', 'server_now'])) ??
          DateTime.now().millisecondsSinceEpoch,
      entitlementSource:
          asString(pick(m, const ['entitlementSource', 'entitlement_source'])),
      language: asString(m['language']),
      variantTitle:
          LocalizedText.fromJson(pick(m, const ['variantTitle', 'variant_title'])),
      result: res is Map ? ExamResult.fromJson(res) : null,
    );
  }
}

@immutable
class SectionScore {
  final String sectionId;
  final int correct;
  final int total;
  final double percent;

  const SectionScore({
    required this.sectionId,
    required this.correct,
    required this.total,
    required this.percent,
  });

  factory SectionScore.fromJson(Object? json) {
    final m = asJsonMap(json);
    final correct = asInt(m['correct']) ?? 0;
    final total = asInt(m['total']) ?? 0;
    return SectionScore(
      sectionId: asString(pick(m, const ['section_id', 'sectionId'])) ?? '',
      correct: correct,
      total: total,
      percent: asDouble(m['percent']) ??
          (total == 0 ? 0 : correct * 100 / total),
    );
  }

  Map<String, dynamic> toJson() => {
        'section_id': sectionId,
        'correct': correct,
        'total': total,
        'percent': percent,
      };
}

@immutable
class TopicScore {
  final String topicId;
  final int correct;
  final int total;
  final LocalizedText title;

  const TopicScore({
    required this.topicId,
    required this.correct,
    required this.total,
    this.title = LocalizedText.empty,
  });

  double get percent => total == 0 ? 0 : correct * 100 / total;

  factory TopicScore.fromJson(Object? json) {
    final m = asJsonMap(json);
    return TopicScore(
      topicId: asString(pick(m, const ['topic_id', 'topicId'])) ?? '',
      correct: asInt(m['correct']) ?? 0,
      total: asInt(m['total']) ?? 0,
      title: LocalizedText.fromJson(m['title']),
    );
  }

  Map<String, dynamic> toJson() => {
        'topic_id': topicId,
        'correct': correct,
        'total': total,
        if (!title.isEmpty) 'title': title.toJson(),
      };
}

/// Server-computed result of a completed attempt (ARCHITECTURE §1.4). The
/// client never computes scores or XP itself.
@immutable
class ExamResult {
  final int correct;
  final int total;
  final double percent;

  /// Optional — only when the server reports them.
  final int? incorrect;
  final int? skipped;
  final List<SectionScore> sections;
  final List<TopicScore> topics;
  final List<String> weakTopics;
  final List<String> strongTopics;
  final int xpAwarded;
  final bool leaderboardEligible;
  final String disclaimerKey;

  const ExamResult({
    required this.correct,
    required this.total,
    required this.percent,
    this.incorrect,
    this.skipped,
    this.sections = const [],
    this.topics = const [],
    this.weakTopics = const [],
    this.strongTopics = const [],
    this.xpAwarded = 0,
    this.leaderboardEligible = true,
    this.disclaimerKey = 'exam_result_unofficial',
  });

  factory ExamResult.fromJson(Object? json) {
    final m = asJsonMap(json);
    final correct = asInt(m['correct']) ?? 0;
    final total = asInt(m['total']) ?? 0;
    return ExamResult(
      correct: correct,
      total: total,
      percent:
          asDouble(m['percent']) ?? (total == 0 ? 0 : correct * 100 / total),
      incorrect: asInt(pick(m, const ['incorrect', 'wrong'])),
      skipped: asInt(pick(m, const ['skipped', 'unanswered'])),
      sections: asJsonList(m['sections'])
          .map(SectionScore.fromJson)
          .toList(growable: false),
      topics:
          asJsonList(m['topics']).map(TopicScore.fromJson).toList(growable: false),
      weakTopics: asStringList(pick(m, const ['weak_topics', 'weakTopics'])),
      strongTopics:
          asStringList(pick(m, const ['strong_topics', 'strongTopics'])),
      xpAwarded: asInt(pick(m, const ['xp_awarded', 'xpAwarded'])) ?? 0,
      leaderboardEligible: asBool(
          pick(m, const ['leaderboard_eligible', 'leaderboardEligible']),
          fallback: true),
      disclaimerKey: asString(pick(m, const ['disclaimer_key', 'disclaimerKey'])) ??
          'exam_result_unofficial',
    );
  }

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'total': total,
        'percent': percent,
        if (incorrect != null) 'incorrect': incorrect,
        if (skipped != null) 'skipped': skipped,
        'sections': sections.map((s) => s.toJson()).toList(),
        'topics': topics.map((t) => t.toJson()).toList(),
        'weak_topics': weakTopics,
        'strong_topics': strongTopics,
        'xp_awarded': xpAwarded,
        'leaderboard_eligible': leaderboardEligible,
        'disclaimer_key': disclaimerKey,
      };

  TopicScore? topic(String id) {
    for (final t in topics) {
      if (t.topicId == id) return t;
    }
    return null;
  }
}

/// Response of `examSubmitSection`.
@immutable
class SubmitSectionResponse {
  final bool completed;
  final ExamSessionPayload? next;
  final ExamResult? result;

  const SubmitSectionResponse({required this.completed, this.next, this.result});

  factory SubmitSectionResponse.fromJson(Object? json) {
    final m = asJsonMap(json);
    final next = m['next'];
    final result = m['result'];
    return SubmitSectionResponse(
      completed: asBool(m['completed']),
      next: next is Map ? ExamSessionPayload.fromJson(next) : null,
      result: result is Map ? ExamResult.fromJson(result) : null,
    );
  }
}

/// One item of `examGetReview` (only for completed attempts).
@immutable
class ReviewItem {
  final String questionId;
  final String sectionId;
  final String stem;
  final List<QuestionOption> options;
  final ExamPassage? passage;
  final String? userAnswer;
  final String? correct;
  final String explanation;
  final String? topicId;
  final String? imageUrl;
  final QuestionTable? table;
  final bool? flagged;

  const ReviewItem({
    required this.questionId,
    required this.sectionId,
    required this.stem,
    required this.options,
    required this.userAnswer,
    required this.correct,
    required this.explanation,
    this.passage,
    this.topicId,
    this.imageUrl,
    this.table,
    this.flagged,
  });

  bool get isSkipped => userAnswer == null || userAnswer!.isEmpty;
  bool get isCorrect => !isSkipped && userAnswer == correct;
  bool get isWrong => !isCorrect;

  factory ReviewItem.fromJson(Object? json) {
    final m = asJsonMap(json);
    final options = asJsonList(m['options']);
    final p = m['passage'];
    final qid = asString(pick(m, const ['questionId', 'question_id', 'id'])) ?? '';
    return ReviewItem(
      questionId: qid,
      sectionId: asString(pick(m, const ['sectionId', 'section_id'])) ?? '',
      stem: asString(m['stem']) ?? '',
      options: [
        for (var i = 0; i < options.length; i++)
          QuestionOption.fromJson(options[i], i),
      ],
      passage: p == null
          ? null
          : ExamPassage.fromJson(
              asString(asJsonMap(p)['id']) ?? 'p_$qid', p),
      userAnswer: asString(pick(m, const ['userAnswer', 'user_answer'])),
      correct: asString(pick(m, const ['correct', 'correctAnswer'])),
      explanation: asString(m['explanation']) ?? '',
      topicId: asString(pick(m, const ['topicId', 'topic_id'])),
      imageUrl: asString(pick(m, const ['imageUrl', 'image_url'])),
      table: QuestionTable.fromJson(m['table']),
      flagged: m['flagged'] is bool ? m['flagged'] as bool : null,
    );
  }
}
