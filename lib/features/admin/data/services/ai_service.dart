import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_models.dart';
import '../../../../core/constants/ort_constants.dart';
import '../../../../shared/models/question_model.dart';

/// Enhanced AI Service with Claude 4.5 Sonnet integration
/// Specialized for ORT (Общереспубликанское тестирование) question generation
class AiService {
  final String apiKey;
  final String baseUrl;

  AiService({
    required this.apiKey,
    this.baseUrl = AiServiceConfig.apiEndpoint,
  });

  /// Generate ORT questions using Claude with full metadata
  Future<AIGenerationResult> generateQuestions({
    required String subjectId,
    required String sectionId,
    required String topic,
    required int difficulty,
    required int count,
    List<QuestionType> questionTypes = const [QuestionType.singleChoice],
    List<String> languages = const ['ru'],
    String? additionalInstructions,
    List<String>? avoidSimilarTo,
  }) async {
    final startTime = DateTime.now();

    try {
      // Build optimized ORT-specific prompt
      final prompt = _buildOrtPrompt(
        subjectId: subjectId,
        sectionId: sectionId,
        topic: topic,
        difficulty: difficulty,
        count: count,
        questionTypes: questionTypes,
        languages: languages,
        additionalInstructions: additionalInstructions,
        avoidSimilarTo: avoidSimilarTo,
      );

      // Make API request
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': AiServiceConfig.apiVersion,
        },
        body: jsonEncode({
          'model': AiServiceConfig.model,
          'max_tokens': AiServiceConfig.maxTokens,
          'temperature': AiServiceConfig.temperature,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw AIServiceException(
          'API request failed',
          response.body,
          response.statusCode,
        );
      }

      // Parse response
      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'];
      final questions = _parseQuestionsFromResponse(
        content,
        subjectId,
        sectionId,
      );

      final endTime = DateTime.now();
      final tokensUsed = (data['usage']['input_tokens'] ?? 0) +
          (data['usage']['output_tokens'] ?? 0);

      return AIGenerationResult.success(
        questions: questions,
        tokensUsed: tokensUsed,
        estimatedCost: _calculateCost(tokensUsed),
        generationTime: endTime.difference(startTime),
        model: data['model'],
      );
    } catch (e) {
      final endTime = DateTime.now();
      return AIGenerationResult.failure(
        error: e.toString(),
        generationTime: endTime.difference(startTime),
      );
    }
  }

  /// Generate explanation for an existing question
  Future<Map<String, String>> generateExplanation({
    required QuestionModel question,
    required List<String> languages,
  }) async {
    final prompt = _buildExplanationPrompt(question, languages);

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': AiServiceConfig.apiVersion,
        },
        body: jsonEncode({
          'model': AiServiceConfig.model,
          'max_tokens': 2000,
          'temperature': 0.7,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw AIServiceException(
          'Failed to generate explanation',
          response.body,
          response.statusCode,
        );
      }

      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'];

      // Try to extract JSON
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!);
        return Map<String, String>.from(parsed['explanation'] ?? {});
      }

      // Fallback: return raw content as Russian explanation
      return {'ru': content};
    } catch (e) {
      return {'ru': 'Ошибка генерации объяснения: $e'};
    }
  }

  /// Analyze question quality using AI
  Future<QuestionAnalysis> analyzeQuestion(QuestionModel question) async {
    final prompt = _buildAnalysisPrompt(question);

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': AiServiceConfig.apiVersion,
        },
        body: jsonEncode({
          'model': AiServiceConfig.model,
          'max_tokens': 1000,
          'temperature': 0.3, // Lower temperature for analysis
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200) {
        return QuestionAnalysis.empty();
      }

      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'];

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        return QuestionAnalysis.fromJson(jsonDecode(jsonMatch.group(0)!));
      }

      return QuestionAnalysis.empty();
    } catch (e) {
      return QuestionAnalysis.empty();
    }
  }

  /// Build ORT-specific optimized prompt
  String _buildOrtPrompt({
    required String subjectId,
    required String sectionId,
    required String topic,
    required int difficulty,
    required int count,
    required List<QuestionType> questionTypes,
    required List<String> languages,
    String? additionalInstructions,
    List<String>? avoidSimilarTo,
  }) {
    // Get section info
    final section = OrtConstants.mainSectionsList.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => OrtConstants.mainSectionsList.first,
    );

    final difficultyDesc = _getDifficultyDescription(difficulty);
    final typeInstructions = _getTypeInstructions(questionTypes);
    final languageList = _getLanguageNames(languages);

    return '''
Ты эксперт по созданию тестовых вопросов для ОРТ (Общереспубликанское тестирование) Кыргызстана.

ЗАДАЧА: Создай $count уникальных вопросов высокого качества

ПАРАМЕТРЫ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Раздел ОРТ: ${section.nameRu} (${section.descriptionRu})
Предмет: $subjectId
Тема: $topic
Сложность: $difficulty/3 ($difficultyDesc)
Количество: $count вопросов
Языки: $languageList

ТИПЫ ВОПРОСОВ:
$typeInstructions

ТРЕБОВАНИЯ К ВОПРОСАМ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. ФОРМАТ ОРТ: Строго 5 вариантов ответа (A, B, C, D, E)
2. ОДИН ПРАВИЛЬНЫЙ: Только ОДИН вариант должен быть правильным
3. ДИСТРАКТОРЫ: Неправильные ответы должны быть:
   - Правдоподобными
   - Отражающими типичные ошибки учеников
   - Не очевидно неверными
4. ЯЗЫК: Академический, ясный, без двусмысленности
5. СЛОЖНОСТЬ: Соответствовать заявленному уровню $difficulty/3
6. УНИКАЛЬНОСТЬ: Каждый вопрос должен быть оригинальным
7. ФОРМУЛЫ: Если есть формулы, использовать plain text или LaTeX

СТРУКТУРА СЛОЖНОСТИ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Уровень 1 (Лёгкий):
  - Прямое применение базовых знаний
  - Определения, факты, простые вычисления
  - Ученик должен просто вспомнить информацию

Уровень 2 (Средний):
  - Применение знаний в стандартных ситуациях
  - Требуется анализ, сравнение
  - Многошаговые решения (2-3 шага)

Уровень 3 (Сложный):
  - Синтез, критическое мышление
  - Нестандартные ситуации
  - Комбинирование нескольких концепций
  - Многошаговые решения (4+ шага)

${additionalInstructions != null ? '''
ДОПОЛНИТЕЛЬНЫЕ ИНСТРУКЦИИ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$additionalInstructions
''' : ''}

${avoidSimilarTo != null && avoidSimilarTo.isNotEmpty ? '''
ИЗБЕГАТЬ ПОХОЖИХ ВОПРОСОВ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Не создавай вопросы слишком похожие на эти:
${avoidSimilarTo.take(5).map((q) => '- $q').join('\n')}
''' : ''}

ФОРМАТ ОТВЕТА (СТРОГО JSON):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "questions": [
    {
      "stem": {
        "ru": "Текст вопроса на русском",
        "ky": "Кыргызча суроонун тексти",
        "en": "Question text in English"
      },
      "options": [
        {
          "id": "A",
          "text": {
            "ru": "Вариант A",
            "ky": "Вариант A",
            "en": "Option A"
          },
          "is_correct": false
        },
        {
          "id": "B",
          "text": {
            "ru": "Вариант B (ПРАВИЛЬНЫЙ)",
            "ky": "Вариант B (ТУУРА)",
            "en": "Option B (CORRECT)"
          },
          "is_correct": true
        },
        {
          "id": "C",
          "text": {
            "ru": "Вариант C",
            "ky": "Вариант C",
            "en": "Option C"
          },
          "is_correct": false
        },
        {
          "id": "D",
          "text": {
            "ru": "Вариант D",
            "ky": "Вариант D",
            "en": "Option D"
          },
          "is_correct": false
        },
        {
          "id": "E",
          "text": {
            "ru": "Вариант E",
            "ky": "Вариант E",
            "en": "Option E"
          },
          "is_correct": false
        }
      ],
      "correct_answer": "B",
      "explanation": {
        "ru": "Подробное объяснение решения с пошаговыми действиями",
        "ky": "Чечимдин деталдуу түшүндүрмөсү кадам-кадам",
        "en": "Detailed step-by-step solution explanation"
      },
      "tags": ["тег1", "тег2", "тег3"],
      "difficulty": $difficulty,
      "subject_id": "$subjectId",
      "section_id": "$sectionId"
    }
  ]
}

ВАЖНО:
- Верни ТОЛЬКО валидный JSON без дополнительного текста до или после
- Все $count вопросов должны быть в массиве "questions"
- Каждый вопрос должен иметь ВСЕ указанные поля
- Explanation должен быть максимально подробным и понятным
''';
  }

  /// Build explanation generation prompt
  String _buildExplanationPrompt(
    QuestionModel question,
    List<String> languages,
  ) {
    final languageList = _getLanguageNames(languages);

    return '''
Объясни решение следующего вопроса из ОРТ теста:

ВОПРОС: ${question.getStem('ru')}

ВАРИАНТЫ ОТВЕТОВ:
${question.options.map((o) => '${o.id}) ${o.getText('ru')}').join('\n')}

ПРАВИЛЬНЫЙ ОТВЕТ: ${question.correctAnswer}

ЗАДАЧА:
Предоставь подробное объяснение на языках: $languageList

ТРЕБОВАНИЯ К ОБЪЯСНЕНИЮ:
1. Понятно для школьника
2. Пошаговое решение
3. Указание ключевых концепций
4. Типичные ошибки, которых следует избегать
5. Дополнительные советы (если применимо)

ФОРМАТ ОТВЕТА (JSON):
{
  "explanation": {
    "ru": "Подробное объяснение на русском...",
    "ky": "Кыргызча толук түшүндүрмө...",
    "en": "Detailed explanation in English..."
  },
  "key_points": ["Ключевая концепция 1", "Ключевая концепция 2"],
  "common_mistakes": ["Типичная ошибка 1", "Типичная ошибка 2"]
}

Верни ТОЛЬКО валидный JSON!
''';
  }

  /// Build quality analysis prompt
  String _buildAnalysisPrompt(QuestionModel question) {
    return '''
Проанализируй качество следующего вопроса для ОРТ:

ВОПРОС: ${question.getStem('ru')}

ВАРИАНТЫ:
${question.options.map((o) => '${o.id}) ${o.getText('ru')}').join('\n')}

ПРАВИЛЬНЫЙ ОТВЕТ: ${question.correctAnswer}
СЛОЖНОСТЬ: ${question.difficulty}/3

КРИТЕРИИ ОЦЕНКИ (шкала 1-10):
1. Clarity (Ясность формулировки)
2. Distractors (Качество дистракторов)
3. Difficulty (Соответствие уровню сложности)
4. Unambiguity (Однозначность правильного ответа)
5. ORT Format (Соответствие формату ОРТ)

ФОРМАТ ОТВЕТА (JSON):
{
  "scores": {
    "clarity": 8,
    "distractors": 7,
    "difficulty": 9,
    "unambiguity": 10,
    "ortFormat": 8
  },
  "overallScore": 8.4,
  "issues": [
    "Описание проблемы 1",
    "Описание проблемы 2"
  ],
  "suggestions": [
    "Рекомендация по улучшению 1",
    "Рекомендация по улучшению 2"
  ]
}

Верни ТОЛЬКО валидный JSON!
''';
  }

  /// Parse questions from AI response
  List<GeneratedQuestion> _parseQuestionsFromResponse(
    String content,
    String subjectId,
    String sectionId,
  ) {
    try {
      // Extract JSON from response (in case there's extra text)
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) {
        throw AIServiceException('No JSON found in response', content);
      }

      final data = jsonDecode(jsonMatch.group(0)!);
      final questionsData = data['questions'] as List;

      return questionsData.map((q) {
        return GeneratedQuestion(
          stem: Map<String, String>.from(q['stem'] ?? {}),
          options: (q['options'] as List).map((o) {
            return GeneratedOption(
              id: o['id'] ?? '',
              text: Map<String, String>.from(o['text'] ?? {}),
              isCorrect: o['is_correct'] ?? false,
            );
          }).toList(),
          correctAnswer: q['correct_answer'] ?? '',
          explanation: q['explanation'] != null
              ? Map<String, String>.from(q['explanation'])
              : null,
          difficulty: q['difficulty'] ?? 1,
          tags: List<String>.from(q['tags'] ?? []),
          subjectId: q['subject_id'] ?? subjectId,
          sectionId: q['section_id'] ?? sectionId,
        );
      }).toList();
    } catch (e) {
      throw AIServiceException('Failed to parse AI response', e.toString());
    }
  }

  /// Calculate estimated cost based on tokens
  double _calculateCost(int tokens) {
    // Claude 3.5 Sonnet pricing (as of 2024):
    // Input: $3 per million tokens
    // Output: $15 per million tokens
    // For simplicity, using average: ~$9 per million tokens
    // Which is $0.009 per 1K tokens
    return (tokens / 1000) * 0.009;
  }

  /// Get difficulty description
  String _getDifficultyDescription(int difficulty) {
    switch (difficulty) {
      case 1:
        return 'Лёгкий - базовые знания, прямые вопросы, определения';
      case 2:
        return 'Средний - применение знаний, анализ, многошаговые решения';
      case 3:
        return 'Сложный - синтез, критическое мышление, нестандартные ситуации';
      default:
        return 'Средний';
    }
  }

  /// Get type instructions
  String _getTypeInstructions(List<QuestionType> types) {
    return types.map((t) {
      switch (t) {
        case QuestionType.singleChoice:
          return '• Single Choice: Один правильный ответ из 5 вариантов (A-E)';
        case QuestionType.analogy:
          return '• Analogy: Формат "A : B = C : ?" для проверки логического мышления';
        case QuestionType.completion:
          return '• Completion: Дополнение предложений с пропуском';
        case QuestionType.textBased:
          return '• Text-based: Вопросы к прочитанному тексту';
        default:
          return '• Стандартный формат ОРТ';
      }
    }).join('\n');
  }

  /// Get language names
  String _getLanguageNames(List<String> languages) {
    return languages.map((lang) {
      switch (lang) {
        case 'ru':
          return 'Русский';
        case 'ky':
          return 'Кыргызский';
        case 'en':
          return 'English';
        default:
          return lang;
      }
    }).join(', ');
  }

  /// Detect duplicate questions using Levenshtein distance
  Future<List<String>> detectDuplicates(
    String questionText,
    List<String> existingQuestions,
  ) async {
    final duplicates = <String>[];
    final normalized = questionText.toLowerCase().trim();

    for (var existing in existingQuestions) {
      final existingNormalized = existing.toLowerCase().trim();
      if (_calculateSimilarity(normalized, existingNormalized) > 0.8) {
        duplicates.add(existing);
      }
    }

    return duplicates;
  }

  /// Calculate text similarity using Levenshtein distance
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.isEmpty) return 1.0;

    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// Levenshtein distance algorithm
  int _levenshteinDistance(String s1, String s2) {
    final costs = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i <= s1.length; i++) {
      var lastValue = i;
      for (var j = 0; j <= s2.length; j++) {
        if (i == 0) {
          costs[j] = j;
        } else if (j > 0) {
          var newValue = costs[j - 1];
          if (s1[i - 1] != s2[j - 1]) {
            newValue =
                [newValue, lastValue, costs[j]].reduce((a, b) => a < b ? a : b) +
                    1;
          }
          costs[j - 1] = lastValue;
          lastValue = newValue;
        }
      }
      if (i > 0) costs[s2.length] = lastValue;
    }

    return costs[s2.length];
  }
}
