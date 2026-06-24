import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// ORT Test Model - Represents a complete ORT exam test
class OrtTestModel extends Equatable {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final String category; // 'main_ort', 'math', 'russian', etc.
  final String language; // 'ru', 'ky', 'en'
  final int difficulty; // 1-5
  final int questionCount;
  final int durationMinutes;
  final List<String> questionIds;
  final bool isPremium;
  final bool isActive;
  final int order;
  final DateTime createdAt;
  final String createdBy;

  const OrtTestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.language,
    required this.difficulty,
    required this.questionCount,
    required this.durationMinutes,
    required this.questionIds,
    this.isPremium = false,
    this.isActive = true,
    this.order = 0,
    required this.createdAt,
    required this.createdBy,
  });

  factory OrtTestModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrtTestModel(
      id: id,
      title: Map<String, String>.from(data['title'] ?? {}),
      description: Map<String, String>.from(data['description'] ?? {}),
      category: data['category'] ?? '',
      language: data['language'] ?? 'ru',
      difficulty: data['difficulty'] ?? 1,
      questionCount: data['question_count'] ?? 0,
      durationMinutes: data['duration_minutes'] ?? 90,
      questionIds: List<String>.from(data['question_ids'] ?? []),
      isPremium: data['is_premium'] ?? false,
      isActive: data['is_active'] ?? true,
      order: data['order'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'language': language,
      'difficulty': difficulty,
      'question_count': questionCount,
      'duration_minutes': durationMinutes,
      'question_ids': questionIds,
      'is_premium': isPremium,
      'is_active': isActive,
      'order': order,
      'created_at': Timestamp.fromDate(createdAt),
      'created_by': createdBy,
    };
  }

  String getTitle(String locale) {
    return title[locale] ?? title['ru'] ?? title['en'] ?? '';
  }

  String getDescription(String locale) {
    return description[locale] ?? description['ru'] ?? description['en'] ?? '';
  }

  String getDifficultyText() {
    switch (difficulty) {
      case 1:
        return 'Очень легкий';
      case 2:
        return 'Легкий';
      case 3:
        return 'Средний';
      case 4:
        return 'Сложный';
      case 5:
        return 'Очень сложный';
      default:
        return 'Уровень $difficulty';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        language,
        difficulty,
        questionCount,
        durationMinutes,
        questionIds,
        isPremium,
        isActive,
        order,
        createdAt,
        createdBy,
      ];
}
