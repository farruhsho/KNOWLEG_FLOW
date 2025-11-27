import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/subjects_repository.dart';

/// Subjects manager page
class SubjectsManagerPage extends ConsumerStatefulWidget {
  const SubjectsManagerPage({super.key});

  @override
  ConsumerState<SubjectsManagerPage> createState() =>
      _SubjectsManagerPageState();
}

class _SubjectsManagerPageState extends ConsumerState<SubjectsManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedSubjects = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление предметами'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showSubjectDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Добавить предмет'),
          ),
          const SizedBox(width: AdminSpacing.md),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: subjectsAsync.when(
              data: (subjects) {
                final filteredSubjects = _filterSubjects(subjects);
                if (filteredSubjects.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildSubjectsList(filteredSubjects);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Ошибка: $error'),
              ),
            ),
          ),
          if (_selectedSubjects.isNotEmpty) _buildBottomBar(),
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
                hintText: 'Поиск по названию...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Show filter dialog
            },
            icon: const Icon(Icons.filter_list),
            label: const Text('Фильтр'),
          ),
          const SizedBox(width: AdminSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Show sort dialog
            },
            icon: const Icon(Icons.sort),
            label: const Text('Сортировка'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList(List<SubjectModel> subjects) {
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
            ...subjects.map(_buildSubjectRow),
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
          Checkbox(
            value: _selectedSubjects.length ==
                ref.watch(subjectsProvider).value?.length,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedSubjects.addAll(
                    ref.watch(subjectsProvider).value?.map((s) => s.id) ?? [],
                  );
                } else {
                  _selectedSubjects.clear();
                }
              });
            },
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              'ПРЕДМЕТ',
              style: AdminTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'УРОКОВ',
              style: AdminTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'ВОПРОСОВ',
              style: AdminTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'СТАТУС',
              style: AdminTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'ДЕЙСТВИЯ',
              style: AdminTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(SubjectModel subject) {
    final isSelected = _selectedSubjects.contains(subject.id);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AdminColors.primary.withOpacity(0.05)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: AdminColors.divider),
        ),
      ),
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedSubjects.add(subject.id);
                } else {
                  _selectedSubjects.remove(subject.id);
                }
              });
            },
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(
                  subject.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.title['ru'] ?? '',
                        style: AdminTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subject.description['ru']?.isNotEmpty == true)
                        Text(
                          subject.description['ru']!,
                          style: AdminTypography.bodySmall.copyWith(
                            color: AdminColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              subject.totalLessons.toString(),
              style: AdminTypography.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              subject.totalQuestions.toString(),
              style: AdminTypography.bodyMedium,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: subject.isActive
                      ? AdminColors.success
                      : AdminColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  subject.isActive ? 'Активен' : 'Неактивен',
                  style: AdminTypography.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showSubjectDialog(subject),
                  tooltip: 'Редактировать',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _deleteSubject(subject.id),
                  tooltip: 'Удалить',
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Дублировать'),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Экспортировать'),
                    ),
                  ],
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
          const Icon(
            Icons.subject,
            size: 64,
            color: AdminColors.textTertiary,
          ),
          const SizedBox(height: AdminSpacing.md),
          Text(
            'Нет предметов',
            style: AdminTypography.h5.copyWith(
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            'Создайте первый предмет',
            style: AdminTypography.bodyMedium.copyWith(
              color: AdminColors.textTertiary,
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _showSubjectDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Добавить предмет'),
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
        border: Border(
          top: BorderSide(color: AdminColors.border),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Выбрано: ${_selectedSubjects.length}',
            style: AdminTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AdminSpacing.lg),
          OutlinedButton.icon(
            onPressed: _bulkDelete,
            icon: const Icon(Icons.delete),
            label: const Text('Удалить'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
            ),
          ),
        ],
      ),
    );
  }

  List<SubjectModel> _filterSubjects(List<SubjectModel> subjects) {
    if (_searchQuery.isEmpty) return subjects;

    return subjects.where((subject) {
      final titleRu = subject.title['ru']?.toLowerCase() ?? '';
      final titleKy = subject.title['ky']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return titleRu.contains(query) || titleKy.contains(query);
    }).toList();
  }

  void _showSubjectDialog(SubjectModel? subject) {
    // TODO: Show subject editor dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subject == null ? 'Новый предмет' : 'Редактировать предмет'),
        content: const Text('Subject editor dialog - TODO'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить предмет?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(subjectsRepositoryProvider).deleteSubject(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Предмет удален')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные предметы?'),
        content: Text('Будет удалено: ${_selectedSubjects.length} предметов'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(subjectsRepositoryProvider)
            .bulkDeleteSubjects(_selectedSubjects.toList());
        setState(() {
          _selectedSubjects.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Предметы удалены')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }
}
