import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../../../../core/constants/ort_constants.dart';
import '../../data/models/question_model.dart';
import '../../data/repositories/questions_repository.dart';

/// Questions manager page
class QuestionsManagerPage extends ConsumerStatefulWidget {
  const QuestionsManagerPage({super.key});

  @override
  ConsumerState<QuestionsManagerPage> createState() =>
      _QuestionsManagerPageState();
}

class _QuestionsManagerPageState extends ConsumerState<QuestionsManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedQuestions = {};
  String _searchQuery = '';
  String? _selectedSubjectFilter;
  int? _selectedDifficultyFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsProvider(_selectedSubjectFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление вопросами (4,521)'),
        actions: [
          OutlinedButton.icon(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.upload),
            label: const Text('Импорт'),
          ),
          const SizedBox(width: AdminSpacing.sm),
          ElevatedButton.icon(
            onPressed: () => _showQuestionDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Добавить'),
          ),
          const SizedBox(width: AdminSpacing.md),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          _buildFilterChips(),
          Expanded(
            child: questionsAsync.when(
              data: (questions) {
                final filteredQuestions = _filterQuestions(questions);
                if (filteredQuestions.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildQuestionsList(filteredQuestions);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Ошибка: $error'),
              ),
            ),
          ),
          if (_selectedQuestions.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(
          bottom: BorderSide(color: AdminColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск по тексту вопроса...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          PopupMenuButton<String>(
            icon: Row(
              children: const [
                Icon(Icons.filter_list),
                SizedBox(width: 4),
                Text('Фильтр'),
              ],
            ),
            onSelected: (value) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'subject', child: Text('По предмету')),
              const PopupMenuItem(value: 'difficulty', child: Text('По сложности')),
              const PopupMenuItem(value: 'type', child: Text('По типу')),
              const PopupMenuItem(value: 'tags', child: Text('По тегам')),
            ],
          ),
          const SizedBox(width: AdminSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedSubjectFilter = null;
                _selectedDifficultyFilter = null;
                _searchQuery = '';
                _searchController.clear();
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Сброс'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasFilters = _selectedSubjectFilter != null ||
        _selectedDifficultyFilter != null;

    if (!hasFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: const BoxDecoration(
        color: AdminColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Wrap(
        spacing: AdminSpacing.sm,
        children: [
          const Text('Активные фильтры:'),
          if (_selectedSubjectFilter != null)
            Chip(
              label: Text('Предмет: $_selectedSubjectFilter'),
              onDeleted: () => setState(() => _selectedSubjectFilter = null),
            ),
          if (_selectedDifficultyFilter != null)
            Chip(
              label: Text(
                'Сложность: ${OrtConstants.getDifficultyName(_selectedDifficultyFilter!)}',
              ),
              onDeleted: () => setState(() => _selectedDifficultyFilter = null),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(List<QuestionModel> questions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          children: [
            _buildTableHeader(),
            const Divider(height: 1),
            ...questions.map(_buildQuestionRow),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Row(
        children: [
          Checkbox(value: false, onChanged: (v) {}),
          const SizedBox(width: AdminSpacing.sm),
          const Expanded(child: Text('ID', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(flex: 3, child: Text('ВОПРОС', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('ТЕМА', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('⭐', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('% ОТВ', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildQuestionRow(QuestionModel question) {
    final isSelected = _selectedQuestions.contains(question.id);
    final correctPct = question.stats.correctPercentage;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AdminColors.primary.withOpacity(0.05) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: AdminColors.divider)),
      ),
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedQuestions.add(question.id);
                } else {
                  _selectedQuestions.remove(question.id);
                }
              });
            },
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              'Q-${question.id.substring(0, 6)}',
              style: AdminTypography.mono.copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.stem['ru'] ?? '',
                  style: AdminTypography.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: question.options.take(5).map((opt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: opt.isCorrect ? AdminColors.successLight : AdminColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: opt.isCorrect ? AdminColors.success : AdminColors.border,
                        ),
                      ),
                      child: Text(opt.id, style: AdminTypography.labelSmall),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              children: question.tags.take(2).map((tag) {
                return Chip(
                  label: Text(tag),
                  labelStyle: AdminTypography.labelSmall,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(
                3,
                (i) => Icon(
                  Icons.star,
                  size: 14,
                  color: i < question.difficulty ? AdminColors.warning : AdminColors.textTertiary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  '${correctPct.toStringAsFixed(0)}%',
                  style: AdminTypography.bodyMedium.copyWith(
                    color: correctPct > 70 ? AdminColors.success : correctPct > 40 ? AdminColors.warning : AdminColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  correctPct > 70 ? Icons.arrow_upward : correctPct > 40 ? Icons.remove : Icons.arrow_downward,
                  size: 12,
                  color: correctPct > 70 ? AdminColors.success : correctPct > 40 ? AdminColors.warning : AdminColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.quiz, size: 64, color: AdminColors.textTertiary),
          const SizedBox(height: AdminSpacing.md),
          Text('Нет вопросов', style: AdminTypography.h5.copyWith(color: AdminColors.textSecondary)),
          const SizedBox(height: AdminSpacing.sm),
          Text('Создайте первый вопрос или импортируйте', style: AdminTypography.bodyMedium.copyWith(color: AdminColors.textTertiary)),
          const SizedBox(height: AdminSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(onPressed: _showImportDialog, icon: const Icon(Icons.upload), label: const Text('Импорт')),
              const SizedBox(width: AdminSpacing.sm),
              ElevatedButton.icon(onPressed: () => _showQuestionDialog(null), icon: const Icon(Icons.add), label: const Text('Добавить')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Text('Выбрано: ${_selectedQuestions.length}', style: AdminTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: AdminSpacing.lg),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.star), label: const Text('Сложность')),
          const SizedBox(width: AdminSpacing.sm),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.label), label: const Text('Теги')),
          const SizedBox(width: AdminSpacing.sm),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('Экспорт')),
          const SizedBox(width: AdminSpacing.sm),
          OutlinedButton.icon(
            onPressed: _bulkDelete,
            icon: const Icon(Icons.delete),
            label: const Text('Удалить'),
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.error),
          ),
        ],
      ),
    );
  }

  List<QuestionModel> _filterQuestions(List<QuestionModel> questions) {
    var filtered = questions;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((q) {
        final stem = q.stem['ru']?.toLowerCase() ?? '';
        return stem.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    if (_selectedDifficultyFilter != null) {
      filtered = filtered.where((q) => q.difficulty == _selectedDifficultyFilter).toList();
    }
    return filtered;
  }

  void _showQuestionDialog(QuestionModel? question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question == null ? 'Новый вопрос' : 'Редактировать'),
        content: const Text('Question editor - TODO'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Сохранить')),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Импорт вопросов'),
        content: const Text('Import dialog - TODO'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Импорт')),
        ],
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Будет удалено: ${_selectedQuestions.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(questionsRepositoryProvider).bulkDeleteQuestions(_selectedQuestions.toList());
        setState(() => _selectedQuestions.clear());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Удалено')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      }
    }
  }
}
