import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuizPage extends StatefulWidget {
  final String quizId;

  const QuizPage({
    super.key,
    required this.quizId,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentQuestion = 0;
  final int _totalQuestions = 10;
  String? _selectedAnswer;
  final Map<int, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Вопрос ${_currentQuestion + 1} из $_totalQuestions'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                '⏱ 10:00',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentQuestion + 1) / _totalQuestions,
              backgroundColor: AppColors.grey200,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Вопрос ${_currentQuestion + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.primary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Сколько будет 2 + 2?',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options
                    Text(
                      'Выберите ответ:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    ..._buildOptions(),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentQuestion > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousQuestion,
                        child: const Text('Назад'),
                      ),
                    ),
                  if (_currentQuestion > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedAnswer != null
                          ? (_currentQuestion < _totalQuestions - 1
                              ? _nextQuestion
                              : _finishQuiz)
                          : null,
                      child: Text(
                        _currentQuestion < _totalQuestions - 1
                            ? 'Следующий'
                            : 'Завершить',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    final options = [
      {'id': 'A', 'text': '3'},
      {'id': 'B', 'text': '4'},
      {'id': 'C', 'text': '5'},
      {'id': 'D', 'text': '6'},
    ];

    return options.map((option) {
      final isSelected = _selectedAnswer == option['id'];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedAnswer = option['id'] as String;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.grey300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : AppColors.grey200,
                  ),
                  child: Center(
                    child: Text(
                      option['id'] as String,
                      style: TextStyle(
                        color: isSelected ? AppColors.white : AppColors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option['text'] as String,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _nextQuestion() {
    if (_selectedAnswer != null) {
      setState(() {
        _answers[_currentQuestion] = _selectedAnswer!;
        _currentQuestion++;
        _selectedAnswer = _answers[_currentQuestion];
      });
    }
  }

  void _previousQuestion() {
    setState(() {
      _currentQuestion--;
      _selectedAnswer = _answers[_currentQuestion];
    });
  }

  void _finishQuiz() {
    if (_selectedAnswer != null) {
      _answers[_currentQuestion] = _selectedAnswer!;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить тест?'),
        content: Text(
          'Вы ответили на ${_answers.length} из $_totalQuestions вопросов.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // TODO: Navigate to results page
            },
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
  }
}
