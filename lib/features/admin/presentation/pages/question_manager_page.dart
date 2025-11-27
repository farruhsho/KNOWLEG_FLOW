import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/question_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/widgets/loading_view.dart';

/// Question Manager Page - CRUD operations for questions
class QuestionManagerPage extends ConsumerStatefulWidget {
  const QuestionManagerPage({super.key});

  @override
  ConsumerState<QuestionManagerPage> createState() => _QuestionManagerPageState();
}

class _QuestionManagerPageState extends ConsumerState<QuestionManagerPage> {
  final _dataService = FirebaseDataService();
  List<QuestionModel> _questions = [];
  bool _isLoading = true;
  String _selectedSubject = 'all';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final questions = await _dataService.getQuestions(
        subjectId: _selectedSubject == 'all' ? null : _selectedSubject,
        count: 100,
      );
      if (mounted) {
        setState(() {
          _questions = questions;
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
        title: const Text('Question Manager'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedSubject = value;
              });
              _loadQuestions();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Subjects')),
              const PopupMenuItem(value: 'math', child: Text('Mathematics')),
              const PopupMenuItem(value: 'physics', child: Text('Physics')),
              const PopupMenuItem(value: 'chemistry', child: Text('Chemistry')),
              const PopupMenuItem(value: 'biology', child: Text('Biology')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showQuestionEditor(context, null);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Question'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загрузка вопросов...')
          : _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.quiz, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No questions found'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showQuestionEditor(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Question'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadQuestions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(
                            question.stem['ru'] ?? question.stem.values.first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${question.subjectId} • Difficulty: ${question.difficulty}',
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
                                _showQuestionEditor(context, question);
                              } else if (value == 'delete') {
                                _confirmDelete(question);
                              }
                            },
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...question.options.asMap().entries.map((entry) {
                                    final optIndex = entry.key;
                                    final option = entry.value;
                                    final isCorrect = optIndex.toString() == question.correctAnswer;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                                            color: isCorrect ? AppColors.success : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(option.text['ru'] ?? option.text.values.first),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
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

  void _showQuestionEditor(BuildContext context, QuestionModel? question) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question editor not yet implemented'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _confirmDelete(QuestionModel question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _questions.remove(question);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Question deleted'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
