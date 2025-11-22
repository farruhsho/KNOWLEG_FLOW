import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/models/question_model.dart';
import '../../../../shared/models/mock_test_model.dart';

/// Главная панель администратора
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _adminService = AdminService();

  Map<String, dynamic>? _statistics;
  List<SubjectModel> _subjects = [];
  List<QuestionModel> _questions = [];
  List<MockTestModel> _mockTests = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAuth();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAuth() async {
    if (!_adminService.isAdminLoggedIn) {
      if (mounted) {
        context.go(AppRouter.adminLogin);
      }
      return;
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _adminService.getStatistics();
      final subjects = await _adminService.getAllSubjects();
      final questions = await _adminService.getAllQuestions();
      final tests = await _adminService.getAllMockTests();

      if (mounted) {
        setState(() {
          _statistics = stats;
          _subjects = subjects;
          _questions = questions;
          _mockTests = tests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ошибка загрузки данных: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _adminService.logoutAdmin();
      if (mounted) {
        context.go(AppRouter.adminLogin);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Админ Панель'),
            if (_adminService.currentAdminEmail != null)
              Text(
                _adminService.currentAdminEmail!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Обзор'),
            Tab(icon: Icon(Icons.book), text: 'Предметы'),
            Tab(icon: Icon(Icons.question_answer), text: 'Вопросы'),
            Tab(icon: Icon(Icons.quiz), text: 'Тесты'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSubjectsTab(),
                _buildQuestionsTab(),
                _buildMockTestsTab(),
              ],
            ),
    );
  }

  // ==================== ВКЛАДКА ОБЗОРА ====================

  Widget _buildOverviewTab() {
    if (_statistics == null) {
      return const Center(child: Text('Нет данных'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Предметы',
                  _statistics!['totalSubjects'].toString(),
                  Icons.book,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Вопросы',
                  _statistics!['totalQuestions'].toString(),
                  Icons.question_answer,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Тесты',
                  _statistics!['totalMockTests'].toString(),
                  Icons.quiz,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Опубликовано',
                  _statistics!['publishedTests'].toString(),
                  Icons.check_circle,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Быстрые действия',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                'Создать предмет',
                Icons.add,
                () => _showCreateSubjectDialog(),
              ),
              _buildActionButton(
                'Создать вопрос',
                Icons.add_circle,
                () => _showCreateQuestionDialog(),
              ),
              _buildActionButton(
                'Создать тест',
                Icons.add_box,
                () => _showCreateMockTestDialog(),
              ),
              _buildActionButton(
                'Загрузить 100 тестов',
                Icons.upload,
                () => _generate100SampleQuestions(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ==================== ВКЛАДКА ПРЕДМЕТОВ ====================

  Widget _buildSubjectsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showCreateSubjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('Добавить предмет'),
          ),
        ),
        Expanded(
          child: _subjects.isEmpty
              ? const Center(child: Text('Нет предметов'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(subject.color.replaceFirst('#', '0xFF')),
                          ),
                          child: Text(
                            subject.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        title: Text(subject.getTitle('ru')),
                        subtitle: Text(
                          '${subject.totalQuestions} вопросов',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditSubjectDialog(subject),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSubject(subject.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==================== ВКЛАДКА ВОПРОСОВ ====================

  Widget _buildQuestionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateQuestionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить вопрос'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generate100SampleQuestions,
                  icon: const Icon(Icons.upload),
                  label: const Text('100 тестов'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _questions.isEmpty
              ? const Center(child: Text('Нет вопросов'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    final subject = _subjects.firstWhere(
                      (s) => s.id == question.subjectId,
                      orElse: () => SubjectModel(
                        id: '',
                        title: {'ru': 'Неизвестно'},
                        description: {},
                        icon: '❓',
                        color: '#999999',
                      ),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getDifficultyColor(question.difficulty),
                          child: Text(
                            question.difficulty.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          question.getStem('ru'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(subject.getTitle('ru')),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...question.options.map((option) {
                                  final isCorrect = option.id == question.correctAnswer;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCorrect ? Icons.check_circle : Icons.circle_outlined,
                                          color: isCorrect ? Colors.green : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${option.id}: ${option.getText('ru')}',
                                            style: TextStyle(
                                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _deleteQuestion(question.id),
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('Удалить'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ==================== ВКЛАДКА ТЕСТОВ ====================

  Widget _buildMockTestsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showCreateMockTestDialog,
            icon: const Icon(Icons.add),
            label: const Text('Создать тест'),
          ),
        ),
        Expanded(
          child: _mockTests.isEmpty
              ? const Center(child: Text('Нет тестов'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _mockTests.length,
                  itemBuilder: (context, index) {
                    final test = _mockTests[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          test.isPublished ? Icons.check_circle : Icons.circle_outlined,
                          color: test.isPublished ? Colors.green : Colors.grey,
                        ),
                        title: Text(test.getTitle('ru')),
                        subtitle: Text(
                          '${test.totalQuestions} вопросов • ${test.totalTimeMinutes} мин • ${test.priceKGS} сом',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                test.isPublished ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () => _toggleTestPublish(test.id, test.isPublished),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteMockTest(test.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==================== ДИАЛОГИ ====================

  Future<void> _showCreateSubjectDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final iconController = TextEditingController(text: '📚');
    final colorController = TextEditingController(text: '#2563EB');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать предмет'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Иконка (emoji)'),
              ),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Цвет (#RRGGBB)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final subject = SubjectModel(
                id: 'subject_${DateTime.now().millisecondsSinceEpoch}',
                title: {'ru': titleController.text, 'kg': titleController.text},
                description: {'ru': descController.text, 'kg': descController.text},
                icon: iconController.text,
                color: colorController.text,
              );

              try {
                await _adminService.createSubject(subject);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccess('Предмет создан');
                  await _loadData();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showError('Ошибка: $e');
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSubjectDialog(SubjectModel subject) async {
    final titleController = TextEditingController(text: subject.getTitle('ru'));
    final descController = TextEditingController(text: subject.getDescription('ru'));
    final iconController = TextEditingController(text: subject.icon);
    final colorController = TextEditingController(text: subject.color);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать предмет'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Иконка (emoji)'),
              ),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Цвет (#RRGGBB)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = SubjectModel(
                id: subject.id,
                title: {'ru': titleController.text, 'kg': titleController.text},
                description: {'ru': descController.text, 'kg': descController.text},
                icon: iconController.text,
                color: colorController.text,
                moduleIds: subject.moduleIds,
                difficultyTags: subject.difficultyTags,
                totalLessons: subject.totalLessons,
                totalQuestions: subject.totalQuestions,
              );

              try {
                await _adminService.updateSubject(updated);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccess('Предмет обновлен');
                  await _loadData();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showError('Ошибка: $e');
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateQuestionDialog() async {
    if (_subjects.isEmpty) {
      _showError('Сначала создайте предметы');
      return;
    }

    String? selectedSubjectId = _subjects.first.id;
    final questionController = TextEditingController();
    final optionAController = TextEditingController();
    final optionBController = TextEditingController();
    final optionCController = TextEditingController();
    final optionDController = TextEditingController();
    String correctAnswer = 'A';
    int difficulty = 3;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Создать вопрос'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Предмет'),
                  items: _subjects.map((subject) {
                    return DropdownMenuItem(
                      value: subject.id,
                      child: Text(subject.getTitle('ru')),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSubjectId = value;
                    });
                  },
                ),
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(labelText: 'Вопрос'),
                  maxLines: 3,
                ),
                TextField(
                  controller: optionAController,
                  decoration: const InputDecoration(labelText: 'Вариант A'),
                ),
                TextField(
                  controller: optionBController,
                  decoration: const InputDecoration(labelText: 'Вариант B'),
                ),
                TextField(
                  controller: optionCController,
                  decoration: const InputDecoration(labelText: 'Вариант C'),
                ),
                TextField(
                  controller: optionDController,
                  decoration: const InputDecoration(labelText: 'Вариант D'),
                ),
                DropdownButtonFormField<String>(
                  value: correctAnswer,
                  decoration: const InputDecoration(labelText: 'Правильный ответ'),
                  items: ['A', 'B', 'C', 'D'].map((value) {
                    return DropdownMenuItem(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      correctAnswer = value!;
                    });
                  },
                ),
                DropdownButtonFormField<int>(
                  value: difficulty,
                  decoration: const InputDecoration(labelText: 'Сложность'),
                  items: [1, 2, 3, 4, 5].map((value) {
                    return DropdownMenuItem(value: value, child: Text(value.toString()));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      difficulty = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final question = QuestionModel(
                  id: 'question_${DateTime.now().millisecondsSinceEpoch}',
                  subjectId: selectedSubjectId!,
                  type: 'mcq',
                  difficulty: difficulty,
                  stem: {'ru': questionController.text, 'kg': questionController.text},
                  options: [
                    OptionModel(
                      id: 'A',
                      text: {'ru': optionAController.text, 'kg': optionAController.text},
                    ),
                    OptionModel(
                      id: 'B',
                      text: {'ru': optionBController.text, 'kg': optionBController.text},
                    ),
                    OptionModel(
                      id: 'C',
                      text: {'ru': optionCController.text, 'kg': optionCController.text},
                    ),
                    OptionModel(
                      id: 'D',
                      text: {'ru': optionDController.text, 'kg': optionDController.text},
                    ),
                  ],
                  correctAnswer: correctAnswer,
                  explanation: {'ru': '', 'kg': ''},
                  createdBy: _adminService.currentAdminEmail ?? 'admin',
                  createdAt: DateTime.now(),
                );

                try {
                  await _adminService.createQuestion(question);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showSuccess('Вопрос создан');
                    await _loadData();
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showError('Ошибка: $e');
                  }
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateMockTestDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController(text: '100');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать тест'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Цена (KGS)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final test = MockTestModel(
                id: 'test_${DateTime.now().millisecondsSinceEpoch}',
                title: {'ru': titleController.text, 'kg': titleController.text},
                description: {'ru': descController.text, 'kg': descController.text},
                sections: const [],
                priceKGS: int.tryParse(priceController.text) ?? 100,
                createdBy: _adminService.currentAdminEmail ?? 'admin',
                createdAt: DateTime.now(),
              );

              try {
                await _adminService.createMockTest(test);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccess('Тест создан');
                  await _loadData();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showError('Ошибка: $e');
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  // ==================== ДЕЙСТВИЯ ====================

  Future<void> _deleteSubject(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить предмет?'),
        content: const Text('Это также удалит все связанные вопросы.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteSubject(id);
        _showSuccess('Предмет удален');
        await _loadData();
      } catch (e) {
        _showError('Ошибка: $e');
      }
    }
  }

  Future<void> _deleteQuestion(String id) async {
    try {
      await _adminService.deleteQuestion(id);
      _showSuccess('Вопрос удален');
      await _loadData();
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<void> _deleteMockTest(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тест?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteMockTest(id);
        _showSuccess('Тест удален');
        await _loadData();
      } catch (e) {
        _showError('Ошибка: $e');
      }
    }
  }

  Future<void> _toggleTestPublish(String id, bool currentlyPublished) async {
    try {
      if (currentlyPublished) {
        await _adminService.unpublishMockTest(id);
        _showSuccess('Тест снят с публикации');
      } else {
        await _adminService.publishMockTest(id);
        _showSuccess('Тест опубликован');
      }
      await _loadData();
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<void> _generate100SampleQuestions() async {
    context.go(AppRouter.adminGenerateQuestions);
  }
}
