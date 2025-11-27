import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../admin/services/admin_service.dart';

/// Lessons manager page for admin
class LessonsManagerPage extends StatefulWidget {
  const LessonsManagerPage({super.key});

  @override
  State<LessonsManagerPage> createState() => _LessonsManagerPageState();
}

class _LessonsManagerPageState extends State<LessonsManagerPage> {
  final _adminService = AdminService();
  List<LessonModel> _lessons = [];
  List<SubjectModel> _subjects = [];
  String? _selectedSubjectId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subjects = await _adminService.getAllSubjects();
      if (subjects.isNotEmpty && _selectedSubjectId == null) {
        _selectedSubjectId = subjects.first.id;
      }

      List<LessonModel> lessons = [];
      if (_selectedSubjectId != null) {
        lessons = await _adminService.getLessonsBySubject(_selectedSubjectId!);
      }

      if (mounted) {
        setState(() {
          _subjects = subjects;
          _lessons = lessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление уроками'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_subjects.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.grey100,
              child: DropdownButtonFormField<String>(initialValue: _selectedSubjectId,
                decoration: const InputDecoration(
                  labelText: 'Предмет',
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _subjects.map((subject) {
                  return DropdownMenuItem(
                    value: subject.id,
                    child: Text('${subject.icon} ${subject.getTitle('ru')}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSubjectId = value;
                  });
                  _loadData();
                },
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _selectedSubjectId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showLessonDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить урок'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Загрузка уроков...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadData);
    }

    if (_lessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 64, color: AppColors.grey400),
            const SizedBox(height: 16),
            const Text('Нет уроков', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Добавьте первый урок',
              style: TextStyle(color: AppColors.grey600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text('${lesson.order}'),
            ),
            title: Text(
              lesson.getTitle('ru'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${lesson.estimatedTimeMinutes} мин • ${lesson.tags.join(', ')}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.info),
                  onPressed: () => _showLessonDialog(lesson: lesson),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _confirmDelete(lesson),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLessonDialog({LessonModel? lesson}) {
    final isEdit = lesson != null;
    final titleController = TextEditingController(
      text: isEdit ? lesson.getTitle('ru') : '',
    );
    final contentController = TextEditingController(
      text: isEdit ? lesson.getContent('ru') : '',
    );
    final timeController = TextEditingController(
      text: isEdit ? lesson.estimatedTimeMinutes.toString() : '15',
    );
    final orderController = TextEditingController(
      text: isEdit ? lesson.order.toString() : '${_lessons.length + 1}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Редактировать урок' : 'Новый урок'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Содержание'),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Время (мин)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: orderController,
                decoration: const InputDecoration(labelText: 'Порядок'),
                keyboardType: TextInputType.number,
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
              final newLesson = LessonModel(
                id: isEdit ? lesson.id : '',
                subjectId: _selectedSubjectId!,
                title: {'ru': titleController.text, 'ky': titleController.text, 'en': titleController.text},
                content: {'ru': contentController.text, 'ky': contentController.text, 'en': contentController.text},
                estimatedTimeMinutes: int.tryParse(timeController.text) ?? 15,
                order: int.tryParse(orderController.text) ?? 1,
                tags: [],
                mediaUrls: [],
                createdBy: 'admin',
                createdAt: isEdit ? lesson.createdAt : DateTime.now(),
              );

              try {
                if (isEdit) {
                  await _adminService.updateLesson(lesson.id, newLesson);
                } else {
                  await _adminService.createLesson(newLesson);
                }
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Урок обновлен' : 'Урок создан'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить урок?'),
        content: Text('Вы уверены, что хотите удалить "${lesson.getTitle('ru')}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _adminService.deleteLesson(lesson.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Урок удален'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
