import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_view.dart';

/// Lesson Manager Page - Manage daily lessons
class LessonManagerPage extends ConsumerStatefulWidget {
  const LessonManagerPage({super.key});

  @override
  ConsumerState<LessonManagerPage> createState() => _LessonManagerPageState();
}

class _LessonManagerPageState extends ConsumerState<LessonManagerPage> {
  final _firestore = FirebaseFirestore.instance;
  List<LessonData> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('daily_lessons')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _lessons = snapshot.docs.map((doc) {
            final data = doc.data();
            return LessonData(
              id: doc.id,
              title: data['title'] ?? '',
              subject: data['subject'] ?? '',
              content: data['content'] ?? '',
              difficulty: data['difficulty'] ?? 'medium',
              estimatedMinutes: data['estimatedMinutes'] ?? 15,
              isPublished: data['isPublished'] ?? false,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLessons,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showLessonEditor(context, null);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загрузка уроков...')
          : _lessons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No lessons found'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showLessonEditor(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Lesson'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLessons,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = _lessons[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.school, color: AppColors.info),
                          ),
                          title: Text(lesson.title),
                          subtitle: Row(
                            children: [
                              Chip(
                                label: Text(
                                  lesson.subject,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              Text('${lesson.estimatedMinutes} min'),
                              const SizedBox(width: 8),
                              if (lesson.isPublished)
                                const Icon(Icons.check_circle, color: AppColors.success, size: 16)
                              else
                                const Icon(Icons.unpublished, color: Colors.grey, size: 16),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle_publish',
                                child: Row(
                                  children: [
                                    Icon(lesson.isPublished ? Icons.unpublished : Icons.publish),
                                    const SizedBox(width: 8),
                                    Text(lesson.isPublished ? 'Unpublish' : 'Publish'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showLessonEditor(context, lesson);
                              } else if (value == 'toggle_publish') {
                                _togglePublish(lesson);
                              } else if (value == 'delete') {
                                _confirmDelete(lesson);
                              }
                            },
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Content Preview:',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lesson.content.length > 200
                                        ? '${lesson.content.substring(0, 200)}...'
                                        : lesson.content,
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
    );
  }

  void _showLessonEditor(BuildContext context, LessonData? lesson) {
    final titleController = TextEditingController(text: lesson?.title ?? '');
    final contentController = TextEditingController(text: lesson?.content ?? '');
    final minutesController = TextEditingController(text: lesson?.estimatedMinutes.toString() ?? '15');
    String selectedSubject = lesson?.subject ?? 'math';
    String selectedDifficulty = lesson?.difficulty ?? 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(lesson == null ? 'Create Lesson' : 'Edit Lesson'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'math', child: Text('Mathematics')),
                    DropdownMenuItem(value: 'physics', child: Text('Physics')),
                    DropdownMenuItem(value: 'chemistry', child: Text('Chemistry')),
                    DropdownMenuItem(value: 'biology', child: Text('Biology')),
                    DropdownMenuItem(value: 'russian', child: Text('Russian')),
                    DropdownMenuItem(value: 'kyrgyz', child: Text('Kyrgyz')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSubject = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedDifficulty = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Minutes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Content',
                    border: OutlineInputBorder(),
                    hintText: 'Enter lesson content here...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final lessonData = {
                  'title': titleController.text,
                  'subject': selectedSubject,
                  'difficulty': selectedDifficulty,
                  'content': contentController.text,
                  'estimatedMinutes': int.tryParse(minutesController.text) ?? 15,
                  'isPublished': lesson?.isPublished ?? false,
                  'createdAt': lesson == null ? FieldValue.serverTimestamp() : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (lesson == null) {
                  await _firestore.collection('daily_lessons').add(lessonData);
                } else {
                  await _firestore.collection('daily_lessons').doc(lesson.id).update(lessonData);
                }

                Navigator.pop(context);
                _loadLessons();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lesson saved successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePublish(LessonData lesson) async {
    await _firestore.collection('daily_lessons').doc(lesson.id).update({
      'isPublished': !lesson.isPublished,
    });
    _loadLessons();
  }

  void _confirmDelete(LessonData lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Are you sure you want to delete "${lesson.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('daily_lessons').doc(lesson.id).delete();
              Navigator.pop(context);
              _loadLessons();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class LessonData {
  final String id;
  final String title;
  final String subject;
  final String content;
  final String difficulty;
  final int estimatedMinutes;
  final bool isPublished;

  LessonData({
    required this.id,
    required this.title,
    required this.subject,
    required this.content,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.isPublished,
  });
}
