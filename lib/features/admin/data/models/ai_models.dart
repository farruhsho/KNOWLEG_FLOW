/// AI service configuration
class AiServiceConfig {
  static const String apiEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String model = 'claude-3-5-sonnet-20241022';
  static const int maxTokens = 4096;
  static const double temperature = 0.7;
}

/// AI question generation request
class AiQuestionRequest {
  final String subjectId;
  final String topic;
  final int difficulty;
  final int count;
  final String language;
  final String? context;
  final List<String>? tags;

  AiQuestionRequest({
    required this.subjectId,
    required this.topic,
    required this.difficulty,
    required this.count,
    this.language = 'ru',
    this.context,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'topic': topic,
      'difficulty': difficulty,
      'count': count,
      'language': language,
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

/// Generated question from AI
class GeneratedQuestion {
  final Map<String, String> stem;
  final List<GeneratedOption> options;
  final String correctAnswer;
  final Map<String, String>? explanation;
  final List<String> tags;
  final int difficulty;

  GeneratedQuestion({
    required this.stem,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.tags = const [],
    required this.difficulty,
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
    };
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
