/// Subject model for ORT exam subjects
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
  });

  String getTitle(String locale) => title[locale] ?? title['ru'] ?? '';
  String getDescription(String locale) => description[locale] ?? description['ru'] ?? '';

  factory SubjectModel.fromFirestore(Map<String, dynamic> data) {
    return SubjectModel(
      id: data['id'] as String,
      title: Map<String, String>.from(data['title'] as Map? ?? data['name'] as Map),
      description: Map<String, String>.from(data['description'] as Map),
      icon: data['icon'] as String,
      color: data['color'] as String,
      moduleIds: data['moduleIds'] != null ? List<String>.from(data['moduleIds'] as List) : null,
      difficultyTags: data['difficultyTags'] != null ? List<String>.from(data['difficultyTags'] as List) : null,
      totalLessons: data['totalLessons'] as int? ?? 0,
      totalQuestions: data['totalQuestions'] as int? ?? 0,
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
    );
  }
}
