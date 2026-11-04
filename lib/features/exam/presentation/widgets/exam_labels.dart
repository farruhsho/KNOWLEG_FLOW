import '../../../../core/content/topic_names.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/exam_blueprint.dart';
import '../../domain/localized_text.dart';

/// Student-facing names for exam ids (topics, sections, blueprints) so the
/// ru/ky UI never shows raw slugs such as `math.arithmetic` or
/// `ort_subject_chemistry_2026` (UX-02). Names come from the bundled
/// curriculum catalog ([TopicNames]) and the blueprint.

/// Label of [topicId]:
/// 1. a title the server attached to the topic score;
/// 2. the catalog name of the id or of its nearest known parent
///    (`math.arithmetic.x` → «Арифметика»);
/// 3. the blueprint section / part the id starts with (`analogies.*` →
///    «Аналогии»);
/// 4. a humanized last segment (never the dotted id).
String examTopicName(
  String topicId, {
  required TopicNames names,
  required String lang,
  ExamBlueprint? blueprint,
  LocalizedText serverTitle = LocalizedText.empty,
}) {
  if (!serverTitle.isEmpty) return serverTitle.resolve(lang);
  final segments = topicId.split('.');
  for (var n = segments.length; n > 0; n--) {
    final prefix = segments.take(n).join('.');
    if (names.contains(prefix)) return names.label(prefix, lang);
  }
  final area = _blueprintArea(segments.first, blueprint, lang);
  if (area != null && area.isNotEmpty) return area;
  return names.label(topicId, lang);
}

String? _blueprintArea(String id, ExamBlueprint? bp, String lang) {
  if (bp == null) return null;
  for (final s in bp.sections) {
    for (final p in s.parts) {
      if (p.id == id) return p.title.resolve(lang);
    }
  }
  for (final s in bp.sections) {
    if (s.id == id || s.subjectArea == id) return s.title.resolve(lang);
  }
  return null;
}

/// Title of section [sectionId]: the blueprint's, else the catalog name of
/// the subject area (`verbal` → «Аналогии и дополнение предложений»).
String examSectionName(
  String sectionId, {
  required TopicNames names,
  required String lang,
  ExamBlueprint? blueprint,
}) {
  final title = blueprint?.sectionById(sectionId)?.title.resolve(lang);
  if (title != null && title.isNotEmpty) return title;
  return names.label(sectionId, lang);
}

final RegExp _mainId = RegExp(r'^ort_main(_\d{4})?$');
final RegExp _stateLanguageId = RegExp(r'^ort_state_language(_\d{4})?$');
final RegExp _subjectId = RegExp(r'^ort_subject_(.+?)(_\d{4})?$');

/// Title of a blueprint (direction). When the blueprint itself is not
/// loaded (offline, retired year), the id is decoded: `ort_main_*` → main
/// test, `ort_state_language_*` → state language, `ort_subject_{s}_*` → the
/// subject's catalog name.
String examBlueprintName(
  String blueprintId, {
  required AppLocalizations l,
  required TopicNames names,
  required String lang,
  ExamBlueprint? blueprint,
}) {
  final title = blueprint?.title.resolve(lang);
  if (title != null && title.isNotEmpty) return title;
  if (_mainId.hasMatch(blueprintId)) return l.examCatalogMainTitle;
  if (_stateLanguageId.hasMatch(blueprintId)) {
    return l.examCatalogStateLanguageTitle;
  }
  final subject = _subjectId.firstMatch(blueprintId)?.group(1);
  if (subject != null) return names.label(subject, lang);
  return names.label(blueprintId, lang);
}
