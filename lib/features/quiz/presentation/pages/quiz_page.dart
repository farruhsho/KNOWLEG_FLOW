import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/models/gamification_models.dart';
import '../../../../shared/models/question_model.dart';

class QuizPage extends StatefulWidget {
  final String quizId;

  const QuizPage({
    super.key,
    required this.quizId,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with SingleTickerProviderStateMixin {
  final _firebaseDataService = FirebaseDataService();
  List<QuestionModel> _questions = [];
  bool _isLoading = true;
  int _currentQuestion = 0;
  int get _totalQuestions => _questions.length;
  String? _selectedAnswer;
  final Map<int, String> _answers = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'current_user';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _firebaseDataService.getQuestions(
        count: 10,
        subjectId: widget.quizId,
      );
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      print('❌ Error loading questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загрузка теста...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Тест')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 80, color: AppColors.grey400),
              const SizedBox(height: 16),
              const Text('Вопросы не найдены'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQ = _questions[_currentQuestion];

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
              child: FadeTransition(
                opacity: _fadeAnimation,
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
                              currentQ.getStem('ru'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (currentQ.difficulty != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.signal_cellular_alt,
                                    size: 16,
                                    color: _getDifficultyColor(currentQ.difficulty!),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getDifficultyText(currentQ.difficulty!),
                                    style: TextStyle(
                                      color: _getDifficultyColor(currentQ.difficulty!),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Color _getDifficultyColor(int difficulty) {
    if (difficulty <= 2) return AppColors.success;
    if (difficulty <= 3) return AppColors.warning;
    return AppColors.error;
  }

  String _getDifficultyText(int difficulty) {
    if (difficulty <= 2) return 'Легкий';
    if (difficulty <= 3) return 'Средний';
    return 'Сложный';
  }

  List<Widget> _buildOptions() {
    if (_questions.isEmpty) return [];
    final currentQ = _questions[_currentQuestion];
    final options = currentQ.options;

    return options.map((option) {
      final isSelected = _selectedAnswer == option.id;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedAnswer = option.id;
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
                      option.id,
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
                    option.getText('ru'),
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
      _animationController.reverse().then((_) {
        setState(() {
          _answers[_currentQuestion] = _selectedAnswer!;
          _currentQuestion++;
          _selectedAnswer = _answers[_currentQuestion];
        });
        _animationController.forward();
      });
    }
  }

  void _previousQuestion() {
    _animationController.reverse().then((_) {
      setState(() {
        _currentQuestion--;
        _selectedAnswer = _answers[_currentQuestion];
      });
      _animationController.forward();
    });
  }

  void _finishQuiz() async {
    if (_selectedAnswer != null) {
      _answers[_currentQuestion] = _selectedAnswer!;
    }

    final answeredCount = _answers.length;
    final isComplete = answeredCount == _totalQuestions;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isComplete ? 'Завершить тест?' : 'Не все вопросы отвечены'),
        content: Text(
          isComplete
              ? 'Вы ответили на все вопросы. Завершить тест?'
              : 'Вы ответили на $answeredCount из $_totalQuestions вопросов. Все равно завершить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isComplete
                ? null
                : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                  ),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Award XP for completing quiz
    final gamificationService = GamificationService();

    // Calculate XP based on answers
    final correctAnswers = _calculateCorrectAnswers();
    final baseXP = 50; // Base XP for completing quiz
    final bonusXP = correctAnswers * 5; // 5 XP per correct answer
    final totalXP = baseXP + bonusXP;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userId = _currentUserId;

      // Award XP
      final reward = await gamificationService.awardXP(
        userId,
        totalXP,
        'Quiz completed',
      );

      // Update Firebase user progress statistics
      final scorePercentage = (correctAnswers / _totalQuestions * 240).round();
      await _firebaseDataService.updateTestStats(
        userId,
        scorePercentage,
        _totalQuestions,
        widget.quizId,
      );

      // Update gamification statistics
      await gamificationService.updateStatistic(
        userId,
        'testsCompleted',
        1,
      );
      await gamificationService.updateStatistic(
        userId,
        'questionsAnswered',
        answeredCount,
      );

      if (correctAnswers == _totalQuestions) {
        await gamificationService.updateStatistic(
          userId,
          'perfectScores',
          1,
        );
      }

      // Update daily quests
      final quests = await gamificationService.getDailyQuests(userId);
      for (final quest in quests) {
        if (quest.type == QuestType.completeTest && !quest.isCompleted) {
          await gamificationService.updateQuestProgress(userId, quest.id, 1);
        } else if (quest.type == QuestType.answerQuestions && !quest.isCompleted) {
          await gamificationService.updateQuestProgress(
            userId,
            quest.id,
            answeredCount,
          );
        }
      }

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show reward animation
      await _showRewardDialog(reward, correctAnswers);

      // Navigate back
      if (!mounted) return;
      context.pop();
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить результаты')),
      );
    }
  }

  int _calculateCorrectAnswers() {
    int correctCount = 0;

    for (var entry in _answers.entries) {
      final questionIndex = entry.key;
      final userAnswer = entry.value;

      if (questionIndex < _questions.length) {
        final question = _questions[questionIndex];
        if (question.correctAnswer == userAnswer) {
          correctCount++;
        }
      }
    }

    return correctCount;
  }

  Future<void> _showRewardDialog(XPReward reward, int correctAnswers) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Тест завершён!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Правильных ответов: $correctAnswers/$_totalQuestions',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Rewards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.star, color: AppColors.warning, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              '+${reward.xpGained} XP',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        if (reward.coinsGained > 0)
                          Column(
                            children: [
                              const Icon(Icons.monetization_on,
                                  color: Colors.amber, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                '+${reward.coinsGained}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (reward.levelUp) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_upward, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Уровень ${reward.newLevel}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Отлично!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
