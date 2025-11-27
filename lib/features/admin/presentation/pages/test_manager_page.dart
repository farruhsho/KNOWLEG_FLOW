import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/ort_test_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/widgets/loading_view.dart';

/// Test Manager Page - CRUD operations for tests
class TestManagerPage extends ConsumerStatefulWidget {
  const TestManagerPage({super.key});

  @override
  ConsumerState<TestManagerPage> createState() => _TestManagerPageState();
}

class _TestManagerPageState extends ConsumerState<TestManagerPage> {
  final _dataService = FirebaseDataService();
  List<OrtTestModel> _tests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    try {
      final testsData = await _dataService.getOrtTests();
      if (mounted) {
        setState(() {
          _tests = testsData.map((data) => OrtTestModel.fromFirestore(data)).toList();
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
        title: const Text('Test Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTests,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showTestEditor(context, null);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Test'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загрузка тестов...')
          : _tests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No tests found'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showTestEditor(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Test'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tests.length,
                    itemBuilder: (context, index) {
                      final test = _tests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.assignment, color: Colors.white),
                          ),
                          title: Text(test.title),
                          subtitle: Text(
                            '${test.totalQuestions} questions • ${test.totalMinutes} min',
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
                                _showTestEditor(context, test);
                              } else if (value == 'delete') {
                                _confirmDelete(test);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showTestEditor(BuildContext context, OrtTestModel? test) {
    final titleController = TextEditingController(text: test?.title ?? '');
    final descriptionController = TextEditingController(text: test?.description['ru'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(test == null ? 'Create New Test' : 'Edit Test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Test Title (Russian)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Russian)',
                  border: OutlineInputBorder(),
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
            onPressed: () {
              // TODO: Save test to Firebase
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test saved successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              _loadTests();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(OrtTestModel test) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Test'),
        content: Text('Are you sure you want to delete "${test.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Delete from Firebase
              Navigator.pop(context);
              setState(() {
                _tests.remove(test);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test deleted'),
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
