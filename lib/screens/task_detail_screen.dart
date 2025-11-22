import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knowledge_flow/models/task.dart';
import 'package:knowledge_flow/providers/task_provider.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  int currentQuestionIndex = 0;
  Map<int, int> userAnswers = {};
  bool isQuizCompleted = false;
  bool showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final taskProviderInstance = ref.watch(taskProvider);
    final task = taskProviderInstance.getTaskById(widget.taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Задание не найдено')),
      );
    }

    if (task.isCompleted && !isQuizCompleted) {
      return _buildCompletedView(task);
    }

    if (isQuizCompleted) {
      return _buildResultsView(task);
    }

    return _buildQuizView(task);
  }

  Widget _buildCompletedView(Task task) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задание выполнено'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Вы уже выполнили это задание!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ваш результат: ${task.score}/${task.questions.length * 10}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    currentQuestionIndex = 0;
                    userAnswers.clear();
                    isQuizCompleted = false;
                    showExplanation = false;
                  });
                  ref.read(taskProvider.notifier).resetTask(widget.taskId);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Пройти заново'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizView(Task task) {
    final question = task.questions[currentQuestionIndex];
    final selectedAnswer = userAnswers[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / task.questions.length,
            minHeight: 6,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Вопрос ${currentQuestionIndex + 1} из ${task.questions.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...List.generate(
                    question.options.length,
                    (index) => _buildOptionCard(
                      question.options[index],
                      index,
                      selectedAnswer,
                    ),
                  ),
                  if (showExplanation && selectedAnswer != null) ...[
                    const SizedBox(height: 24),
                    _buildExplanationCard(question, selectedAnswer),
                  ],
                ],
              ),
            ),
          ),
          _buildNavigationButtons(task),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option, int index, int? selectedAnswer) {
    final isSelected = selectedAnswer == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: showExplanation
            ? null
            : () {
                setState(() {
                  userAnswers[currentQuestionIndex] = index;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(Question question, int selectedAnswer) {
    final isCorrect = selectedAnswer == question.correctAnswerIndex;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isCorrect ? 'Правильно!' : 'Неправильно',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isCorrect) ...[
            Text(
              'Правильный ответ: ${question.options[question.correctAnswerIndex]}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            question.explanation,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(Task task) {
    final selectedAnswer = userAnswers[currentQuestionIndex];
    final isLastQuestion = currentQuestionIndex == task.questions.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    currentQuestionIndex--;
                    showExplanation = false;
                  });
                },
                child: const Text('Назад'),
              ),
            ),
          if (currentQuestionIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: selectedAnswer == null
                  ? null
                  : () {
                      if (!showExplanation) {
                        setState(() {
                          showExplanation = true;
                        });
                      } else {
                        if (isLastQuestion) {
                          _completeQuiz();
                        } else {
                          setState(() {
                            currentQuestionIndex++;
                            showExplanation = false;
                          });
                        }
                      }
                    },
              child: Text(
                !showExplanation
                    ? 'Проверить'
                    : isLastQuestion
                        ? 'Завершить'
                        : 'Далее',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(Task task) {
    int correctAnswers = 0;
    int totalScore = 0;

    for (int i = 0; i < task.questions.length; i++) {
      final userAnswer = userAnswers[i];
      final correctAnswer = task.questions[i].correctAnswerIndex;
      if (userAnswer == correctAnswer) {
        correctAnswers++;
        totalScore += 10;
      }
    }

    final percentage = (correctAnswers / task.questions.length) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: percentage >= 70
                      ? [Colors.green, Colors.lightGreen]
                      : percentage >= 50
                          ? [Colors.orange, Colors.deepOrange]
                          : [Colors.red, Colors.redAccent],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    percentage >= 70
                        ? Icons.emoji_events
                        : percentage >= 50
                            ? Icons.thumb_up
                            : Icons.refresh,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    percentage >= 70
                        ? 'Отлично!'
                        : percentage >= 50
                            ? 'Хорошо!'
                            : 'Попробуйте еще раз',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$correctAnswers из ${task.questions.length} правильных',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ваш результат: $totalScore/${task.questions.length * 10}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Подробные результаты',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              task.questions.length,
              (index) => _buildResultCard(task, index, userAnswers[index] ?? 0),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        currentQuestionIndex = 0;
                        userAnswers.clear();
                        isQuizCompleted = false;
                        showExplanation = false;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Пройти заново'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('На главную'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Task task, int questionIndex, int userAnswer) {
    final question = task.questions[questionIndex];
    final isCorrect = userAnswer == question.correctAnswerIndex;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Вопрос ${questionIndex + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  isCorrect ? '+10' : '0',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.question,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (!isCorrect) ...[
              Text(
                'Ваш ответ: ${question.options[userAnswer]}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Правильный ответ: ${question.options[question.correctAnswerIndex]}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              Text(
                'Ваш ответ: ${question.options[userAnswer]}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _completeQuiz() {
    final taskProviderInstance = ref.read(taskProvider);
    final task = taskProviderInstance.getTaskById(widget.taskId);
    if (task == null) return;

    int totalScore = 0;

    for (int i = 0; i < task.questions.length; i++) {
      final userAnswer = userAnswers[i];
      final correctAnswer = task.questions[i].correctAnswerIndex;
      if (userAnswer == correctAnswer) {
        totalScore += 10;
      }
    }

    ref.read(taskProvider.notifier).completeTask(task.id, totalScore);

    setState(() {
      isQuizCompleted = true;
    });
  }
}
