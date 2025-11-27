import '../../../../shared/models/question_model.dart';

/// AI service configuration
class AiServiceConfig {
  static const String apiEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String model = 'claude-sonnet-4-20250514'; // Latest Sonnet 4.5
  static const int maxTokens = 8000;
  static const double temperature = 0.7;
  static const String apiVersion = '2023-06-01';
}

/// Enhanced AI question generation request
class AiQuestionRequest {
  final String subjectId;
  final String sectionId; // ORT section (math1, math2, etc.)
  final String topic;
  final int difficulty; // 1-3
  final int count; // 1-20
  final List<QuestionType> questionTypes;
  final List<String> languages; // ['ru', 'ky', 'en']
  final String? additionalInstructions;
  final List<String>? avoidSimilarTo; // Question texts to avoid duplicating
  final String? context;
  final List<String>? tags;

  AiQuestionRequest({
    required this.subjectId,
    required this.sectionId,
    required this.topic,
    required this.difficulty,
    required this.count,
    this.questionTypes = const [QuestionType.singleChoice],
    this.languages = const ['ru'],
    this.additionalInstructions,
    this.avoidSimilarTo,
    this.context,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'section_id': sectionId,
      'topic': topic,
      'difficulty': difficulty,
      'count': count,
      'question_types': questionTypes.map((t) => t.name).toList(),
      'languages': languages,
      'additional_instructions': additionalInstructions,
      'avoid_similar_to': avoidSimilarTo,
      'context': context,
      'tags': tags,
    };
  }
}

/// AI question generation response
class AiQuestionResponse {
  final List<GeneratedQuestion> questions;
  final int tokensUsed;
  final String model;

  AiQuestionResponse({
    required this.questions,
    required this.tokensUsed,
    required this.model,
  });

  factory AiQuestionResponse.fromJson(Map<String, dynamic> json) {
    return AiQuestionResponse(
      questions: (json['questions'] as List)
          .map((q) => GeneratedQuestion.fromJson(q))
          .toList(),
      tokensUsed: json['tokens_used'] ?? 0,
      model: json['model'] ?? '',
    );
  }
}

/// Generated question from AI (before saving to DB)
class GeneratedQuestion {
  final Map<String, String> stem;
  final List<GeneratedOption> options;
  final String correctAnswer;
  final Map<String, String>? explanation;
  final List<String> tags;
  final int difficulty;
  final String subjectId;
  final String sectionId;
  bool isSelected; // For UI selection
  bool isEdited; // Track if user edited

  GeneratedQuestion({
    required this.stem,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.tags = const [],
    required this.difficulty,
    required this.subjectId,
    required this.sectionId,
    this.isSelected = true,
    this.isEdited = false,
  });

  factory GeneratedQuestion.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestion(
      stem: Map<String, String>.from(json['stem'] ?? {}),
      options: (json['options'] as List)
          .map((o) => GeneratedOption.fromJson(o))
          .toList(),
      correctAnswer: json['correct_answer'] ?? '',
      explanation: json['explanation'] != null
          ? Map<String, String>.from(json['explanation'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      difficulty: json['difficulty'] ?? 1,
      subjectId: json['subject_id'] ?? '',
      sectionId: json['section_id'] ?? '',
      isSelected: json['is_selected'] ?? true,
      isEdited: json['is_edited'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stem': stem,
      'options': options.map((o) => o.toJson()).toList(),
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'tags': tags,
      'difficulty': difficulty,
      'subject_id': subjectId,
      'section_id': sectionId,
      'is_selected': isSelected,
      'is_edited': isEdited,
    };
  }

  /// Convert to QuestionModel for saving to Firestore
  QuestionModel toQuestionModel(String createdBy) {
    return QuestionModel(
      id: '',
      subjectId: subjectId,
      sectionId: sectionId,
      stem: stem,
      options: options
          .map((o) => OptionModel(
                id: o.id,
                text: o.text,
              ))
          .toList(),
      correctAnswer: correctAnswer,
      type: QuestionType.singleChoice,
      difficulty: difficulty,
      points: 1,
      explanation: explanation ?? {},
      tags: tags,
      isAiGenerated: true,
      isVerified: false,
      isActive: false, // Requires verification before activation
      stats: const QuestionStats(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }
}

/// Generated answer option
class GeneratedOption {
  final String id;
  final Map<String, String> text;
  final bool isCorrect;

  GeneratedOption({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  factory GeneratedOption.fromJson(Map<String, dynamic> json) {
    return GeneratedOption(
      id: json['id'] ?? '',
      text: Map<String, String>.from(json['text'] ?? {}),
      isCorrect: json['is_correct'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_correct': isCorrect,
    };
  }
}

/// Result of AI generation with metadata
class AIGenerationResult {
  final List<GeneratedQuestion> questions;
  final int tokensUsed;
  final double estimatedCost;
  final Duration generationTime;
  final bool success;
  final String? error;
  final String? model;

  const AIGenerationResult({
    required this.questions,
    required this.tokensUsed,
    required this.estimatedCost,
    required this.generationTime,
    required this.success,
    this.error,
    this.model,
  });

  factory AIGenerationResult.success({
    required List<GeneratedQuestion> questions,
    required int tokensUsed,
    required double estimatedCost,
    required Duration generationTime,
    String? model,
  }) {
    return AIGenerationResult(
      questions: questions,
      tokensUsed: tokensUsed,
      estimatedCost: estimatedCost,
      generationTime: generationTime,
      success: true,
      model: model,
    );
  }

  factory AIGenerationResult.failure({
    required String error,
    required Duration generationTime,
  }) {
    return AIGenerationResult(
      questions: [],
      tokensUsed: 0,
      estimatedCost: 0,
      generationTime: generationTime,
      success: false,
      error: error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questions': questions.map((q) => q.toJson()).toList(),
      'tokens_used': tokensUsed,
      'estimated_cost': estimatedCost,
      'generation_time_ms': generationTime.inMilliseconds,
      'success': success,
      'error': error,
      'model': model,
    };
  }
}

/// Question quality analysis result
class QuestionAnalysis {
  final Map<String, int> scores; // {clarity: 8, distractors: 7, ...}
  final double overallScore;
  final List<String> issues;
  final List<String> suggestions;

  const QuestionAnalysis({
    required this.scores,
    required this.overallScore,
    required this.issues,
    required this.suggestions,
  });

  factory QuestionAnalysis.fromJson(Map<String, dynamic> json) {
    return QuestionAnalysis(
      scores: Map<String, int>.from(json['scores'] ?? {}),
      overallScore: (json['overallScore'] ?? json['overall_score'] ?? 0).toDouble(),
      issues: List<String>.from(json['issues'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }

  factory QuestionAnalysis.empty() {
    return const QuestionAnalysis(
      scores: {},
      overallScore: 0,
      issues: [],
      suggestions: [],
    );
  }

  bool get isGood => overallScore >= 7;
  bool get needsImprovement => overallScore < 5;

  Map<String, dynamic> toJson() {
    return {
      'scores': scores,
      'overall_score': overallScore,
      'issues': issues,
      'suggestions': suggestions,
    };
  }
}

/// AI Service Exception
class AIServiceException implements Exception {
  final String message;
  final String? details;
  final int? statusCode;

  AIServiceException(this.message, [this.details, this.statusCode]);

  @override
  String toString() {
    final buffer = StringBuffer('AIServiceException: $message');
    if (statusCode != null) buffer.write(' (Status: $statusCode)');
    if (details != null) buffer.write('\nDetails: $details');
    return buffer.toString();
  }
}
