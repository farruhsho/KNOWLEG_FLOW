import '../../core/utils/content_locale.dart';
import '../../core/utils/json_read.dart';

/// Subject model for ORT exam subjects
///
/// Parsing tolerates missing description/icon/color, `name` instead of
/// `title`, plain-string titles and numeric fields stored as doubles
/// (CMS-21). [icon] may be a Material icon name ("calculate") or an emoji;
/// render it with `SubjectIcon`.
class SubjectModel {
  final String id;
  final Map<String, String> title; // ru, ky, en
  final Map<String, String> description;
  final String icon;
  final String color;
  final List<String>? moduleIds;
  final List<String>? difficultyTags;
  final int totalLessons;
  final int totalQuestions;
  final int order;
  final bool isActive;

  SubjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.moduleIds,
    this.difficultyTags,
    this.totalLessons = 0,
    this.totalQuestions = 0,
    this.order = 0,
    this.isActive = true,
  });

  String getTitle(String locale) {
    final t = pickLocalized(title, locale);
    return t.isEmpty ? id : t;
  }

  String getDescription(String locale) => pickLocalized(description, locale);

  /// [id] is the document id and wins over a missing `id` field.
  factory SubjectModel.fromFirestore(Map<String, dynamic> data, {String? id}) {
    final dataId = JsonRead.string(data, ['id']);
    List<String>? optList(List<String> keys) {
      final l = JsonRead.stringList(data, keys);
      return l.isEmpty ? null : l;
    }

    return SubjectModel(
      id: (dataId == null || dataId.isEmpty) ? (id ?? '') : dataId,
      title: JsonRead.localized(JsonRead.any(data, ['title', 'name'])),
      description: JsonRead.localized(JsonRead.any(data, ['description', 'subtitle'])),
      icon: JsonRead.stringOr(data, ['icon', 'icon_name', 'iconName']),
      color: JsonRead.stringOr(data, ['color', 'colour']),
      moduleIds: optList(['moduleIds', 'module_ids']),
      difficultyTags: optList(['difficultyTags', 'difficulty_tags']),
      totalLessons: JsonRead.intOr(data, ['totalLessons', 'total_lessons', 'lessons_count'], 0),
      totalQuestions: JsonRead.intOr(data, ['totalQuestions', 'total_questions', 'questions_count'], 0),
      order: JsonRead.intOr(data, ['order', 'position'], 0),
      isActive: JsonRead.boolean(data, ['isActive', 'is_active']) ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      if (moduleIds != null) 'moduleIds': moduleIds,
      if (difficultyTags != null) 'difficultyTags': difficultyTags,
      'totalLessons': totalLessons,
      'totalQuestions': totalQuestions,
    };
  }

  SubjectModel copyWith({
    String? id,
    Map<String, String>? title,
    Map<String, String>? description,
    String? icon,
    String? color,
    List<String>? moduleIds,
    List<String>? difficultyTags,
    int? totalLessons,
    int? totalQuestions,
    int? order,
    bool? isActive,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      moduleIds: moduleIds ?? this.moduleIds,
      difficultyTags: difficultyTags ?? this.difficultyTags,
      totalLessons: totalLessons ?? this.totalLessons,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }
}
