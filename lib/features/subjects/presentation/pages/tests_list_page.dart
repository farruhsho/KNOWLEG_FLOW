import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/ort_test_model.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';

/// Tests list page with filtering and pagination
class TestsListPage extends StatefulWidget {
  final String? categoryId;
  final String? subjectId;

  const TestsListPage({
    super.key,
    this.categoryId,
    this.subjectId,
  });

  @override
  State<TestsListPage> createState() => _TestsListPageState();
}

class _TestsListPageState extends State<TestsListPage> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedLanguage = 'all';
  String _selectedDifficulty = 'all';
  final int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  List<OrtTestModel> _tests = [];
  bool _isLoading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _tests = [];
        _lastDocument = null;
        _hasMore = true;
      });
    }

    try {
      Query query = _firestore.collection('ort_tests');

      // Apply filters
      if (widget.categoryId != null) {
        query = query.where('category', isEqualTo: widget.categoryId);
      }
      if (widget.subjectId != null) {
        query = query.where('subject', isEqualTo: widget.subjectId);
      }
      if (_selectedLanguage != 'all') {
        query = query.where('language', isEqualTo: _selectedLanguage);
      }
      if (_selectedDifficulty != 'all') {
        query = query.where('difficulty', isEqualTo: _selectedDifficulty);
      }

      // Pagination
      query = query.orderBy('createdAt', descending: true).limit(_pageSize);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            final newTests = snapshot.docs
                .map((doc) => OrtTestModel.fromFirestore(doc))
                .toList();
            _tests.addAll(newTests);
            _hasMore = snapshot.docs.length == _pageSize;
          } else {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки тестов: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: AppColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Тесты',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.05),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фильтры',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Все языки',
                          value: 'all',
                          groupValue: _selectedLanguage,
                          onSelected: (selected) {
                            if (selected) _updateLanguage('all');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Русский',
                          value: 'ru',
                          groupValue: _selectedLanguage,
                          onSelected: (selected) {
                            if (selected) _updateLanguage('ru');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Кыргызча',
                          value: 'ky',
                          groupValue: _selectedLanguage,
                          onSelected: (selected) {
                            if (selected) _updateLanguage('ky');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Все уровни',
                          value: 'all',
                          groupValue: _selectedDifficulty,
                          onSelected: (selected) {
                            if (selected) _updateDifficulty('all');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Легкий',
                          value: 'easy',
                          groupValue: _selectedDifficulty,
                          onSelected: (selected) {
                            if (selected) _updateDifficulty('easy');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Средний',
                          value: 'medium',
                          groupValue: _selectedDifficulty,
                          onSelected: (selected) {
                            if (selected) _updateDifficulty('medium');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Сложный',
                          value: 'hard',
                          groupValue: _selectedDifficulty,
                          onSelected: (selected) {
                            if (selected) _updateDifficulty('hard');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading && _tests.isEmpty)
            const SliverFillRemaining(
              child: LoadingView(message: 'Загрузка тестов...'),
            )
          else if (_tests.isEmpty)
            const SliverFillRemaining(
              child: EmptyView(
                message: 'Тесты не найдены',
                subtitle: 'Попробуйте изменить фильтры',
                icon: Icons.quiz_outlined,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _tests.length) {
                      if (_hasMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () => _loadTests(loadMore: true),
                              child: const Text('Загрузить еще'),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }
                    final test = _tests[index];
                    return _buildTestCard(context, test);
                  },
                  childCount: _tests.length + (_hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required String groupValue,
    required ValueChanged<bool> onSelected,
  }) {
    final isSelected = value == groupValue;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: AppColors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.grey200,
        ),
      ),
    );
  }

  void _updateLanguage(String value) {
    setState(() {
      _selectedLanguage = value;
    });
    _loadTests();
  }

  void _updateDifficulty(String value) {
    setState(() {
      _selectedDifficulty = value;
    });
    _loadTests();
  }

  Widget _buildTestCard(BuildContext context, OrtTestModel test) {

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey200.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            context.push('/mock-test/${test.id}');
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.quiz, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  test.getDescription('ru'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.list_alt, size: 16, color: AppColors.grey600),
                    const SizedBox(width: 4),
                    Text(
                      '${test.totalQuestions} вопросов',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.timer_outlined, size: 16, color: AppColors.grey600),
                    const SizedBox(width: 4),
                    Text(
                      '${test.totalMinutes} мин',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String? difficulty) {
    // OrtTestModel doesn't have difficulty field, use default color
    return AppColors.primary;
  }

  String _getDifficultyText(String? difficulty) {
    // OrtTestModel doesn't have difficulty field, return empty string
    return '';
  }
}

