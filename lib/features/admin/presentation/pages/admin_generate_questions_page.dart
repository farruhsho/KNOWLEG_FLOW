import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/models/question_model.dart';

/// Страница генерации 100 тестовых вопросов
class AdminGenerateQuestionsPage extends StatefulWidget {
  const AdminGenerateQuestionsPage({super.key});

  @override
  State<AdminGenerateQuestionsPage> createState() => _AdminGenerateQuestionsPageState();
}

class _AdminGenerateQuestionsPageState extends State<AdminGenerateQuestionsPage> {
  final _adminService = AdminService();

  bool _isGenerating = false;
  int _progress = 0;
  String _statusMessage = 'Готов к генерации 100 тестовых вопросов';

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
  }

  Future<void> _checkAdminAuth() async {
    if (!_adminService.isAdminLoggedIn) {
      if (mounted) {
        context.go(AppRouter.adminLogin);
      }
    }
  }

  Future<void> _generateQuestions() async {
    setState(() {
      _isGenerating = true;
      _progress = 0;
      _statusMessage = 'Создание предметов...';
    });

    try {
      // Создать предметы если их нет
      final subjects = await _createSubjects();

      setState(() {
        _progress = 10;
        _statusMessage = 'Создано ${subjects.length} предметов. Генерация вопросов...';
      });

      // Генерация вопросов
      final questions = _generateSampleQuestions(subjects);

      // Сохранить вопросы батчами
      const batchSize = 20;
      for (var i = 0; i < questions.length; i += batchSize) {
        final batch = questions.sublist(
          i,
          i + batchSize > questions.length ? questions.length : i + batchSize,
        );

        await _adminService.createQuestionsBatch(batch);

        setState(() {
          _progress = 10 + ((i + batchSize) * 90 ~/ questions.length);
          _statusMessage = 'Сохранено ${i + batch.length} из ${questions.length} вопросов...';
        });

        // Небольшая задержка для UI
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _progress = 100;
        _statusMessage = 'Успешно создано 100 вопросов!';
      });

      // Показать диалог успеха
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Успех!'),
            content: Text('Создано 100 вопросов по ${subjects.length} предметам'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(AppRouter.adminDashboard);
                },
                child: const Text('Вернуться в панель'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _statusMessage = 'Ошибка: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка генерации: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<List<SubjectModel>> _createSubjects() async {
    final subjectsData = [
      {
        'id': 'math',
        'title': 'Математика',
        'icon': '🔢',
        'color': '#2563EB',
        'description': 'Математический раздел ОРТ',
      },
      {
        'id': 'kyrgyz',
        'title': 'Кыргызский язык',
        'icon': '📝',
        'color': '#10B981',
        'description': 'Кыргызский язык и литература',
      },
      {
        'id': 'russian',
        'title': 'Русский язык',
        'icon': '📚',
        'color': '#F59E0B',
        'description': 'Русский язык и литература',
      },
      {
        'id': 'english',
        'title': 'Английский язык',
        'icon': '🌍',
        'color': '#8B5CF6',
        'description': 'Английский язык',
      },
      {
        'id': 'history',
        'title': 'История Кыргызстана',
        'icon': '🏛️',
        'color': '#EF4444',
        'description': 'История и культура Кыргызстана',
      },
    ];

    final subjects = <SubjectModel>[];

    for (final data in subjectsData) {
      try {
        final subject = SubjectModel(
          id: data['id'] as String,
          title: {
            'ru': data['title'] as String,
            'kg': data['title'] as String,
          },
          description: {
            'ru': data['description'] as String,
            'kg': data['description'] as String,
          },
          icon: data['icon'] as String,
          color: data['color'] as String,
        );

        final created = await _adminService.createSubject(subject);
        subjects.add(created);
      } catch (e) {
        // Предмет уже существует, получаем его
        final existing = await _adminService.getSubject(data['id'] as String);
        if (existing != null) {
          subjects.add(existing);
        }
      }
    }

    return subjects;
  }

  List<QuestionModel> _generateSampleQuestions(List<SubjectModel> subjects) {
    final questions = <QuestionModel>[];
    final now = DateTime.now();

    // 20 вопросов на предмет
    for (final subject in subjects) {
      questions.addAll(_generateQuestionsForSubject(subject, 20, now));
    }

    return questions;
  }

  List<QuestionModel> _generateQuestionsForSubject(
    SubjectModel subject,
    int count,
    DateTime createdAt,
  ) {
    final questions = <QuestionModel>[];

    for (var i = 0; i < count; i++) {
      final difficulty = (i % 5) + 1; // Rotate difficulties 1-5

      final question = QuestionModel(
        id: '${subject.id}_q${i + 1}_${createdAt.millisecondsSinceEpoch}',
        subjectId: subject.id,
        type: 'mcq',
        difficulty: difficulty,
        stem: _generateQuestionStem(subject.id, i + 1),
        options: _generateOptions(subject.id, i + 1),
        correctAnswer: _getCorrectAnswer(i),
        explanation: {
          'ru': 'Правильный ответ: ${_getCorrectAnswer(i)}',
          'kg': 'Туура жооп: ${_getCorrectAnswer(i)}',
        },
        tags: [subject.id, 'sample', 'difficulty_$difficulty'],
        createdBy: _adminService.currentAdminEmail ?? 'admin',
        createdAt: createdAt,
      );

      questions.add(question);
    }

    return questions;
  }

  Map<String, String> _generateQuestionStem(String subjectId, int number) {
    final questions = _getQuestionTemplates(subjectId);
    final template = questions[number % questions.length];

    return {
      'ru': '$template (№$number)',
      'kg': '$template (№$number)',
    };
  }

  List<String> _getQuestionTemplates(String subjectId) {
    switch (subjectId) {
      case 'math':
        return [
          'Решите уравнение: 2x + 5 = 15',
          'Найдите площадь прямоугольника со сторонами 5 см и 8 см',
          'Чему равен корень квадратный из 144?',
          'Сколько процентов составляет число 25 от числа 100?',
          'Найдите значение выражения: (3 + 7) × 4',
          'Решите неравенство: 3x - 6 > 9',
          'Найдите периметр квадрата со стороной 7 см',
          'Вычислите: 15% от 200',
          'Решите систему уравнений: x + y = 10, x - y = 2',
          'Найдите объем куба с ребром 4 см',
        ];

      case 'kyrgyz':
        return [
          'Выберите правильное написание слова',
          'Определите падеж существительного в предложении',
          'Какое из слов является синонимом к слову "жакшы"?',
          'Укажите правильную форму глагола',
          'Найдите ошибку в предложении',
          'Определите тип предложения',
          'Какое слово является антонимом к "чоң"?',
          'Выберите правильный вариант согласования',
          'Определите часть речи подчеркнутого слова',
          'Укажите правильный порядок слов в предложении',
        ];

      case 'russian':
        return [
          'Выберите правильное написание слова',
          'Укажите слово с ошибкой в ударении',
          'Определите тип односоставного предложения',
          'Какое слово является синонимом к слову "красивый"?',
          'Найдите слово с приставкой ПРЕ-',
          'Укажите правильную форму множественного числа',
          'Определите способ образования слова',
          'Какое из слов пишется через дефис?',
          'Найдите предложение с обособленным определением',
          'Укажите правильный вариант пунктуации',
        ];

      case 'english':
        return [
          'Choose the correct form of the verb',
          'Select the right preposition',
          'What is the plural form of "child"?',
          'Choose the correct article',
          'Which sentence is grammatically correct?',
          'Select the synonym for "happy"',
          'What is the past tense of "go"?',
          'Choose the correct pronoun',
          'Which word is an adjective?',
          'Select the correct word order',
        ];

      case 'history':
        return [
          'В каком году был основан Киргизский каганат?',
          'Кто был первым президентом Кыргызской Республики?',
          'Когда Кыргызстан получил независимость?',
          'Какой древний город был центром Шелкового пути?',
          'В каком году произошла Великая Октябрьская революция?',
          'Кто написал эпос "Манас"?',
          'Какое событие произошло в 1916 году в Кыргызстане?',
          'Когда была принята Конституция Кыргызской Республики?',
          'Кто был известным кыргызским ханом в XVIII веке?',
          'В каком году Кыргызстан вступил в ООН?',
        ];

      default:
        return ['Вопрос $number по предмету $subjectId'];
    }
  }

  List<OptionModel> _generateOptions(String subjectId, int number) {
    final options = _getOptionTemplates(subjectId, number);

    return [
      OptionModel(
        id: 'A',
        text: {'ru': options[0], 'kg': options[0]},
      ),
      OptionModel(
        id: 'B',
        text: {'ru': options[1], 'kg': options[1]},
      ),
      OptionModel(
        id: 'C',
        text: {'ru': options[2], 'kg': options[2]},
      ),
      OptionModel(
        id: 'D',
        text: {'ru': options[3], 'kg': options[3]},
      ),
    ];
  }

  List<String> _getOptionTemplates(String subjectId, int number) {
    switch (subjectId) {
      case 'math':
        return ['5', '10', '15', '20'];
      case 'kyrgyz':
      case 'russian':
        return ['Вариант А', 'Вариант Б', 'Вариант В', 'Вариант Г'];
      case 'english':
        return ['Option A', 'Option B', 'Option C', 'Option D'];
      case 'history':
        return ['1991', '1992', '1993', '1994'];
      default:
        return ['A', 'B', 'C', 'D'];
    }
  }

  String _getCorrectAnswer(int index) {
    // Rotate correct answers: A, B, C, D, A, B, C, D...
    const answers = ['A', 'B', 'C', 'D'];
    return answers[index % 4];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Генерация тестовых вопросов'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isGenerating
              ? null
              : () => context.go(AppRouter.adminDashboard),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz,
              size: 100,
              color: _isGenerating ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              'Генерация 100 тестовых вопросов',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Будет создано:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('• 5 предметов (Математика, Кыргызский, Русский, Английский, История)'),
            const Text('• 20 вопросов на каждый предмет'),
            const Text('• Вопросы с разными уровнями сложности (1-5)'),
            const Text('• 4 варианта ответа на каждый вопрос'),
            const SizedBox(height: 32),
            if (_isGenerating) ...[
              LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 10,
              ),
              const SizedBox(height: 16),
              Text(
                '$_progress%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _progress == 100 ? Colors.green : Colors.grey[600],
                  fontWeight: _progress == 100 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateQuestions,
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text(
                  'Начать генерацию',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
