import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/handbook_search_delegate.dart';

/// Handbook page - reference materials and formulas
class HandbookPage extends StatelessWidget {
  const HandbookPage({super.key});

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
                'Справочник',
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
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.grey200.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: AppColors.primary),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: HandbookSearchDelegate(),
                    );
                  },
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCategoryCard(
                  context,
                  id: 'ort_guide',
                  title: 'Руководство по ОРТ',
                  subtitle: 'Структура, правила и советы',
                  icon: Icons.school_outlined,
                  color: AppColors.primary,
                  gradientColors: [
                    AppColors.primary.withValues(alpha: 0.8),
                    AppColors.primary,
                  ],
                  itemCount: 3,
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  id: 'math_formulas',
                  title: 'Математика',
                  subtitle: 'Формулы и теоремы',
                  icon: Icons.functions,
                  color: AppColors.secondary,
                  gradientColors: [
                    AppColors.secondary.withValues(alpha: 0.8),
                    AppColors.secondary,
                  ],
                  itemCount: 3,
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  id: 'grammar',
                  title: 'Грамматика',
                  subtitle: 'Правила русского и кыргызского',
                  icon: Icons.spellcheck,
                  color: AppColors.success,
                  gradientColors: [
                    AppColors.success.withValues(alpha: 0.8),
                    AppColors.success,
                  ],
                  itemCount: 2,
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  id: 'logic',
                  title: 'Логика',
                  subtitle: 'Аналогии и логические связи',
                  icon: Icons.psychology_outlined,
                  color: AppColors.info,
                  gradientColors: [
                    AppColors.info.withValues(alpha: 0.8),
                    AppColors.info,
                  ],
                  itemCount: 2,
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  id: 'reading',
                  title: 'Чтение',
                  subtitle: 'Работа с текстом и понимание',
                  icon: Icons.menu_book_outlined,
                  color: AppColors.warning,
                  gradientColors: [
                    AppColors.warning.withValues(alpha: 0.8),
                    AppColors.warning,
                  ],
                  itemCount: 2,
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  id: 'common_errors',
                  title: 'Типичные ошибки',
                  subtitle: 'Разбор частых ошибок',
                  icon: Icons.error_outline,
                  color: AppColors.error,
                  gradientColors: [
                    AppColors.error.withValues(alpha: 0.8),
                    AppColors.error,
                  ],
                  itemCount: 2,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    required int itemCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/handbook/$id');
          },
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background Gradient
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                ),
              ),
              
              // Decorative Circles
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$itemCount разделов',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
