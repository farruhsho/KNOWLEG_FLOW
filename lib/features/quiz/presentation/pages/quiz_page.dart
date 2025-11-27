import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/models/gamification_models.dart';
import '../../../../shared/models/question_model.dart';
import '../../../../shared/widgets/glass_container.dart';

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
      // ignore: avoid_print
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Загрузка теста...',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
                onPressed: () => context.go('/dashboard'),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQ = _questions[_currentQuestion];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with Timer and Progress
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.grey200.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => context.pop(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '10:00',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_currentQuestion + 1}/$_totalQuestions',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentQuestion + 1) / _totalQuestions,
                      backgroundColor: AppColors.grey200,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.grey200.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(currentQ.difficulty)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getDifficultyText(currentQ.difficulty),
                                    style: TextStyle(
                                      color: _getDifficultyColor(currentQ.difficulty),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentQ.getStem('ru'),
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Options
                      Text(
                        'Выберите ответ:',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentQuestion > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousQuestion,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: AppColors.grey300),
                        ),
                        child: const Text('Назад'),
                      ),
                    ),
                  if (_currentQuestion > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedAnswer != null
                          ? (_currentQuestion < _totalQuestions - 1
                              ? _nextQuestion
                              : _finishQuiz)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentQuestion < _totalQuestions - 1
                            ? 'Следующий вопрос'
                            : 'Завершить тест',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
            HapticFeedback.selectionClick();
            setState(() {
              _selectedAnswer = option.id;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.grey200,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.white,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : AppColors.grey100,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.grey300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      option.id,
                      style: TextStyle(
                        color: isSelected ? AppColors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option.getText('ru'),
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
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

      // Navigate back to dashboard
      if (!mounted) return;
      context.go('/dashboard');
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                            colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)],
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
