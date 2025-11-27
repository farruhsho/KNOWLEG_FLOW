import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Model for full ORT test structure (130 questions, 3 sections, 195 minutes)
/// Section 1: Main Test (30 Math + 30 Russian/Kyrgyz) - 90 minutes
/// Section 2: Subject Test (40 questions from chosen subject) - 60 minutes
/// Section 3: Language Test (30 questions from chosen language) - 45 minutes
class OrtTestModel extends Equatable {
  final String id;
  final String title;
  final Map<String, String> description;
  final OrtSection section1; // Main Test
  final OrtSection section2; // Subject Test
  final OrtSection section3; // Language Test
  final int totalQuestions; // Should be 130
  final int totalMinutes; // Should be 195
  final int maxScore; // Should be 200
  final DateTime createdAt;
  final String createdBy;
  final bool isPremium;

  const OrtTestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.section1,
    required this.section2,
    required this.section3,
    this.totalQuestions = 130,
    this.totalMinutes = 195,
    this.maxScore = 200,
    required this.createdAt,
    required this.createdBy,
    this.isPremium = false,
  });

  factory OrtTestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrtTestModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: Map<String, String>.from(data['description'] ?? {}),
      section1: OrtSection.fromMap(data['section1'] as Map<String, dynamic>),
      section2: OrtSection.fromMap(data['section2'] as Map<String, dynamic>),
      section3: OrtSection.fromMap(data['section3'] as Map<String, dynamic>),
      totalQuestions: data['total_questions'] ?? 130,
      totalMinutes: data['total_minutes'] ?? 195,
      maxScore: data['max_score'] ?? 200,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['created_by'] ?? '',
      isPremium: data['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'section1': section1.toMap(),
      'section2': section2.toMap(),
      'section3': section3.toMap(),
      'total_questions': totalQuestions,
      'total_minutes': totalMinutes,
      'max_score': maxScore,
      'created_at': Timestamp.fromDate(createdAt),
      'created_by': createdBy,
      'is_premium': isPremium,
    };
  }

  String getDescription(String locale) {
    return description[locale] ?? description['ru'] ?? '';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        section1,
        section2,
        section3,
        totalQuestions,
        totalMinutes,
        maxScore,
        createdAt,
        createdBy,
        isPremium,
      ];
}

/// Represents one section of the ORT test
class OrtSection extends Equatable {
  final String name; // 'main', 'subject', 'language'
  final Map<String, String> title;
  final List<String> questionIds; // References to questions collection
  final int questionCount;
  final int durationMinutes;
  final Map<String, dynamic>? metadata; // For subject/language selection

  const OrtSection({
    required this.name,
    required this.title,
    required this.questionIds,
    required this.questionCount,
    required this.durationMinutes,
    this.metadata,
  });

  factory OrtSection.fromMap(Map<String, dynamic> map) {
    return OrtSection(
      name: map['name'] ?? '',
      title: Map<String, String>.from(map['title'] ?? {}),
      questionIds: List<String>.from(map['question_ids'] ?? []),
      questionCount: map['question_count'] ?? 0,
      durationMinutes: map['duration_minutes'] ?? 0,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'question_ids': questionIds,
      'question_count': questionCount,
      'duration_minutes': durationMinutes,
      'metadata': metadata,
    };
  }

  String getTitle(String locale) {
    return title[locale] ?? title['ru'] ?? '';
  }

  @override
  List<Object?> get props => [
        name,
        title,
        questionIds,
        questionCount,
        durationMinutes,
        metadata,
      ];
}

/// User's attempt at an ORT test
class OrtTestAttempt extends Equatable {
  final String id;
  final String userId;
  final String testId;
  final Map<String, String> answers; // questionId -> selectedOptionId
  final int section1Score;
  final int section2Score;
  final int section3Score;
  final int totalScore; // Out of 200
  final DateTime startedAt;
  final DateTime? completedAt;
  final Map<String, int> timeSpentPerSection; // section name -> seconds
  final bool isCompleted;

  const OrtTestAttempt({
    required this.id,
    required this.userId,
    required this.testId,
    required this.answers,
    this.section1Score = 0,
    this.section2Score = 0,
    this.section3Score = 0,
    this.totalScore = 0,
    required this.startedAt,
    this.completedAt,
    this.timeSpentPerSection = const {},
    this.isCompleted = false,
  });

  factory OrtTestAttempt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrtTestAttempt(
      id: doc.id,
      userId: data['user_id'] ?? '',
      testId: data['test_id'] ?? '',
      answers: Map<String, String>.from(data['answers'] ?? {}),
      section1Score: data['section1_score'] ?? 0,
      section2Score: data['section2_score'] ?? 0,
      section3Score: data['section3_score'] ?? 0,
      totalScore: data['total_score'] ?? 0,
      startedAt: (data['started_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      timeSpentPerSection: Map<String, int>.from(data['time_spent_per_section'] ?? {}),
      isCompleted: data['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'test_id': testId,
      'answers': answers,
      'section1_score': section1Score,
      'section2_score': section2Score,
      'section3_score': section3Score,
      'total_score': totalScore,
      'started_at': Timestamp.fromDate(startedAt),
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'time_spent_per_section': timeSpentPerSection,
      'is_completed': isCompleted,
    };
  }

  OrtTestAttempt copyWith({
    String? id,
    String? userId,
    String? testId,
    Map<String, String>? answers,
    int? section1Score,
    int? section2Score,
    int? section3Score,
    int? totalScore,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, int>? timeSpentPerSection,
    bool? isCompleted,
  }) {
    return OrtTestAttempt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      testId: testId ?? this.testId,
      answers: answers ?? this.answers,
      section1Score: section1Score ?? this.section1Score,
      section2Score: section2Score ?? this.section2Score,
      section3Score: section3Score ?? this.section3Score,
      totalScore: totalScore ?? this.totalScore,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      timeSpentPerSection: timeSpentPerSection ?? this.timeSpentPerSection,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        testId,
        answers,
        section1Score,
        section2Score,
        section3Score,
        totalScore,
        startedAt,
        completedAt,
        timeSpentPerSection,
        isCompleted,
      ];
}
