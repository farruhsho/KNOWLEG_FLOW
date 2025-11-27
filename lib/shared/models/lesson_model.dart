/// Lesson model for daily lessons and subject lessons
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
  });

  String getTitle(String locale) => title[locale] ?? title['ru'] ?? '';
  String getContent(String locale) => content[locale] ?? content['ru'] ?? '';

  factory LessonModel.fromFirestore(Map<String, dynamic> data) {
    return LessonModel(
      id: data['id'] as String,
      subjectId: data['subjectId'] as String,
      title: Map<String, String>.from(data['title'] as Map),
      content: Map<String, String>.from(data['content'] as Map),
      mediaUrls: data['mediaUrls'] != null ? List<String>.from(data['mediaUrls'] as List) : [],
      estimatedTimeMinutes: data['estimatedTimeMinutes'] as int? ?? data['estimatedTime'] as int? ?? 30,
      tags: data['tags'] != null ? List<String>.from(data['tags'] as List) : [],
      order: data['order'] as int,
      createdBy: data['createdBy'] as String? ?? 'admin',
      createdAt: data['createdAt'] is String
          ? DateTime.parse(data['createdAt'] as String)
          : (data['createdAt'] as DateTime? ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'subjectId': subjectId,
      'title': title,
      'content': content,
      'mediaUrls': mediaUrls,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'tags': tags,
      'order': order,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
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
    );
  }
}
