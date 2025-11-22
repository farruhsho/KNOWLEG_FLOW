import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class MockTestPage extends StatelessWidget {
  final String testId;

  const MockTestPage({
    super.key,
    required this.testId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пробный экзамен ОРТ'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Полная симуляция ОРТ',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(
                                  'Тест #$testId',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(
                        context,
                        Icons.quiz,
                        'Вопросов',
                        '${AppConstants.totalQuestions}',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.access_time,
                        'Время',
                        '${AppConstants.totalTimeMinutes} минут',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.star,
                        'Макс. балл',
                        '${AppConstants.maxScore}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sections
              Text(
                'Секции теста',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              _buildSectionCard(
                context,
                title: 'Раздел 1: Основной тест',
                questions: AppConstants.mainTestQuestions,
                time: AppConstants.mainTestTimeMinutes,
                description:
                    'Вербальная часть (30 вопросов) + Математическая часть (30 вопросов)',
                color: AppColors.primary,
              ),

              const SizedBox(height: 12),

              _buildSectionCard(
                context,
                title: 'Раздел 2: Предметный тест',
                questions: AppConstants.subjectTestQuestions,
                time: AppConstants.subjectTestTimeMinutes,
                description: 'Выбранный предмет (Математика, Физика, и т.д.)',
                color: AppColors.secondary,
              ),

              const SizedBox(height: 12),

              _buildSectionCard(
                context,
                title: 'Раздел 3: Языковой тест',
                questions: AppConstants.languageTestQuestions,
                time: AppConstants.languageTestTimeMinutes,
                description: 'Кыргызский, Русский или Английский язык',
                color: AppColors.accent,
              ),

              const SizedBox(height: 32),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showStartDialog(context);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Начать тест'),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Rules
              Card(
                color: AppColors.grey50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Правила тестирования',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRuleItem('• Тест нельзя прервать и вернуться позже'),
                      _buildRuleItem(
                          '• Каждая секция имеет свой таймер'),
                      _buildRuleItem(
                          '• Результаты доступны сразу после завершения'),
                      _buildRuleItem(
                          '• Все вопросы с множественным выбором (4 варианта)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required int questions,
    required int time,
    required String description,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text('$questions вопросов',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Icon(Icons.timer, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text('$time мин',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text),
    );
  }

  void _showStartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Начать тест?'),
        content: const Text(
          'После начала теста вы не сможете его прервать. '
          'Убедитесь, что у вас есть 3 часа 15 минут свободного времени.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to test runner
            },
            child: const Text('Начать'),
          ),
        ],
      ),
    );
  }
}
