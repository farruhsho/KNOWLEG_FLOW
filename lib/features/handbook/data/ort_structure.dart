import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/utils/content_locale.dart';
import '../../../core/utils/json_read.dart';
import '../../../l10n/app_localizations.dart';

class OrtSectionFact {
  final String id;
  final Map<String, String> title;
  final int questions;
  final int minutes;
  final List<OrtPartFact> parts;
  const OrtSectionFact(this.id, this.title, this.questions, this.minutes, this.parts);
}

class OrtPartFact {
  final Map<String, String> title;
  final int questions;
  final int options;
  final bool verified;
  const OrtPartFact(this.title, this.questions, this.options, this.verified);
}

class OrtSubjectFact {
  final String subjectId;
  final Map<String, String> title;
  final int questions;
  final int minutes;
  const OrtSubjectFact(this.subjectId, this.title, this.questions, this.minutes);
}

/// ORT structure facts read from `assets/data/exam_blueprints.json` — the
/// single verified source — instead of hand-written handbook text (CMS-08).
class OrtStructureFacts {
  final int examYear;
  final List<OrtSectionFact> mainSections;
  final List<OrtSubjectFact> subjectTests;
  final OrtSubjectFact? stateLanguage;
  final int? officialMaxScore;
  final int? thresholdUniversity;
  final int? thresholdSubjectTests;
  final int? thresholdCollege;
  final Map<String, String> disclaimer;
  final String? sourceUrl;

  const OrtStructureFacts({
    required this.examYear,
    required this.mainSections,
    required this.subjectTests,
    this.stateLanguage,
    this.officialMaxScore,
    this.thresholdUniversity,
    this.thresholdSubjectTests,
    this.thresholdCollege,
    this.disclaimer = const {},
    this.sourceUrl,
  });

  int get mainQuestions => mainSections.fold(0, (s, x) => s + x.questions);
  int get mainMinutes => mainSections.fold(0, (s, x) => s + x.minutes);

  static const assetPath = 'assets/data/exam_blueprints.json';

  static Future<OrtStructureFacts> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return parse(jsonDecode(raw));
  }

  /// Parses the blueprint file (an object with `blueprints` or a bare list).
  static OrtStructureFacts parse(Object? json) {
    final list = json is List ? json : (JsonRead.asMap(json)?['blueprints'] as List? ?? const []);
    final blueprints = list.map(JsonRead.asMap).whereType<Map<String, dynamic>>().where((b) {
      final status = JsonRead.string(b, ['status']);
      return status == null || status == 'active';
    }).toList();

    Map<String, dynamic>? main;
    final subjects = <OrtSubjectFact>[];
    OrtSubjectFact? state;
    for (final b in blueprints) {
      final kind = JsonRead.string(b, ['kind']);
      final sections = (b['sections'] as List? ?? const []).map(JsonRead.asMap).whereType<Map<String, dynamic>>().toList();
      if (kind == 'main') {
        main = b;
      } else if (sections.isNotEmpty) {
        final s = sections.first;
        final fact = OrtSubjectFact(
          JsonRead.stringOr(b, ['subject_id']),
          JsonRead.localized(b['title']),
          JsonRead.intOr(s, ['question_count'], 0),
          JsonRead.intOr(s, ['duration_minutes'], 0),
        );
        if (kind == 'state_language') {
          state = fact;
        } else if (kind == 'subject') {
          subjects.add(fact);
        }
      }
    }

    final mainSections = <OrtSectionFact>[];
    if (main != null) {
      final sections = (main['sections'] as List? ?? const []).map(JsonRead.asMap).whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) => JsonRead.intOr(a, ['order'], 0).compareTo(JsonRead.intOr(b, ['order'], 0)));
      for (final s in sections) {
        final parts = (s['parts'] as List? ?? const []).map(JsonRead.asMap).whereType<Map<String, dynamic>>().map((p) => OrtPartFact(
              JsonRead.localized(p['title']),
              JsonRead.intOr(p, ['question_count'], 0),
              JsonRead.intOr(p, ['options_per_question'], 0),
              JsonRead.boolean(p, ['verified']) ?? false,
            ));
        mainSections.add(OrtSectionFact(
          JsonRead.stringOr(s, ['id']),
          JsonRead.localized(s['title']),
          JsonRead.intOr(s, ['question_count'], 0),
          JsonRead.intOr(s, ['duration_minutes'], 0),
          parts.toList(),
        ));
      }
    }
    final ref = JsonRead.map(main ?? const {}, ['reference']) ?? const {};
    final thresholds = JsonRead.map(ref, ['thresholds_2026_27', 'thresholds']) ?? const {};
    final uni = JsonRead.map(thresholds, ['university']) ?? const {};
    final college = JsonRead.map(thresholds, ['college']) ?? const {};
    final scoring = JsonRead.map(main ?? const {}, ['scoring']) ?? const {};
    final source = JsonRead.map(main ?? const {}, ['source']) ?? const {};
    return OrtStructureFacts(
      examYear: JsonRead.intOr(main ?? const {}, ['exam_year'], 0),
      mainSections: mainSections,
      subjectTests: subjects,
      stateLanguage: state,
      officialMaxScore: JsonRead.integer(ref, ['official_max_score']),
      thresholdUniversity: JsonRead.integer(uni, ['general']),
      thresholdSubjectTests: JsonRead.integer(uni, ['subject_tests']),
      thresholdCollege: JsonRead.integer(college, ['general']),
      disclaimer: JsonRead.localized(scoring['disclaimer']),
      sourceUrl: JsonRead.string(source, ['url']),
    );
  }

  /// "Структура экзамена" section as Markdown, in [lang].
  String structureMarkdown(AppLocalizations l, String lang) {
    final b = StringBuffer()
      ..writeln('**${l.learnHbMainTest('$examYear')}**')
      ..writeln();
    for (final s in mainSections) {
      b.writeln('- ${l.learnHbSectionLine(pickLocalized(s.title, lang), s.questions, s.minutes)}');
      for (final p in s.parts.where((p) => s.parts.length > 1)) {
        final note = p.verified ? '' : ' ${l.learnHbAssumption}';
        b.writeln('- — ${l.learnHbPartLine(pickLocalized(p.title, lang), p.questions, p.options)}$note');
      }
    }
    b
      ..writeln()
      ..writeln(l.learnHbMainTotal(mainQuestions, mainMinutes))
      ..writeln()
      ..writeln('**${l.learnHbSubjectTests}**')
      ..writeln();
    for (final s in subjectTests) {
      b.writeln('- ${l.learnHbSectionLine(pickLocalized(s.title, lang), s.questions, s.minutes)}');
    }
    final st = stateLanguage;
    if (st != null) {
      b
        ..writeln()
        ..writeln('**${pickLocalized(st.title, lang)}**')
        ..writeln()
        ..writeln(l.learnHbStateLanguage(st.questions, st.minutes));
    }
    return b.toString().trim();
  }

  /// "Система оценивания" section as Markdown, in [lang].
  String scoringMarkdown(AppLocalizations l, String lang) {
    final b = StringBuffer();
    if (officialMaxScore != null) b.writeln('- ${l.learnHbMaxScore(officialMaxScore!)}');
    if (thresholdUniversity != null && thresholdSubjectTests != null) {
      b.writeln('- ${l.learnHbThresholdsUniversity(thresholdUniversity!, thresholdSubjectTests!)}');
    }
    if (thresholdCollege != null) b.writeln('- ${l.learnHbThresholdCollege(thresholdCollege!)}');
    b.writeln('- ${l.learnHbThresholdsYearly}');
    final d = pickLocalized(disclaimer, lang);
    if (d.isNotEmpty) {
      b
        ..writeln()
        ..writeln('> $d');
    }
    return b.toString().trim();
  }
}
