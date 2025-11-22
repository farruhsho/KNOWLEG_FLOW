import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/app_router.dart';

class QuizResultsPage extends StatefulWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int totalTimeSeconds;

  const QuizResultsPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalTimeSeconds,
  });

  @override
  State<QuizResultsPage> createState() => _QuizResultsPageState();
}

class _QuizResultsPageState extends State<QuizResultsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.correctAnswers / widget.totalQuestions * 100).round();
    final incorrectAnswers = widget.totalQuestions - widget.correctAnswers;
    final avgTimePerQuestion = widget.totalTimeSeconds / widget.totalQuestions;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Score circle
              ScaleTransition(
                scale: _scaleAnimation,
                child: _buildScoreCircle(context, percentage),
              ),

              const SizedBox(height: 32),

              // Result message
              Text(
                _getResultMessage(percentage),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Вы ответили правильно на ${widget.correctAnswers} из ${widget.totalQuestions} вопросов',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Stats cards
              FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.check_circle,
                        label: 'Правильно',
                        value: widget.correctAnswers.toString(),
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.cancel,
                        label: 'Неправильно',
                        value: incorrectAnswers.toString(),
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.access_time,
                        label: 'Общее время',
                        value: _formatTime(widget.totalTimeSeconds),
                        color: AppColors.info,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.timer,
                      label: 'Среднее время',
                      value: '${avgTimePerQuestion.toStringAsFixed(1)}с',
                      color: AppColors.warning,
                    ),
                  ),
                ],
                ),
              ),

              const SizedBox(height: 32),

              // Performance breakdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Детальная статистика',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      _buildProgressRow(
                        context,
                        'Правильные ответы',
                        widget.correctAnswers,
                        widget.totalQuestions,
                        AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      _buildProgressRow(
                        context,
                        'Неправильные ответы',
                        incorrectAnswers,
                        widget.totalQuestions,
                        AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Show detailed review
                  },
                  icon: const Icon(Icons.preview),
                  label: const Text('Посмотреть разбор'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Retry quiz
                    context.pop();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Пройти еще раз'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    context.go(AppRouter.dashboard);
                  },
                  child: const Text('Вернуться на главную'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle(BuildContext context, int percentage) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        children: [
          // Background circle
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: percentage / 100,
                strokeWidth: 12,
                backgroundColor: AppColors.grey200,
                valueColor: AlwaysStoppedAnimation(
                  _getScoreColor(percentage),
                ),
              ),
            ),
          ),
          // Score text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: _getScoreColor(percentage),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Результат',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    String label,
    int value,
    int total,
    Color color,
  ) {
    final percentage = value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$value/$total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: AppColors.grey200,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return AppColors.success;
    if (percentage >= 60) return AppColors.info;
    if (percentage >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _getResultMessage(int percentage) {
    if (percentage >= 90) return 'Отлично!';
    if (percentage >= 70) return 'Хорошо!';
    if (percentage >= 50) return 'Неплохо!';
    return 'Нужно больше практики';
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}м ${secs}с';
    }
    return '${secs}с';
  }
}
