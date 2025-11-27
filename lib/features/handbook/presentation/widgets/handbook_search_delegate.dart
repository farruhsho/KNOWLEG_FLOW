import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/handbook_data.dart';

/// Search delegate for handbook content
class HandbookSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Поиск в справочнике...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.outfit(
          color: Colors.white70,
          fontSize: 16,
        ),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
        titleLarge: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _searchContent(query);
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: GoogleFonts.outfit(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте другой запрос',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildResultCard(context, result);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildPopularTopics(context);
    }

    final results = _searchContent(query);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.take(5).length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildSuggestionCard(context, result);
      },
    );
  }

  Widget _buildPopularTopics(BuildContext context) {
    final popularTopics = [
      {'title': 'Формулы по математике', 'icon': Icons.functions, 'query': 'формулы'},
      {'title': 'Правила грамматики', 'icon': Icons.spellcheck, 'query': 'грамматика'},
      {'title': 'Структура ОРТ', 'icon': Icons.school, 'query': 'структура'},
      {'title': 'Типичные ошибки', 'icon': Icons.error_outline, 'query': 'ошибки'},
      {'title': 'Логические задачи', 'icon': Icons.psychology, 'query': 'логика'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Популярные темы',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ...popularTopics.map((topic) {
          return ListTile(
            leading: Icon(
              topic['icon'] as IconData,
              color: AppColors.primary,
            ),
            title: Text(
              topic['title'] as String,
              style: GoogleFonts.inter(fontSize: 16),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              query = topic['query'] as String;
              showResults(context);
            },
          );
        }),
      ],
    );
  }

  Widget _buildResultCard(BuildContext context, SearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed('/handbook/${result.categoryId}');
          close(context, result.categoryId);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(result.categoryId).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result.categoryTitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(result.categoryId),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.sectionTitle,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.snippet,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(BuildContext context, SearchResult result) {
    return ListTile(
      leading: Icon(
        Icons.article_outlined,
        color: _getCategoryColor(result.categoryId),
      ),
      title: Text(
        result.sectionTitle,
        style: GoogleFonts.inter(fontSize: 15),
      ),
      subtitle: Text(
        result.categoryTitle,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.of(context).pushNamed('/handbook/${result.categoryId}');
        close(context, result.categoryId);
      },
    );
  }

  List<SearchResult> _searchContent(String searchQuery) {
    if (searchQuery.isEmpty) return [];

    final results = <SearchResult>[];
    final lowercaseQuery = searchQuery.toLowerCase();

    HandbookData.content.forEach((categoryId, categoryData) {
      final categoryTitle = categoryData['title'] as String;
      final sections = categoryData['sections'] as List<Map<String, dynamic>>;

      for (final section in sections) {
        final sectionTitle = section['title'] as String;
        final sectionContent = section['content'] as String;

        // Search in title and content
        if (sectionTitle.toLowerCase().contains(lowercaseQuery) ||
            sectionContent.toLowerCase().contains(lowercaseQuery)) {
          
          // Extract snippet around the match
          String snippet = sectionContent;
          final matchIndex = sectionContent.toLowerCase().indexOf(lowercaseQuery);
          
          if (matchIndex != -1) {
            final start = (matchIndex - 50).clamp(0, sectionContent.length);
            final end = (matchIndex + lowercaseQuery.length + 100).clamp(0, sectionContent.length);
            snippet = sectionContent.substring(start, end);
            if (start > 0) snippet = '...$snippet';
            if (end < sectionContent.length) snippet = '$snippet...';
          } else {
            // If match is only in title, show beginning of content
            snippet = sectionContent.length > 150
                ? '${sectionContent.substring(0, 150)}...'
                : sectionContent;
          }

          results.add(SearchResult(
            categoryId: categoryId,
            categoryTitle: categoryTitle,
            sectionTitle: sectionTitle,
            snippet: snippet,
          ));
        }
      }
    });

    return results;
  }

  Color _getCategoryColor(String id) {
    switch (id) {
      case 'ort_guide':
        return AppColors.primary;
      case 'math_formulas':
        return AppColors.secondary;
      case 'grammar':
        return AppColors.success;
      case 'logic':
        return AppColors.info;
      case 'reading':
        return AppColors.warning;
      case 'common_errors':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}

class SearchResult {
  final String categoryId;
  final String categoryTitle;
  final String sectionTitle;
  final String snippet;

  SearchResult({
    required this.categoryId,
    required this.categoryTitle,
    required this.sectionTitle,
    required this.snippet,
  });
}
