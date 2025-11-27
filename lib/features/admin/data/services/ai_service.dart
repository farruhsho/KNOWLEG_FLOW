import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_models.dart';

/// AI service for question generation
class AiService {
  final String apiKey;

  AiService({required this.apiKey});

  /// Generate questions using Claude API
  Future<AiQuestionResponse> generateQuestions(
    AiQuestionRequest request,
  ) async {
    final prompt = _buildPrompt(request);

    try {
      final response = await http.post(
        Uri.parse(AiServiceConfig.apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': AiServiceConfig.model,
          'max_tokens': AiServiceConfig.maxTokens,
          'temperature': AiServiceConfig.temperature,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'];
        final questionsJson = jsonDecode(content);

        return AiQuestionResponse(
          questions: (questionsJson['questions'] as List)
              .map((q) => GeneratedQuestion.fromJson(q))
              .toList(),
          tokensUsed: data['usage']['output_tokens'] ?? 0,
          model: data['model'] ?? '',
        );
      } else {
        throw Exception('AI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate questions: $e');
    }
  }

  /// Build prompt for Claude
  String _buildPrompt(AiQuestionRequest request) {
    return '''
Ты - эксперт по созданию тестовых вопросов для ОРТ (Общереспубликанское тестирование) Кыргызстана.

ЗАДАНИЕ:
Создай ${request.count} тестовых вопросов по следующим параметрам:
- Предмет: ${request.subjectId}
- Тема: ${request.topic}
- Сложность: ${request.difficulty} (1-легко, 2-средне, 3-сложно)
- Язык: ${request.language}
${request.context != null ? '- Контекст: ${request.context}' : ''}
${request.tags != null ? '- Теги: ${request.tags!.join(", ")}' : ''}

ТРЕБОВАНИЯ К ВОПРОСАМ:
1. Каждый вопрос должен иметь 5 вариантов ответа (A, B, C, D, E)
2. Только один правильный ответ
3. Вопросы должны соответствовать формату ОРТ
4. Используй академический язык
5. Вопросы должны быть четкими и однозначными
6. Дистракторы (неправильные ответы) должны быть правдоподобными

ФОРМАТ ОТВЕТА (строго JSON):
{
  "questions": [
    {
      "stem": {
        "ru": "Текст вопроса на русском",
        "ky": "Суроонун тексти кыргызча",
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
            "ru": "Вариант B (правильный)",
            "ky": "Вариант B (туура)",
            "en": "Option B (correct)"
          },
          "is_correct": true
        },
        // ... остальные варианты C, D, E
      ],
      "correct_answer": "B",
      "explanation": {
        "ru": "Объяснение почему B правильный",
        "ky": "Түшүндүрмө эмне үчүн B туура",
        "en": "Explanation why B is correct"
      },
      "tags": ["тег1", "тег2"],
      "difficulty": ${request.difficulty}
    }
  ]
}

ВАЖНО: Верни ТОЛЬКО валидный JSON, без дополнительного текста!
''';
  }

  /// Detect duplicate questions
  Future<List<String>> detectDuplicates(
    String questionText,
    List<String> existingQuestions,
  ) async {
    // TODO: Implement semantic similarity check using embeddings
    // For now, simple text matching
    final duplicates = <String>[];
    final normalized = questionText.toLowerCase().trim();

    for (var i = 0; i < existingQuestions.length; i++) {
      final existing = existingQuestions[i].toLowerCase().trim();
      if (_calculateSimilarity(normalized, existing) > 0.8) {
        duplicates.add(existingQuestions[i]);
      }
    }

    return duplicates;
  }

  /// Calculate text similarity (simple Levenshtein-based)
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.length == 0) return 1.0;

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
            newValue = [newValue, lastValue, costs[j]].reduce((a, b) => a < b ? a : b) + 1;
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
