import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enhanced Question Model with full ORT support
class QuestionModel extends Equatable {
  final String id;
  final String subjectId;
  final String sectionId; // ORT section (math1, math2, analogies, etc.)
  final String? topicId;
  final String? lessonId;

  // Multi-language content
  final Map<String, String> stem; // Question text
  final List<OptionModel> options;
  final String correctAnswer; // Option ID (A-E)
  final List<String>? correctAnswers; // For multiple choice

  // Question properties
  final QuestionType type;
  final int difficulty; // 1-3
  final int points; // Points for correct answer

  // Media
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final List<String>? attachments;

  // Explanation
  final Map<String, String> explanation;
  final Map<String, String>? hint;
  final String? solutionVideoUrl;

  // Metadata
  final List<String> tags;
  final String? source; // Where question came from
  final bool isAiGenerated;
  final bool isVerified;
  final bool isActive;

  // Statistics
  final QuestionStats? stats;

  // Audit
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;

  // Legacy support
  final String category; // 'main', 'subject', 'language' for ORT sections
  final List<double>? embedding; // Vector embedding for duplicate detection

  const QuestionModel({
    required this.id,
    required this.subjectId,
    required this.sectionId,
    this.topicId,
    this.lessonId,
    required this.stem,
    required this.options,
    required this.correctAnswer,
    this.correctAnswers,
    required this.type,
    required this.difficulty,
    this.points = 1,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    this.attachments,
    required this.explanation,
    this.hint,
    this.solutionVideoUrl,
    this.tags = const [],
    this.source,
    this.isAiGenerated = false,
    this.isVerified = false,
    this.isActive = true,
    this.stats,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    this.category = 'subject',
    this.embedding,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      subjectId: data['subject_id'] ?? data['subjectId'] ?? '',
      sectionId: data['section_id'] ?? data['sectionId'] ?? '',
      topicId: data['topic_id'] ?? data['topicId'],
      lessonId: data['lesson_id'] ?? data['lessonId'],
      stem: Map<String, String>.from(data['stem'] ?? {}),
      options: (data['options'] as List<dynamic>?)
              ?.map((e) => OptionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswer: data['correct_answer'] ?? data['correct'] ?? 'A',
      correctAnswers: data['correct_answers'] != null
          ? List<String>.from(data['correct_answers'])
          : null,
      type: _parseQuestionType(data['type'] ?? 'single_choice'),
      difficulty: data['difficulty'] ?? 1,
      points: data['points'] ?? 1,
      imageUrl: data['image_url'] ?? data['imageUrl'],
      videoUrl: data['video_url'] ?? data['videoUrl'],
      audioUrl: data['audio_url'] ?? data['audioUrl'],
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
          : null,
      explanation: Map<String, String>.from(data['explanation'] ?? {}),
      hint: data['hint'] != null
          ? Map<String, String>.from(data['hint'])
          : null,
      solutionVideoUrl: data['solution_video_url'] ?? data['solutionVideoUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      source: data['source'],
      isAiGenerated: data['is_ai_generated'] ?? data['isAiGenerated'] ?? false,
      isVerified: data['is_verified'] ?? data['isVerified'] ?? false,
      isActive: data['is_active'] ?? data['isActive'] ?? true,
      stats: data['stats'] != null
          ? QuestionStats.fromMap(data['stats'])
          : null,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['created_by'] ?? data['createdBy'] ?? '',
      updatedBy: data['updated_by'] ?? data['updatedBy'],
      category: data['category'] ?? 'subject',
      embedding: data['embedding'] != null
          ? List<double>.from(data['embedding'] as List<dynamic>)
          : null,
    );
  }

  static QuestionType _parseQuestionType(String typeStr) {
    switch (typeStr) {
      case 'single_choice':
      case 'mcq':
        return QuestionType.singleChoice;
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'analogy':
        return QuestionType.analogy;
      case 'completion':
      case 'fill_blank':
        return QuestionType.completion;
      case 'matching':
        return QuestionType.matching;
      case 'ordering':
        return QuestionType.ordering;
      case 'true_false':
      case 'tf':
        return QuestionType.trueFalse;
      case 'text_based':
        return QuestionType.textBased;
      default:
        return QuestionType.singleChoice;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject_id': subjectId,
      'section_id': sectionId,
      'topic_id': topicId,
      'lesson_id': lessonId,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correct_answer': correctAnswer,
      'correct_answers': correctAnswers,
      'type': type.name,
      'difficulty': difficulty,
      'points': points,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'audio_url': audioUrl,
      'attachments': attachments,
      'explanation': explanation,
      'hint': hint,
      'solution_video_url': solutionVideoUrl,
      'tags': tags,
      'source': source,
      'is_ai_generated': isAiGenerated,
      'is_verified': isVerified,
      'is_active': isActive,
      'stats': stats?.toMap(),
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'category': category,
      'embedding': embedding,
    };
  }
  
  // JSON serialization for export/import
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? json['subject_id'] ?? '',
      sectionId: json['sectionId'] ?? json['section_id'] ?? '',
      topicId: json['topicId'] ?? json['topic_id'],
      lessonId: json['lessonId'] ?? json['lesson_id'],
      stem: Map<String, String>.from(json['stem'] ?? {}),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => OptionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'] ?? json['correct'] ?? 'A',
      correctAnswers: json['correctAnswers'] != null
          ? List<String>.from(json['correctAnswers'])
          : null,
      type: _parseQuestionType(json['type'] ?? 'single_choice'),
      difficulty: json['difficulty'] ?? 1,
      points: json['points'] ?? 1,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      videoUrl: json['videoUrl'] ?? json['video_url'],
      audioUrl: json['audioUrl'] ?? json['audio_url'],
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      explanation: Map<String, String>.from(json['explanation'] ?? {}),
      hint: json['hint'] != null
          ? Map<String, String>.from(json['hint'])
          : null,
      solutionVideoUrl: json['solutionVideoUrl'] ?? json['solution_video_url'],
      tags: List<String>.from(json['tags'] ?? []),
      source: json['source'],
      isAiGenerated: json['isAiGenerated'] ?? json['is_ai_generated'] ?? false,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      stats: json['stats'] != null
          ? QuestionStats.fromMap(json['stats'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now()),
      createdBy: json['createdBy'] ?? json['created_by'] ?? '',
      updatedBy: json['updatedBy'] ?? json['updated_by'],
      category: json['category'] ?? 'subject',
      embedding: json['embedding'] != null
          ? List<double>.from(json['embedding'] as List<dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'sectionId': sectionId,
      'topicId': topicId,
      'lessonId': lessonId,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correctAnswer': correctAnswer,
      'correctAnswers': correctAnswers,
      'type': type.name,
      'difficulty': difficulty,
      'points': points,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'attachments': attachments,
      'explanation': explanation,
      'hint': hint,
      'solutionVideoUrl': solutionVideoUrl,
      'tags': tags,
      'source': source,
      'isAiGenerated': isAiGenerated,
      'isVerified': isVerified,
      'isActive': isActive,
      'stats': stats?.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'category': category,
      'embedding': embedding,
    };
  }

  /// Get localized stem text
  String getStem(String locale) {
    return stem[locale] ?? stem['ru'] ?? stem['en'] ?? stem.values.first;
  }

  /// Get localized explanation
  String getExplanation(String locale) {
    return explanation[locale] ?? explanation['ru'] ?? explanation['en'] ?? '';
  }

  /// Get localized hint
  String? getHint(String locale) {
    return hint?[locale] ?? hint?['ru'] ?? hint?['en'];
  }

  /// Get correct percentage from stats
  double get correctPercentage {
    if (stats == null || stats!.totalAttempts == 0) return 0;
    return stats!.percentageCorrect;
  }

  /// Check if question is problematic (low success rate)
  bool get isProblematic =>
      stats != null && stats!.isProblematic;

  /// Copy with modifications
  QuestionModel copyWith({
    String? id,
    String? subjectId,
    String? sectionId,
    String? topicId,
    String? lessonId,
    Map<String, String>? stem,
    List<OptionModel>? options,
    String? correctAnswer,
    List<String>? correctAnswers,
    QuestionType? type,
    int? difficulty,
    int? points,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<String>? attachments,
    Map<String, String>? explanation,
    Map<String, String>? hint,
    String? solutionVideoUrl,
    List<String>? tags,
    String? source,
    bool? isAiGenerated,
    bool? isVerified,
    bool? isActive,
    QuestionStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? category,
    List<double>? embedding,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      sectionId: sectionId ?? this.sectionId,
      topicId: topicId ?? this.topicId,
      lessonId: lessonId ?? this.lessonId,
      stem: stem ?? this.stem,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      attachments: attachments ?? this.attachments,
      explanation: explanation ?? this.explanation,
      hint: hint ?? this.hint,
      solutionVideoUrl: solutionVideoUrl ?? this.solutionVideoUrl,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      category: category ?? this.category,
      embedding: embedding ?? this.embedding,
    );
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        sectionId,
        topicId,
        lessonId,
        stem,
        options,
        correctAnswer,
        correctAnswers,
        type,
        difficulty,
        points,
        imageUrl,
        videoUrl,
        audioUrl,
        attachments,
        explanation,
        hint,
        solutionVideoUrl,
        tags,
        source,
        isAiGenerated,
        isVerified,
        isActive,
        stats,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
        category,
        embedding,
      ];
}

class OptionModel extends Equatable {
  final String id; // 'A', 'B', 'C', 'D'
  final Map<String, String> text;

  const OptionModel({
    required this.id,
    required this.text,
  });

  factory OptionModel.fromMap(Map<String, dynamic> map) {
    return OptionModel(
      id: map['id'] ?? '',
      text: Map<String, String>.from(map['text'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
    };
  }

  String getText(String locale) {
    return text[locale] ?? text['en'] ?? text['ru'] ?? '';
  }

  @override
  List<Object?> get props => [id, text];
}

/// Question types enum
enum QuestionType {
  singleChoice, // Standard A-E choice
  multipleChoice, // Multiple correct answers
  analogy, // A:B = C:?
  completion, // Fill in blank
  matching, // Match pairs
  ordering, // Put in order
  trueFalse, // True/False
  textBased, // Based on reading passage
}

/// Question statistics model
class QuestionStats extends Equatable {
  final int totalAttempts;
  final int correctAttempts;
  final double avgTimeSeconds;
  final Map<String, int> answerDistribution;
  final DateTime? lastAttemptAt;

  const QuestionStats({
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.avgTimeSeconds = 0,
    this.answerDistribution = const {},
    this.lastAttemptAt,
  });

  /// Calculate success rate
  double get successRate =>
      totalAttempts > 0 ? correctAttempts / totalAttempts : 0;

  /// Get percentage correct
  double get percentageCorrect => successRate * 100;

  /// Check if question is problematic (low success rate)
  bool get isProblematic => percentageCorrect < 30 && totalAttempts > 10;

  factory QuestionStats.fromMap(Map<String, dynamic> map) {
    return QuestionStats(
      totalAttempts: map['total_attempts'] ?? map['totalAttempts'] ?? 0,
      correctAttempts: map['correct_attempts'] ?? map['correctAttempts'] ?? 0,
      avgTimeSeconds:
          (map['avg_time_seconds'] ?? map['avgTimeSeconds'] ?? 0).toDouble(),
      answerDistribution: Map<String, int>.from(
          map['answer_distribution'] ?? map['answerDistribution'] ?? {}),
      lastAttemptAt: map['last_attempt_at'] != null
          ? (map['last_attempt_at'] as Timestamp).toDate()
          : (map['lastAttemptAt'] != null
              ? DateTime.parse(map['lastAttemptAt'])
              : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_attempts': totalAttempts,
      'correct_attempts': correctAttempts,
      'avg_time_seconds': avgTimeSeconds,
      'answer_distribution': answerDistribution,
      'last_attempt_at': lastAttemptAt != null
          ? Timestamp.fromDate(lastAttemptAt!)
          : null,
    };
  }

  /// Create a copy with updated values
  QuestionStats copyWith({
    int? totalAttempts,
    int? correctAttempts,
    double? avgTimeSeconds,
    Map<String, int>? answerDistribution,
    DateTime? lastAttemptAt,
  }) {
    return QuestionStats(
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctAttempts: correctAttempts ?? this.correctAttempts,
      avgTimeSeconds: avgTimeSeconds ?? this.avgTimeSeconds,
      answerDistribution: answerDistribution ?? this.answerDistribution,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  @override
  List<Object?> get props => [
        totalAttempts,
        correctAttempts,
        avgTimeSeconds,
        answerDistribution,
        lastAttemptAt,
      ];
}
