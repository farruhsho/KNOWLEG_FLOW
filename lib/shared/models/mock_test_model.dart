import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MockTestModel extends Equatable {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final List<TestSectionModel> sections;
  final int priceKGS;
  final bool isPublished;
  final String createdBy;
  final DateTime createdAt;

  const MockTestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.sections,
    required this.priceKGS,
    this.isPublished = false,
    required this.createdBy,
    required this.createdAt,
  });

  factory MockTestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MockTestModel(
      id: doc.id,
      title: Map<String, String>.from(data['title'] ?? {}),
      description: Map<String, String>.from(data['description'] ?? {}),
      sections: (data['sections'] as List<dynamic>?)
              ?.map((e) => TestSectionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      priceKGS: data['price_kgs'] ?? 100,
      isPublished: data['is_published'] ?? false,
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'sections': sections.map((e) => e.toMap()).toList(),
      'price_kgs': priceKGS,
      'is_published': isPublished,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  String getTitle(String locale) {
    return title[locale] ?? title['en'] ?? title['ru'] ?? '';
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? description['ru'] ?? '';
  }

  int get totalQuestions {
    return sections.fold(0, (sum, section) => sum + section.questionIds.length);
  }

  int get totalTimeMinutes {
    return sections.fold(0, (sum, section) => sum + section.timeMinutes);
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        sections,
        priceKGS,
        isPublished,
        createdBy,
        createdAt,
      ];
}

class TestSectionModel extends Equatable {
  final String name;
  final String type; // 'main', 'subject', 'language'
  final int timeMinutes;
  final List<String> questionIds;

  const TestSectionModel({
    required this.name,
    required this.type,
    required this.timeMinutes,
    required this.questionIds,
  });

  factory TestSectionModel.fromMap(Map<String, dynamic> map) {
    return TestSectionModel(
      name: map['name'] ?? '',
      type: map['type'] ?? 'main',
      timeMinutes: map['time_minutes'] ?? 60,
      questionIds: List<String>.from(map['question_ids'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'time_minutes': timeMinutes,
      'question_ids': questionIds,
    };
  }

  @override
  List<Object?> get props => [name, type, timeMinutes, questionIds];
}
