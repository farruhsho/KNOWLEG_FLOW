import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/models/ort_test_model.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_indicator.dart';

class TestsListPage extends StatefulWidget {
  const TestsListPage({super.key});

  @override
  State<TestsListPage> createState() => _TestsListPageState();
}

class _TestsListPageState extends State<TestsListPage> {
  List<OrtTestModel> _tests = [];
  List<OrtTestModel> _filteredTests = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String? _selectedCategory;
  String? _selectedLanguage;
  int? _selectedDifficulty;
  bool _showPremiumOnly = false;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final tests = _getSampleTests();

      setState(() {
        _tests = tests;
        _filteredTests = tests;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<OrtTestModel> _getSampleTests() {
    final now = DateTime.now();
    return [
      OrtTestModel(
        id: 'ort_math_1',
        title: {'ru': 'ОРТ Математика - Тест 1', 'ky': 'ОРТ Математика - Тест 1'},
        description: {'ru': 'Полный тест по математике с задачами разного уровня сложности', 'ky': 'Математика боюнча толук тест'},
        category: 'math',
        language: 'ru',
        difficulty: 3,
        questionCount: 30,
        durationMinutes: 90,
        questionIds: [],
        isPremium: false,
        createdAt: now,
        createdBy: 'admin',
      ),
      OrtTestModel(
        id: 'ort_russian_1',
        title: {'ru': 'ОРТ Русский язык - Тест 1', 'ky': 'ОРТ Орус тили - Тест 1'},
        description: {'ru': 'Тест на знание русского языка: грамматика, лексика, синтаксис', 'ky': 'Орус тили боюнча тест'},
        category: 'russian',
        language: 'ru',
        difficulty: 2,
        questionCount: 30,
        durationMinutes: 90,
        questionIds: [],
        isPremium: false,
        createdAt: now,
        createdBy: 'admin',
      ),
      OrtTestModel(
        id: 'ort_kyrgyz_1',
        title: {'ru': 'ОРТ Кыргызский язык - Тест 1', 'ky': 'ОРТ Кыргыз тили - Тест 1'},
        description: {'ru': 'Тест по кыргызскому языку', 'ky': 'Кыргыз тили боюнча тест'},
        category: 'kyrgyz',
        language: 'ky',
        difficulty: 2,
        questionCount: 30,
        durationMinutes: 90,
        questionIds: [],
        isPremium: true,
        createdAt: now,
        createdBy: 'admin',
      ),
      OrtTestModel(
        id: 'ort_english_1',
        title: {'ru': 'ОРТ Английский - Тест 1', 'en': 'ORT English - Test 1'},
        description: {'ru': 'Тест по английскому языку: грамматика, чтение, лексика', 'en': 'English language test'},
        category: 'english',
        language: 'en',
        difficulty: 4,
        questionCount: 30,
        durationMinutes: 90,
        questionIds: [],
        isPremium: true,
        createdAt: now,
        createdBy: 'admin',
      ),
      OrtTestModel(
        id: 'ort_history_1',
        title: {'ru': 'ОРТ История Кыргызстана - Тест 1', 'ky': 'ОРТ Кыргызстандын тарыхы - Тест 1'},
        description: {'ru': 'Тест по истории Кыргызстана от древности до наших дней', 'ky': 'Кыргызстандын тарыхы боюнча тест'},
        category: 'history',
        language: 'ru',
        difficulty: 3,
        questionCount: 30,
        durationMinutes: 90,
        questionIds: [],
        isPremium: false,
        createdAt: now,
        createdBy: 'admin',
      ),
      OrtTestModel(
        id: 'ort_math_2',
        title: {'ru': 'ОРТ Математика - Тест 2 (Продвинутый)', 'ky': 'ОРТ Математика - Тест 2'},
        description: {'ru': 'Усложненный тест для продвинутых учеников', 'ky': 'Кыйынчылыктуу тест'},
        category: 'math',
        language: 'ru',
        difficulty: 5,
        questionCount: 30,
        durationMinutes: 90,
        questionIds: [],
        isPremium: true,
        createdAt: now,
        createdBy: 'admin',
      ),
    ];
  }

  void _applyFilters() {
    setState(() {
      _filteredTests = _tests.where((test) {
        if (_selectedCategory != null && test.category != _selectedCategory) {
          return false;
        }
        if (_selectedLanguage != null && test.language != _selectedLanguage) {
          return false;
        }
        if (_selectedDifficulty != null && test.difficulty != _selectedDifficulty) {
          return false;
        }
        if (_showPremiumOnly && !test.isPremium) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedLanguage = null;
      _selectedDifficulty = null;
      _showPremiumOnly = false;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Тесты ОРТ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_off),
            onPressed: _clearFilters,
            tooltip: 'Очистить фильтры',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildTestsList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Фильтры',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D1F),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCategoryDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildLanguageDropdown()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDifficultyDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildPremiumToggle()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        decoration: const InputDecoration(
          labelText: 'Категория',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: Colors.white,
        items: const [
          DropdownMenuItem(value: null, child: Text('Все категории')),
          DropdownMenuItem(value: 'math', child: Text('📐 Математика')),
          DropdownMenuItem(value: 'russian', child: Text('📚 Русский язык')),
          DropdownMenuItem(value: 'kyrgyz', child: Text('📝 Кыргызский язык')),
          DropdownMenuItem(value: 'english', child: Text('🌍 Английский')),
          DropdownMenuItem(value: 'history', child: Text('🏛️ История')),
        ],
        onChanged: (value) {
          setState(() => _selectedCategory = value);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedLanguage,
        decoration: const InputDecoration(
          labelText: 'Язык',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: Colors.white,
        items: const [
          DropdownMenuItem(value: null, child: Text('Все языки')),
          DropdownMenuItem(value: 'ru', child: Text('🇷🇺 Русский')),
          DropdownMenuItem(value: 'ky', child: Text('🇰🇬 Кыргызча')),
          DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
        ],
        onChanged: (value) {
          setState(() => _selectedLanguage = value);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildDifficultyDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedDifficulty,
        decoration: const InputDecoration(
          labelText: 'Сложность',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: Colors.white,
        items: [
          const DropdownMenuItem(value: null, child: Text('Все уровни')),
          ...List.generate(5, (index) {
            final level = index + 1;
            return DropdownMenuItem(
              value: level,
              child: Text(_getDifficultyText(level)),
            );
          }),
        ],
        onChanged: (value) {
          setState(() => _selectedDifficulty = value);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildPremiumToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: CheckboxListTile(
        title: const Text('Premium', style: TextStyle(fontSize: 14)),
        value: _showPremiumOnly,
        onChanged: (value) {
          setState(() => _showPremiumOnly = value ?? false);
          _applyFilters();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        activeColor: AppColors.warning,
      ),
    );
  }

  Widget _buildTestsList() {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadTests);
    }

    if (_filteredTests.isEmpty) {
      return const EmptyView(
        message: 'Тесты не найдены',
        subtitle: 'Попробуйте изменить фильтры',
        icon: Icons.quiz_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTests.length,
        itemBuilder: (context, index) {
          final test = _filteredTests[index];
          return _buildTestCard(test);
        },
      ),
    );
  }

  Widget _buildTestCard(OrtTestModel test) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getCategoryColor(test.category),
            _getCategoryColor(test.category).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getCategoryColor(test.category).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startTest(test),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getCategoryEmoji(test.category),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test.getTitle('ru'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCategoryName(test.category),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (test.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stars, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  test.getDescription('ru'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.quiz_outlined,
                      '${test.questionCount} вопросов',
                    ),
                    _buildInfoChip(
                      Icons.access_time_outlined,
                      '${test.durationMinutes} мин',
                    ),
                    _buildInfoChip(
                      Icons.signal_cellular_alt,
                      test.getDifficultyText(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'math':
        return const Color(0xFF8B5CF6); // Purple
      case 'russian':
        return const Color(0xFF3B82F6); // Blue
      case 'kyrgyz':
        return const Color(0xFF10B981); // Green
      case 'english':
        return const Color(0xFFEC4899); // Pink
      case 'history':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'math':
        return '📐';
      case 'russian':
        return '📚';
      case 'kyrgyz':
        return '📝';
      case 'english':
        return '🌍';
      case 'history':
        return '🏛️';
      default:
        return '📖';
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'math':
        return 'Математика';
      case 'russian':
        return 'Русский язык';
      case 'kyrgyz':
        return 'Кыргызский язык';
      case 'english':
        return 'Английский язык';
      case 'history':
        return 'История Кыргызстана';
      default:
        return category;
    }
  }

  String _getDifficultyText(int difficulty) {
    switch (difficulty) {
      case 1:
        return '⭐ Очень легкий';
      case 2:
        return '⭐⭐ Легкий';
      case 3:
        return '⭐⭐⭐ Средний';
      case 4:
        return '⭐⭐⭐⭐ Сложный';
      case 5:
        return '⭐⭐⭐⭐⭐ Очень сложный';
      default:
        return 'Уровень $difficulty';
    }
  }

  void _startTest(OrtTestModel test) {
    if (test.isPremium) {
      _showPremiumDialog(test);
    } else {
      context.push('${AppRouter.quiz}/${test.id}');
    }
  }

  void _showPremiumDialog(OrtTestModel test) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.stars, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Premium тест'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Тест "${test.getTitle('ru')}" доступен только для Premium пользователей.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              '✨ Получите доступ ко всем тестам\n📊 Подробная аналитика\n🎯 Персональные рекомендации',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRouter.payments);
            },
            icon: const Icon(Icons.stars),
            label: const Text('Оформить Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
