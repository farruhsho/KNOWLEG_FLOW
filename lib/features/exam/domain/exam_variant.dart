import 'package:flutter/foundation.dart';

import 'json_utils.dart';
import 'localized_text.dart';

/// Published exam variant (`exam_variants/{id}`, ARCHITECTURE §1.2). The
/// client only ever sees metadata — question ids are not needed and question
/// content arrives section by section from `examStart` / `examSubmitSection`.
@immutable
class ExamVariant {
  final String id;
  final String blueprintId;
  final int blueprintVersion;
  final int number;
  final LocalizedText title;
  final String language;
  final String status;
  final String difficultyLabel;

  const ExamVariant({
    required this.id,
    required this.blueprintId,
    required this.blueprintVersion,
    required this.number,
    required this.title,
    required this.language,
    required this.status,
    this.difficultyLabel = 'standard',
  });

  bool get isPublished => status == 'published';

  bool get isAdvanced => difficultyLabel == 'advanced';

  factory ExamVariant.fromJson(String id, Map<String, dynamic> m) =>
      ExamVariant(
        id: id,
        blueprintId: asString(m['blueprint_id']) ?? '',
        blueprintVersion: asInt(m['blueprint_version']) ?? 1,
        number: asInt(m['number']) ?? 0,
        title: LocalizedText.fromJson(m['title']),
        language: asString(m['language']) ?? 'ru',
        status: asString(m['status']) ?? 'draft',
        difficultyLabel: asString(m['difficulty_label']) ?? 'standard',
      );
}
