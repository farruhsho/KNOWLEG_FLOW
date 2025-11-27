import 'package:flutter/material.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';

/// Sidebar navigation item model
class SidebarItem {
  final String id;
  final String title;
  final IconData icon;
  final String? route;
  final List<SidebarItem>? children;
  final int? badgeCount;

  const SidebarItem({
    required this.id,
    required this.title,
    required this.icon,
    this.route,
    this.children,
    this.badgeCount,
  });
}

/// Admin sidebar navigation widget
class AdminSidebar extends StatefulWidget {
  final bool isCollapsed;
  final String currentRoute;
  final Function(String) onNavigate;
  final VoidCallback onToggle;

  const AdminSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentRoute,
    required this.onNavigate,
    required this.onToggle,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  final Map<String, bool> _expandedItems = {};

  // Sidebar menu items
  static const List<SidebarItem> menuItems = [
    SidebarItem(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard,
      route: '/admin/dashboard',
    ),
    SidebarItem(
      id: 'content',
      title: 'Контент',
      icon: Icons.library_books,
      children: [
        SidebarItem(
          id: 'subjects',
          title: 'Предметы',
          icon: Icons.subject,
          route: '/admin/subjects',
        ),
        SidebarItem(
          id: 'lessons',
          title: 'Уроки',
          icon: Icons.menu_book,
          route: '/admin/lessons',
        ),
        SidebarItem(
          id: 'questions',
          title: 'Вопросы',
          icon: Icons.quiz,
          route: '/admin/questions',
        ),
        SidebarItem(
          id: 'tests',
          title: 'Тесты',
          icon: Icons.assignment,
          route: '/admin/tests',
        ),
      ],
    ),
    SidebarItem(
      id: 'ai',
      title: 'AI',
      icon: Icons.psychology,
      children: [
        SidebarItem(
          id: 'generator',
          title: 'Генератор',
          icon: Icons.auto_awesome,
          route: '/admin/ai/generator',
        ),
        SidebarItem(
          id: 'analysis',
          title: 'Анализ',
          icon: Icons.analytics,
          route: '/admin/ai/analysis',
        ),
      ],
    ),
    SidebarItem(
      id: 'users',
      title: 'Пользователи',
      icon: Icons.people,
      children: [
        SidebarItem(
          id: 'all-users',
          title: 'Все',
          icon: Icons.person,
          route: '/admin/users',
        ),
        SidebarItem(
          id: 'premium',
          title: 'Premium',
          icon: Icons.star,
          route: '/admin/users/premium',
        ),
        SidebarItem(
          id: 'banned',
          title: 'Бан',
          icon: Icons.block,
          route: '/admin/users/banned',
        ),
      ],
    ),
    SidebarItem(
      id: 'statistics',
      title: 'Статистика',
      icon: Icons.bar_chart,
      children: [
        SidebarItem(
          id: 'overview',
          title: 'Обзор',
          icon: Icons.insights,
          route: '/admin/statistics',
        ),
        SidebarItem(
          id: 'export',
          title: 'Экспорт',
          icon: Icons.download,
          route: '/admin/statistics/export',
        ),
      ],
    ),
    SidebarItem(
      id: 'settings',
      title: 'Настройки',
      icon: Icons.settings,
      children: [
        SidebarItem(
          id: 'general',
          title: 'Общие',
          icon: Icons.tune,
          route: '/admin/settings',
        ),
        SidebarItem(
          id: 'roles',
          title: 'Роли',
          icon: Icons.admin_panel_settings,
          route: '/admin/settings/roles',
        ),
        SidebarItem(
          id: 'backup',
          title: 'Backup',
          icon: Icons.backup,
          route: '/admin/settings/backup',
        ),
      ],
    ),
    SidebarItem(
      id: 'logs',
      title: 'Логи',
      icon: Icons.history,
      route: '/admin/logs',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.isCollapsed ? 60 : 240,
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(
          right: BorderSide(color: AdminColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
              children: menuItems.map(_buildMenuItem).toList(),
            ),
          ),
          const Divider(height: 1),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AdminColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school,
              size: 20,
              color: AdminColors.textOnPrimary,
            ),
          ),
          if (!widget.isCollapsed) ...[
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: Text(
                'ORT Master',
                style: AdminTypography.h6.copyWith(
                  color: AdminColors.primary,
                ),
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              widget.isCollapsed ? Icons.menu : Icons.menu_open,
              size: 20,
            ),
            onPressed: widget.onToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(SidebarItem item) {
    final hasChildren = item.children != null && item.children!.isNotEmpty;
    final isExpanded = _expandedItems[item.id] ?? false;
    final isActive = widget.currentRoute == item.route ||
        (hasChildren &&
            item.children!.any((child) => child.route == widget.currentRoute));

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (hasChildren) {
                setState(() {
                  _expandedItems[item.id] = !isExpanded;
                });
              } else if (item.route != null) {
                widget.onNavigate(item.route!);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCollapsed
                    ? AdminSpacing.sm
                    : AdminSpacing.md,
                vertical: AdminSpacing.sm,
              ),
              margin: const EdgeInsets.symmetric(
                horizontal: AdminSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AdminColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 20,
                    color: isActive
                        ? AdminColors.primary
                        : AdminColors.textSecondary,
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: AdminSpacing.sm),
                    Expanded(
                      child: Text(
                        item.title,
                        style: AdminTypography.bodyMedium.copyWith(
                          color: isActive
                              ? AdminColors.primary
                              : AdminColors.textPrimary,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (item.badgeCount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AdminColors.error,
                          borderRadius:
                              BorderRadius.circular(AdminSpacing.radiusFull),
                        ),
                        child: Text(
                          item.badgeCount.toString(),
                          style: AdminTypography.labelSmall.copyWith(
                            color: AdminColors.textOnPrimary,
                          ),
                        ),
                      ),
                    if (hasChildren)
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 16,
                        color: AdminColors.textSecondary,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded && !widget.isCollapsed)
          ...item.children!.map((child) => Padding(
                padding: const EdgeInsets.only(left: AdminSpacing.lg),
                child: _buildMenuItem(child),
              )),
      ],
    );
  }

  Widget _buildFooter() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Implement logout
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal:
                widget.isCollapsed ? AdminSpacing.sm : AdminSpacing.md,
            vertical: AdminSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.logout,
                size: 20,
                color: AdminColors.error,
              ),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: AdminSpacing.sm),
                Text(
                  'Выход',
                  style: AdminTypography.bodyMedium.copyWith(
                    color: AdminColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
