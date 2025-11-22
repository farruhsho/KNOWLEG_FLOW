import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SubjectModel extends Equatable {
  final String id;
  final Map<String, String> title; // {kg: "Математика", ru: "Математика"}
  final Map<String, String> description;
  final String icon;
  final String color;
  final List<String> moduleIds;
  final List<String> difficultyTags;
  final int totalLessons;
  final int totalQuestions;

  const SubjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.moduleIds = const [],
    this.difficultyTags = const [],
    this.totalLessons = 0,
    this.totalQuestions = 0,
  });

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubjectModel(
      id: doc.id,
      title: Map<String, String>.from(data['title'] ?? {}),
      description: Map<String, String>.from(data['description'] ?? {}),
      icon: data['icon'] ?? '📚',
      color: data['color'] ?? '#2563EB',
      moduleIds: List<String>.from(data['module_ids'] ?? []),
      difficultyTags: List<String>.from(data['difficulty_tags'] ?? []),
      totalLessons: data['total_lessons'] ?? 0,
      totalQuestions: data['total_questions'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      'module_ids': moduleIds,
      'difficulty_tags': difficultyTags,
      'total_lessons': totalLessons,
      'total_questions': totalQuestions,
    };
  }

  String getTitle(String locale) {
    return title[locale] ?? title['en'] ?? title['ru'] ?? '';
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? description['ru'] ?? '';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        icon,
        color,
        moduleIds,
        difficultyTags,
        totalLessons,
        totalQuestions,
      ];
}
