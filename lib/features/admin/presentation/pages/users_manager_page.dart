import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../../data/models/admin_user_model.dart';
import '../../data/repositories/users_repository.dart';

/// Users manager page
class UsersManagerPage extends ConsumerStatefulWidget {
  const UsersManagerPage({super.key});

  @override
  ConsumerState<UsersManagerPage> createState() => _UsersManagerPageState();
}

class _UsersManagerPageState extends ConsumerState<UsersManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUsers = {};
  
  UsersFilter _filter = const UsersFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersProvider),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          _buildFilterChips(),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                if (users.isEmpty) return _buildEmptyState();
                return _buildUsersList(users);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Ошибка: $error')),
            ),
          ),
          if (_selectedUsers.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск по имени или email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(searchQuery: value.isEmpty ? null : value);
                });
              },
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Все')),
              ButtonSegment(value: 'premium', label: Text('Premium')),
              ButtonSegment(value: 'free', label: Text('Free')),
              ButtonSegment(value: 'banned', label: Text('Banned')),
            ],
            selected: {_getSelectedSegment()},
            onSelectionChanged: (Set<String> selected) {
              setState(() {
                switch (selected.first) {
                  case 'premium':
                    _filter = const UsersFilter(isPremium: true, isBanned: false);
                    break;
                  case 'free':
                    _filter = const UsersFilter(isPremium: false, isBanned: false);
                    break;
                  case 'banned':
                    _filter = const UsersFilter(isBanned: true);
                    break;
                  default:
                    _filter = const UsersFilter();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  String _getSelectedSegment() {
    if (_filter.isBanned == true) return 'banned';
    if (_filter.isPremium == true) return 'premium';
    if (_filter.isPremium == false) return 'free';
    return 'all';
  }

  Widget _buildFilterChips() {
    if (_filter.searchQuery == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: const BoxDecoration(
        color: AdminColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Wrap(
        spacing: AdminSpacing.sm,
        children: [
          const Text('Поиск:'),
          Chip(
            label: Text(_filter.searchQuery!),
            onDeleted: () {
              _searchController.clear();
              setState(() => _filter = _filter.copyWith(searchQuery: null));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<AdminUserModel> users) {
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
            ...users.map(_buildUserRow),
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
          const Expanded(flex: 2, child: Text('ПОЛЬЗОВАТЕЛЬ', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('СТАТУС', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('ТЕСТЫ', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('ТОЧНОСТЬ', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('АКТИВНОСТЬ', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('ДЕЙСТВИЯ', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildUserRow(AdminUserModel user) {
    final isSelected = _selectedUsers.contains(user.id);
    final dateFormat = DateFormat('dd.MM.yy HH:mm');

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
                  _selectedUsers.add(user.id);
                } else {
                  _selectedUsers.remove(user.id);
                }
              });
            },
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? Text(user.name[0].toUpperCase()) : null,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: AdminTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Text(user.email, style: AdminTypography.bodySmall.copyWith(color: AdminColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isBanned
                        ? AdminColors.errorLight
                        : user.isPremium
                            ? AdminColors.warningLight
                            : AdminColors.successLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user.statusLabel,
                    style: AdminTypography.labelSmall.copyWith(
                      color: user.isBanned
                          ? AdminColors.error
                          : user.isPremium
                              ? AdminColors.warning
                              : AdminColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text('${user.completedTests}/${user.totalTests}', style: AdminTypography.bodyMedium),
          ),
          Expanded(
            child: Text(
              '${user.accuracy.toStringAsFixed(0)}%',
              style: AdminTypography.bodyMedium.copyWith(
                color: user.accuracy > 70 ? AdminColors.success : user.accuracy > 40 ? AdminColors.warning : AdminColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              dateFormat.format(user.lastActive),
              style: AdminTypography.bodySmall.copyWith(color: AdminColors.textSecondary),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(user.isPremium ? Icons.star : Icons.star_border, size: 18),
                  onPressed: () => _togglePremium(user),
                  tooltip: user.isPremium ? 'Убрать Premium' : 'Сделать Premium',
                  color: user.isPremium ? AdminColors.warning : null,
                ),
                IconButton(
                  icon: Icon(user.isBanned ? Icons.lock_open : Icons.lock, size: 18),
                  onPressed: () => _toggleBan(user),
                  tooltip: user.isBanned ? 'Разблокировать' : 'Заблокировать',
                  color: user.isBanned ? AdminColors.error : null,
                ),
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  onPressed: () => _viewUser(user),
                  tooltip: 'Просмотр',
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
          const Icon(Icons.people_outline, size: 64, color: AdminColors.textTertiary),
          const SizedBox(height: AdminSpacing.md),
          Text('Нет пользователей', style: AdminTypography.h5.copyWith(color: AdminColors.textSecondary)),
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
          Text('Выбрано: ${_selectedUsers.length}', style: AdminTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: AdminSpacing.lg),
          OutlinedButton.icon(onPressed: _bulkMakePremium, icon: const Icon(Icons.star), label: const Text('Premium')),
          const SizedBox(width: AdminSpacing.sm),
          OutlinedButton.icon(
            onPressed: _bulkBan,
            icon: const Icon(Icons.block),
            label: const Text('Заблокировать'),
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.error),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePremium(AdminUserModel user) async {
    try {
      await ref.read(usersRepositoryProvider).updatePremiumStatus(user.id, !user.isPremium);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(user.isPremium ? 'Premium убран' : 'Premium активирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _toggleBan(AdminUserModel user) async {
    try {
      await ref.read(usersRepositoryProvider).updateBanStatus(user.id, !user.isBanned);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(user.isBanned ? 'Разблокирован' : 'Заблокирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _viewUser(AdminUserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user.email}'),
            Text('Тесты: ${user.completedTests}/${user.totalTests}'),
            Text('Точность: ${user.accuracy.toStringAsFixed(1)}%'),
            Text('Статус: ${user.statusLabel}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _bulkMakePremium() async {
    try {
      await ref.read(usersRepositoryProvider).bulkUpdatePremium(_selectedUsers.toList(), true);
      setState(() => _selectedUsers.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium активирован')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _bulkBan() async {
    try {
      await ref.read(usersRepositoryProvider).bulkBanUsers(_selectedUsers.toList(), true);
      setState(() => _selectedUsers.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователи заблокированы')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}
