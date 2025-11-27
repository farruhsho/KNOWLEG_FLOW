import 'package:cloud_firestore/cloud_firestore.dart';

/// Question type enum
enum QuestionType {
  singleChoice,
  multipleChoice,
  matching,
  ordering,
  fillBlank,
  textBased,
}

/// Answer option for questions
class AnswerOption {
  final String id;
  final Map<String, String> text;
  final String? imageUrl;
  final bool isCorrect;

  AnswerOption({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.isCorrect,
  });

  factory AnswerOption.fromMap(Map<String, dynamic> map) {
    return AnswerOption(
      id: map['id'] ?? '',
      text: Map<String, String>.from(map['text'] ?? {}),
      imageUrl: map['image_url'],
      isCorrect: map['is_correct'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'image_url': imageUrl,
      'is_correct': isCorrect,
    };
  }
}

/// Question statistics
class QuestionStats {
  final int totalAttempts;
  final int correctAttempts;
  final double avgTimeSeconds;
  final Map<String, int> answerDistribution;

  QuestionStats({
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.avgTimeSeconds = 0.0,
    this.answerDistribution = const {},
  });

  double get correctPercentage =>
      totalAttempts > 0 ? (correctAttempts / totalAttempts) * 100 : 0;

  factory QuestionStats.fromMap(Map<String, dynamic> map) {
    return QuestionStats(
      totalAttempts: map['total_attempts'] ?? 0,
      correctAttempts: map['correct_attempts'] ?? 0,
      avgTimeSeconds: (map['avg_time_seconds'] ?? 0).toDouble(),
      answerDistribution: Map<String, int>.from(map['answer_distribution'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_attempts': totalAttempts,
      'correct_attempts': correctAttempts,
      'avg_time_seconds': avgTimeSeconds,
      'answer_distribution': answerDistribution,
    };
  }
}

/// Question history entry
class QuestionHistory {
  final DateTime timestamp;
  final String userId;
  final String action;
  final Map<String, dynamic>? changes;

  QuestionHistory({
    required this.timestamp,
    required this.userId,
    required this.action,
    this.changes,
  });

  factory QuestionHistory.fromMap(Map<String, dynamic> map) {
    return QuestionHistory(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      userId: map['user_id'] ?? '',
      action: map['action'] ?? '',
      changes: map['changes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'user_id': userId,
      'action': action,
      'changes': changes,
    };
  }
}

/// Question model for admin panel
class QuestionModel {
  final String id;
  final String subjectId;
  final String? topicId;
  final String? lessonId;
  final Map<String, String> stem; // текст вопроса {ru, ky, en}
  final List<AnswerOption> options;
  final String correctAnswer; // индекс или список индексов
  final QuestionType type;
  final int difficulty; // 1-3
  final Map<String, String>? explanation;
  final String? imageUrl;
  final String? videoUrl;
  final List<String> tags;
  final bool isActive;
  final QuestionStats stats;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final List<QuestionHistory> history;

  QuestionModel({
    required this.id,
    required this.subjectId,
    this.topicId,
    this.lessonId,
    required this.stem,
    required this.options,
    required this.correctAnswer,
    required this.type,
    required this.difficulty,
    this.explanation,
    this.imageUrl,
    this.videoUrl,
    this.tags = const [],
    this.isActive = true,
    required this.stats,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.history = const [],
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      subjectId: data['subject_id'] ?? '',
      topicId: data['topic_id'],
      lessonId: data['lesson_id'],
      stem: Map<String, String>.from(data['stem'] ?? {}),
      options: (data['options'] as List<dynamic>?)
              ?.map((e) => AnswerOption.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswer: data['correct_answer'] ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.toString() == 'QuestionType.${data['type']}',
        orElse: () => QuestionType.singleChoice,
      ),
      difficulty: data['difficulty'] ?? 1,
      explanation: data['explanation'] != null
          ? Map<String, String>.from(data['explanation'])
          : null,
      imageUrl: data['image_url'],
      videoUrl: data['video_url'],
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['is_active'] ?? true,
      stats: QuestionStats.fromMap(data['stats'] ?? {}),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      createdBy: data['created_by'] ?? '',
      history: (data['history'] as List<dynamic>?)
              ?.map((e) => QuestionHistory.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject_id': subjectId,
      'topic_id': topicId,
      'lesson_id': lessonId,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correct_answer': correctAnswer,
      'type': type.toString().split('.').last,
      'difficulty': difficulty,
      'explanation': explanation,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'tags': tags,
      'is_active': isActive,
      'stats': stats.toMap(),
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  QuestionModel copyWith({
    String? id,
    String? subjectId,
    String? topicId,
    String? lessonId,
    Map<String, String>? stem,
    List<AnswerOption>? options,
    String? correctAnswer,
    QuestionType? type,
    int? difficulty,
    Map<String, String>? explanation,
    String? imageUrl,
    String? videoUrl,
    List<String>? tags,
    bool? isActive,
    QuestionStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<QuestionHistory>? history,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      lessonId: lessonId ?? this.lessonId,
      stem: stem ?? this.stem,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      explanation: explanation ?? this.explanation,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      history: history ?? this.history,
    );
  }
}
