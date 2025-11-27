import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/question_model.dart';

/// Quiz review page - simplified version
class QuizReviewPage extends StatelessWidget {
  final List<QuestionModel> questions;
  final Map<String, String> userAnswers;
  final int totalScore;
  final int totalQuestions;

  const QuizReviewPage({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.totalScore,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final correctCount = _calculateCorrectAnswers();
    final percentage = (correctCount / totalQuestions * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Разбор теста'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '$correctCount/$totalQuestions',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Правильных ответов: $percentage%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Разбор вопросов',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final userAnswer = userAnswers[question.id];
              final isCorrect = userAnswer == question.correctAnswer;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Text('Вопрос ${index + 1}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(question.getStem('ru')),
                      const SizedBox(height: 8),
                      if (!isCorrect) ...[
                        Text(
                          'Правильный ответ: ${question.correctAnswer}',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Закрыть'),
        ),
      ),
    );
  }

  int _calculateCorrectAnswers() {
    int count = 0;
    for (final question in questions) {
      if (userAnswers[question.id] == question.correctAnswer) {
        count++;
      }
    }
    return count;
  }
}
