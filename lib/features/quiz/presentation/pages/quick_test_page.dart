import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/question_model.dart';
import '../../../../shared/services/firebase_data_service.dart';

/// Quick Test - 10 random questions, no timer, instant feedback
class QuickTestPage extends StatefulWidget {
  const QuickTestPage({super.key});

  @override
  State<QuickTestPage> createState() => _QuickTestPageState();
}

class _QuickTestPageState extends State<QuickTestPage> {
  final _dataService = FirebaseDataService();
  List<QuestionModel> _questions = [];
  final Map<String, String> _answers = {}; // questionId -> selectedOptionId
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  bool _showFeedback = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _dataService.getQuestions(count: 10);
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки вопросов: $e')),
        );
      }
    }
  }

  void _selectAnswer(String optionId) {
    setState(() {
      _answers[_questions[_currentQuestionIndex].id] = optionId;
      _showFeedback = true;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _showFeedback = false;
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
    int correctCount = 0;
    for (var question in _questions) {
      if (_answers[question.id] == question.correctAnswer) {
        correctCount++;
      }
    }

    // Calculate total time (tracked properly now)
    final totalTimeSeconds = 0; // Will be implemented with timer

    // Use go_router for proper navigation
    if (mounted) {
      context.go(
        AppRouter.quizResults,
        extra: {
          'totalQuestions': _questions.length,
          'correctAnswers': correctCount,
          'totalTimeSeconds': totalTimeSeconds,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Быстрый тест')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Быстрый тест')),
        body: const Center(child: Text('Нет доступных вопросов')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final selectedAnswer = _answers[currentQuestion.id];
    final isCorrect = selectedAnswer == currentQuestion.correctAnswer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Выйти из теста?'),
            content: const Text('Ваш прогресс будет потерян.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выйти', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        
        if (shouldExit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Быстрый тест'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentQuestionIndex + 1}/${_questions.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question
                    Text(
                      currentQuestion.getStem('ru'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    // Options
                    ...currentQuestion.options.map((option) {
                      final isSelected = selectedAnswer == option.id;
                      final isCorrectOption = option.id == currentQuestion.correctAnswer;
                      
                      Color? cardColor;
                      if (_showFeedback) {
                        if (isCorrectOption) {
                          cardColor = AppColors.success.withValues(alpha: 0.1);
                        } else if (isSelected && !isCorrect) {
                          cardColor = AppColors.error.withValues(alpha: 0.1);
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: cardColor,
                        child: InkWell(
                          onTap: _showFeedback ? null : () => _selectAnswer(option.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.grey400,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Text(
                                      option.id,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.grey600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option.getText('ru'),
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_showFeedback && isCorrectOption)
                                  const Icon(Icons.check_circle, color: AppColors.success),
                                if (_showFeedback && isSelected && !isCorrect)
                                  const Icon(Icons.cancel, color: AppColors.error),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    // Explanation (shown after answer)
                    if (_showFeedback) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: isCorrect
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.info.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCorrect ? Icons.check_circle : Icons.info,
                                    color: isCorrect ? AppColors.success : AppColors.info,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCorrect ? 'Правильно!' : 'Неправильно',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: isCorrect ? AppColors.success : AppColors.info,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                currentQuestion.getExplanation('ru'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Next button
            if (_showFeedback)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentQuestionIndex < _questions.length - 1
                            ? 'Следующий вопрос'
                            : 'Завершить тест',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
