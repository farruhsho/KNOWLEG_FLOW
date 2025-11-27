import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question_model.dart';
import '../../core/theme/app_colors.dart';

/// AI Explainer Modal for wrong answers
/// Shows "Why wrong? Tip:" explanations with AI-generated insights
class AIExplainerModal extends StatelessWidget {
  final QuestionModel question;
  final String userAnswer;
  final VoidCallback? onRetry;
  final VoidCallback? onNext;

  const AIExplainerModal({
    super.key,
    required this.question,
    required this.userAnswer,
    this.onRetry,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = userAnswer == question.correctAnswer;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isCorrect ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? AppColors.success : AppColors.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCorrect ? 'Правильно!' : 'Неправильно',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: isCorrect ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (!isCorrect)
                          Text(
                            'Правильный ответ: ${question.correctAnswer}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Question
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.getStem('ru'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),

              const SizedBox(height: 20),

              // Explanation
              Text(
                'Объяснение',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                question.getExplanation('ru'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              if (!isCorrect) ...[
                const SizedBox(height: 20),

                // AI Tip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.accent.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Почему неправильно? Совет:',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _generateAITip(question, userAnswer),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  if (onRetry != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onRetry?.call();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Попробовать снова'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (onRetry != null && onNext != null) const SizedBox(width: 12),
                  if (onNext != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onNext?.call();
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Следующий'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generate AI tip based on question and wrong answer
  /// In production, this would call an AI API
  String _generateAITip(QuestionModel question, String wrongAnswer) {
    // Mock AI-generated tips based on difficulty
    if (question.difficulty <= 2) {
      return 'Обратите внимание на ключевые слова в вопросе. '
          'Попробуйте исключить явно неправильные варианты и сосредоточьтесь на оставшихся. '
          'Перечитайте вопрос внимательно перед выбором ответа.';
    } else if (question.difficulty <= 3) {
      return 'Этот вопрос требует понимания основных концепций. '
          'Рекомендуем повторить теорию по этой теме. '
          'Обратите внимание на детали в формулировке вопроса - они часто содержат подсказки.';
    } else {
      return 'Это сложный вопрос, требующий глубокого понимания материала. '
          'Попробуйте разбить вопрос на части и проанализировать каждую. '
          'Рекомендуем дополнительно изучить эту тему и решить похожие задачи.';
    }
  }

  /// Show the AI Explainer Modal
  static Future<void> show(
    BuildContext context, {
    required QuestionModel question,
    required String userAnswer,
    VoidCallback? onRetry,
    VoidCallback? onNext,
  }) {
    // Add haptic feedback
    HapticFeedback.mediumImpact();
    
    return showDialog(
      context: context,
      builder: (context) => AIExplainerModal(
        question: question,
        userAnswer: userAnswer,
        onRetry: onRetry,
        onNext: onNext,
      ),
    );
  }
}
