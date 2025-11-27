import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/ort_constants.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../../../../shared/models/question_model.dart';
import '../../data/models/ai_models.dart';
import '../../data/services/ai_service.dart';
import '../../data/repositories/subjects_repository.dart';

/// Professional AI Question Generator Page for ORT Master KG
class AiGeneratorPage extends ConsumerStatefulWidget {
  const AiGeneratorPage({super.key});

  @override
  ConsumerState<AiGeneratorPage> createState() => _AiGeneratorPageState();
}

class _AiGeneratorPageState extends ConsumerState<AiGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _contextController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String? _selectedSubject;
  String? _selectedSection;
  int _difficulty = 2;
  int _questionCount = 5;
  Set<String> _selectedLanguages = {'ru'};
  Set<QuestionType> _selectedQuestionTypes = {QuestionType.singleChoice};
  bool _isGenerating = false;
  AIGenerationResult? _generationResult;
  String? _error;

  // Real-time cost estimation
  double _estimatedCost = 0.0;

  @override
  void initState() {
    super.initState();
    _updateCostEstimate();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _contextController.dispose();
    _instructionsController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _updateCostEstimate() {
    // Estimate tokens: ~150 per question + prompt overhead
    final estimatedTokens = (_questionCount * 150) + 500;
    setState(() {
      _estimatedCost = (estimatedTokens / 1000) * 0.009;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: AdminColors.primary,
        foregroundColor: AdminColors.textOnPrimary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AdminSpacing.sm),
              decoration: BoxDecoration(
                color: AdminColors.primaryLight,
                borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
              ),
              child: const Icon(Icons.psychology, size: 24),
            ),
            const SizedBox(width: AdminSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Генератор Вопросов', style: AdminTypography.h6.copyWith(
                  color: AdminColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                )),
                Text('Claude 4.5 Sonnet', style: AdminTypography.bodySmall.copyWith(
                  color: AdminColors.textOnPrimary.withOpacity(0.8),
                )),
              ],
            ),
          ],
        ),
        actions: [
          if (_generationResult != null && _generationResult!.success)
            Padding(
              padding: const EdgeInsets.only(right: AdminSpacing.sm),
              child: Chip(
                avatar: const Icon(Icons.check_circle, size: 16, color: AdminColors.success),
                label: Text(
                  '${_generationResult!.questions.where((q) => q.isSelected).length} выбрано',
                  style: AdminTypography.labelSmall,
                ),
                backgroundColor: AdminColors.successLight,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: 'Помощь',
          ),
          const SizedBox(width: AdminSpacing.sm),
        ],
      ),
      body: Row(
        children: [
          // Left panel: Generator form
          Expanded(
            flex: 2,
            child: _buildGeneratorForm(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Right panel: Generated questions
          Expanded(
            flex: 3,
            child: _buildGeneratedQuestionsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratorForm() {
    final subjectsAsync = ref.watch(subjectsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API Key Section
            _buildSectionHeader('1. API Ключ', Icons.key),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Claude API Key *',
                hintText: 'sk-ant-api03-...',
                prefixIcon: const Icon(Icons.vpn_key),
                helperText: 'Получите на console.anthropic.com',
                helperStyle: AdminTypography.bodySmall.copyWith(color: AdminColors.textTertiary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  onPressed: () => _showApiKeyHelp(),
                ),
              ),
              obscureText: true,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Введите API ключ';
                if (!v!.startsWith('sk-ant-')) return 'Неверный формат ключа';
                return null;
              },
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Subject & Section Selection
            _buildSectionHeader('2. Раздел ОРТ', Icons.category),
            const SizedBox(height: AdminSpacing.md),

            // ORT Section Selector
            DropdownButtonFormField<String>(
              value: _selectedSection,
              decoration: const InputDecoration(
                labelText: 'Раздел ОРТ *',
                prefixIcon: Icon(Icons.dataset),
                helperText: 'Выберите раздел теста ОРТ',
              ),
              items: OrtConstants.mainSectionsList.map((section) {
                return DropdownMenuItem(
                  value: section.id,
                  child: Row(
                    children: [
                      Text(section.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: AdminSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.nameRu, style: AdminTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                            Text(
                              '${section.questionCount} вопросов • ${section.timeMinutes} мин',
                              style: AdminTypography.bodySmall.copyWith(
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedSection = v),
              validator: (v) => v == null ? 'Выберите раздел ОРТ' : null,
            ),
            const SizedBox(height: AdminSpacing.md),

            // Subject Selector
            subjectsAsync.when(
              data: (subjects) => DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Предмет *',
                  prefixIcon: Icon(Icons.subject),
                  helperText: 'Для контекста и тегирования',
                ),
                items: subjects.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.icon} ${s.title['ru']}'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v),
                validator: (v) => v == null ? 'Выберите предмет' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Ошибка загрузки: $e', style: AdminTypography.bodySmall.copyWith(
                color: AdminColors.error,
              )),
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Topic
            _buildSectionHeader('3. Тема', Icons.topic),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Тема вопросов *',
                hintText: 'Например: Квадратные уравнения',
                prefixIcon: Icon(Icons.auto_stories),
                helperText: 'Конкретная тема для генерации',
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Введите тему' : null,
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Difficulty
            _buildSectionHeader('4. Сложность', Icons.speed),
            const SizedBox(height: AdminSpacing.md),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text('Базовый'),
                  icon: Icon(Icons.star_border),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Средний'),
                  icon: Icon(Icons.star_half),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('Высокий'),
                  icon: Icon(Icons.star),
                ),
              ],
              selected: {_difficulty},
              onSelectionChanged: (v) => setState(() => _difficulty = v.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: AdminColors.surfaceVariant,
                foregroundColor: AdminColors.textPrimary,
                selectedBackgroundColor: AdminColors.primary,
                selectedForegroundColor: AdminColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              _getDifficultyDescription(),
              style: AdminTypography.bodySmall.copyWith(color: AdminColors.textSecondary),
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Question Count
            _buildSectionHeader('5. Количество', Icons.numbers),
            const SizedBox(height: AdminSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _questionCount.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: _questionCount.toString(),
                    onChanged: (v) {
                      setState(() => _questionCount = v.toInt());
                      _updateCostEstimate();
                    },
                  ),
                ),
                const SizedBox(width: AdminSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.md,
                    vertical: AdminSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.primaryLight,
                    borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                    border: Border.all(color: AdminColors.primary),
                  ),
                  child: Text(
                    '$_questionCount',
                    style: AdminTypography.h6.copyWith(
                      color: AdminColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Languages
            _buildSectionHeader('6. Языки', Icons.language),
            const SizedBox(height: AdminSpacing.md),
            Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: AdminSpacing.sm,
              children: [
                _buildLanguageChip('ru', 'Русский', '🇷🇺'),
                _buildLanguageChip('ky', 'Кыргызча', '🇰🇬'),
                _buildLanguageChip('en', 'English', '🇬🇧'),
              ],
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Question Types
            _buildSectionHeader('7. Типы вопросов', Icons.quiz),
            const SizedBox(height: AdminSpacing.md),
            Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: AdminSpacing.sm,
              children: [
                _buildQuestionTypeChip(QuestionType.singleChoice, 'Один ответ', Icons.radio_button_checked),
                _buildQuestionTypeChip(QuestionType.multipleChoice, 'Несколько', Icons.check_box),
                _buildQuestionTypeChip(QuestionType.analogy, 'Аналогия', Icons.compare_arrows),
                _buildQuestionTypeChip(QuestionType.completion, 'Дополнение', Icons.edit_note),
              ],
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Additional Context
            _buildSectionHeader('8. Дополнительно (опционально)', Icons.add_circle_outline),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _contextController,
              decoration: const InputDecoration(
                labelText: 'Контекст',
                hintText: 'Дополнительная информация для AI',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Специальные инструкции',
                hintText: 'Особые требования к генерации',
                prefixIcon: Icon(Icons.flag),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Cost Estimation
            Container(
              padding: const EdgeInsets.all(AdminSpacing.md),
              decoration: BoxDecoration(
                color: AdminColors.infoLight,
                borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                border: Border.all(color: AdminColors.info),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AdminColors.info),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Примерная стоимость', style: AdminTypography.labelMedium.copyWith(
                          color: AdminColors.info,
                          fontWeight: FontWeight.w600,
                        )),
                        Text(
                          '\$${_estimatedCost.toStringAsFixed(4)} USD',
                          style: AdminTypography.bodySmall.copyWith(color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.xl),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.secondary,
                  foregroundColor: AdminColors.textOnPrimary,
                  disabledBackgroundColor: AdminColors.surfaceVariant,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                  ),
                ),
                child: _isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminColors.textOnPrimary,
                            ),
                          ),
                          const SizedBox(width: AdminSpacing.md),
                          Text('Генерация...', style: AdminTypography.h6.copyWith(
                            color: AdminColors.textOnPrimary,
                          )),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, size: 24),
                          const SizedBox(width: AdminSpacing.sm),
                          Text('Сгенерировать вопросы', style: AdminTypography.h6.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                        ],
                      ),
              ),
            ),

            // Error Display
            if (_error != null) ...[
              const SizedBox(height: AdminSpacing.md),
              Container(
                padding: const EdgeInsets.all(AdminSpacing.md),
                decoration: BoxDecoration(
                  color: AdminColors.errorLight,
                  borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                  border: Border.all(color: AdminColors.error, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AdminColors.error, size: 24),
                    const SizedBox(width: AdminSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ошибка генерации', style: AdminTypography.labelLarge.copyWith(
                            color: AdminColors.error,
                            fontWeight: FontWeight.w600,
                          )),
                          const SizedBox(height: AdminSpacing.xs),
                          Text(_error!, style: AdminTypography.bodySmall.copyWith(
                            color: AdminColors.textPrimary,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedQuestionsPanel() {
    if (_generationResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AdminSpacing.xl),
              decoration: BoxDecoration(
                color: AdminColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, size: 80, color: AdminColors.textTertiary),
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(
              'Сгенерированные вопросы появятся здесь',
              style: AdminTypography.h6.copyWith(color: AdminColors.textSecondary),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              'Заполните параметры слева и нажмите "Сгенерировать"',
              style: AdminTypography.bodyMedium.copyWith(color: AdminColors.textTertiary),
            ),
          ],
        ),
      );
    }

    if (!_generationResult!.success) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(AdminSpacing.xl),
          padding: const EdgeInsets.all(AdminSpacing.xl),
          decoration: BoxDecoration(
            color: AdminColors.errorLight,
            borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
            border: Border.all(color: AdminColors.error, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AdminColors.error),
              const SizedBox(height: AdminSpacing.md),
              Text('Ошибка генерации', style: AdminTypography.h5.copyWith(
                color: AdminColors.error,
              )),
              const SizedBox(height: AdminSpacing.sm),
              Text(_generationResult!.error ?? 'Неизвестная ошибка',
                style: AdminTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final questions = _generationResult!.questions;
    final selectedCount = questions.where((q) => q.isSelected).length;

    return Column(
      children: [
        // Statistics Header
        Container(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AdminColors.successLight, AdminColors.infoLight],
            ),
            border: Border(bottom: BorderSide(color: AdminColors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AdminSpacing.sm),
                    decoration: BoxDecoration(
                      color: AdminColors.success,
                      borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.check_circle, color: AdminColors.textOnPrimary, size: 24),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Генерация завершена', style: AdminTypography.h6.copyWith(
                          color: AdminColors.success,
                          fontWeight: FontWeight.w700,
                        )),
                        Text(
                          'Сгенерировано ${questions.length} вопросов за ${_generationResult!.generationTime.inSeconds}с',
                          style: AdminTypography.bodySmall.copyWith(color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminSpacing.md),
              Row(
                children: [
                  _buildStatChip(Icons.token, '${_generationResult!.tokensUsed} токенов', AdminColors.info),
                  const SizedBox(width: AdminSpacing.sm),
                  _buildStatChip(Icons.attach_money, '\$${_generationResult!.estimatedCost.toStringAsFixed(4)}', AdminColors.warning),
                  const SizedBox(width: AdminSpacing.sm),
                  _buildStatChip(Icons.timer, '${_generationResult!.generationTime.inSeconds}с', AdminColors.secondary),
                ],
              ),
              const SizedBox(height: AdminSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all, size: 20),
                      label: const Text('Выбрать все'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect, size: 20),
                      label: const Text('Снять все'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: selectedCount > 0 ? _saveQuestions : null,
                      icon: const Icon(Icons.save, size: 20),
                      label: Text('Сохранить ($selectedCount)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.success,
                        foregroundColor: AdminColors.textOnPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Questions List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            itemCount: questions.length,
            itemBuilder: (context, index) => _buildQuestionCard(questions[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(GeneratedQuestion question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.lg),
      elevation: question.isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
        side: BorderSide(
          color: question.isSelected ? AdminColors.primary : AdminColors.border,
          width: question.isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: question.isSelected ? AdminColors.primaryLight : AdminColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AdminSpacing.radiusMd)),
            ),
            child: Row(
              children: [
                // Selection Checkbox
                Checkbox(
                  value: question.isSelected,
                  onChanged: (v) => setState(() => question.isSelected = v ?? false),
                  activeColor: AdminColors.primary,
                ),
                const SizedBox(width: AdminSpacing.sm),

                // Question Number
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.md,
                    vertical: AdminSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.primary,
                    borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                  ),
                  child: Text('Вопрос ${index + 1}', style: AdminTypography.labelMedium.copyWith(
                    color: AdminColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  )),
                ),
                const SizedBox(width: AdminSpacing.md),

                // Difficulty Stars
                ...List.generate(
                  question.difficulty,
                  (i) => const Icon(Icons.star, size: 18, color: AdminColors.warning),
                ),
                ...List.generate(
                  3 - question.difficulty,
                  (i) => const Icon(Icons.star_border, size: 18, color: AdminColors.textTertiary),
                ),

                const Spacer(),

                // Edit Status
                if (question.isEdited)
                  Chip(
                    avatar: const Icon(Icons.edit, size: 14, color: AdminColors.info),
                    label: Text('Изменено', style: AdminTypography.labelSmall),
                    backgroundColor: AdminColors.infoLight,
                    visualDensity: VisualDensity.compact,
                  ),

                // Action Buttons
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editQuestion(question, index),
                  tooltip: 'Редактировать',
                  color: AdminColors.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _duplicateQuestion(question),
                  tooltip: 'Дублировать',
                  color: AdminColors.secondary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteQuestion(index),
                  tooltip: 'Удалить',
                  color: AdminColors.error,
                ),
              ],
            ),
          ),

          // Question Content
          Padding(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Stem (all languages)
                ..._selectedLanguages.map((lang) {
                  final stemText = question.stem[lang];
                  if (stemText == null || stemText.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AdminSpacing.sm,
                                vertical: AdminSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                              ),
                              child: Text(
                                _getLanguageFlag(lang),
                                style: AdminTypography.labelSmall,
                              ),
                            ),
                            const SizedBox(width: AdminSpacing.sm),
                            Expanded(
                              child: Text(
                                stemText,
                                style: AdminTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const Divider(),
                const SizedBox(height: AdminSpacing.sm),

                // Options
                ...question.options.asMap().entries.map((entry) {
                  final opt = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Option ID with correct indicator
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: opt.isCorrect ? AdminColors.success : AdminColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                            border: Border.all(
                              color: opt.isCorrect ? AdminColors.success : AdminColors.border,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            opt.id,
                            style: AdminTypography.labelMedium.copyWith(
                              color: opt.isCorrect ? AdminColors.textOnPrimary : AdminColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AdminSpacing.md),

                        // Option Text (primary language)
                        Expanded(
                          child: Text(
                            opt.text[_selectedLanguages.first] ?? opt.text['ru'] ?? '',
                            style: AdminTypography.bodyMedium.copyWith(
                              fontWeight: opt.isCorrect ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),

                        if (opt.isCorrect)
                          const Icon(Icons.check_circle, color: AdminColors.success, size: 20),
                      ],
                    ),
                  );
                }).toList(),

                // Explanation
                if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.md),
                  const Divider(),
                  const SizedBox(height: AdminSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    decoration: BoxDecoration(
                      color: AdminColors.infoLight,
                      borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                      border: Border.all(color: AdminColors.info),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, color: AdminColors.info, size: 20),
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Объяснение:', style: AdminTypography.labelMedium.copyWith(
                                color: AdminColors.info,
                                fontWeight: FontWeight.w600,
                              )),
                              const SizedBox(height: AdminSpacing.xs),
                              Text(
                                question.explanation![_selectedLanguages.first] ??
                                question.explanation!['ru'] ?? '',
                                style: AdminTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tags
                if (question.tags.isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.md),
                  Wrap(
                    spacing: AdminSpacing.xs,
                    runSpacing: AdminSpacing.xs,
                    children: question.tags.map((tag) => Chip(
                      label: Text(tag, style: AdminTypography.labelSmall),
                      backgroundColor: AdminColors.surfaceVariant,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AdminColors.primary),
        const SizedBox(width: AdminSpacing.sm),
        Text(title, style: AdminTypography.h6.copyWith(
          color: AdminColors.primary,
          fontWeight: FontWeight.w700,
        )),
      ],
    );
  }

  Widget _buildLanguageChip(String code, String name, String flag) {
    final isSelected = _selectedLanguages.contains(code);
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AdminSpacing.xs),
          Text(name),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedLanguages.add(code);
          } else {
            if (_selectedLanguages.length > 1) {
              _selectedLanguages.remove(code);
            }
          }
        });
      },
      selectedColor: AdminColors.primaryLight,
      checkmarkColor: AdminColors.primary,
    );
  }

  Widget _buildQuestionTypeChip(QuestionType type, String label, IconData icon) {
    final isSelected = _selectedQuestionTypes.contains(type);
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AdminSpacing.xs),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedQuestionTypes.add(type);
          } else {
            if (_selectedQuestionTypes.length > 1) {
              _selectedQuestionTypes.remove(type);
            }
          }
        });
      },
      selectedColor: AdminColors.secondaryLight,
      checkmarkColor: AdminColors.secondary,
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.sm,
          vertical: AdminSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AdminSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: AdminTypography.labelSmall.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQuestions() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один язык')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generationResult = null;
    });

    try {
      final aiService = AiService(apiKey: _apiKeyController.text.trim());

      final result = await aiService.generateQuestions(
        subjectId: _selectedSubject!,
        sectionId: _selectedSection!,
        topic: _topicController.text.trim(),
        difficulty: _difficulty,
        count: _questionCount,
        questionTypes: _selectedQuestionTypes.toList(),
        languages: _selectedLanguages.toList(),
        additionalInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      );

      setState(() {
        _generationResult = result;
        _isGenerating = false;
      });

      if (mounted && result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: AdminSpacing.sm),
                Text('Сгенерировано ${result.questions.length} вопросов за ${result.generationTime.inSeconds}с'),
              ],
            ),
            backgroundColor: AdminColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  void _selectAll() {
    setState(() {
      for (var q in _generationResult!.questions) {
        q.isSelected = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (var q in _generationResult!.questions) {
        q.isSelected = false;
      }
    });
  }

  void _saveQuestions() {
    final selectedQuestions = _generationResult!.questions
        .where((q) => q.isSelected)
        .toList();

    if (selectedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не выбрано ни одного вопроса')),
      );
      return;
    }

    // TODO: Implement actual saving to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Сохранено ${selectedQuestions.length} вопросов'),
        backgroundColor: AdminColors.success,
      ),
    );
  }

  void _editQuestion(GeneratedQuestion question, int index) {
    // TODO: Implement question editing dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Редактирование будет реализовано')),
    );
  }

  void _duplicateQuestion(GeneratedQuestion question) {
    setState(() {
      final duplicate = GeneratedQuestion(
        stem: Map<String, String>.from(question.stem),
        options: question.options.map((o) => GeneratedOption(
          id: o.id,
          text: Map<String, String>.from(o.text),
          isCorrect: o.isCorrect,
        )).toList(),
        correctAnswer: question.correctAnswer,
        explanation: question.explanation != null
            ? Map<String, String>.from(question.explanation!)
            : null,
        tags: List<String>.from(question.tags),
        difficulty: question.difficulty,
        subjectId: question.subjectId,
        sectionId: question.sectionId,
        isSelected: false,
        isEdited: false,
      );
      _generationResult!.questions.add(duplicate);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вопрос дублирован')),
    );
  }

  void _deleteQuestion(int index) {
    setState(() {
      _generationResult!.questions.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вопрос удален')),
    );
  }

  String _getDifficultyDescription() {
    switch (_difficulty) {
      case 1:
        return 'Базовые знания, прямые формулы, простые вычисления';
      case 2:
        return 'Применение знаний, комбинированные задачи, анализ';
      case 3:
        return 'Сложные задачи, нестандартные подходы, синтез';
      default:
        return '';
    }
  }

  String _getLanguageFlag(String code) {
    switch (code) {
      case 'ru':
        return '🇷🇺 RU';
      case 'ky':
        return '🇰🇬 KY';
      case 'en':
        return '🇬🇧 EN';
      default:
        return code.toUpperCase();
    }
  }

  void _showApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: AdminColors.primary),
            SizedBox(width: AdminSpacing.sm),
            Text('Как получить API ключ'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Перейдите на console.anthropic.com',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: AdminSpacing.sm),
              Text('2. Зарегистрируйтесь или войдите'),
              SizedBox(height: AdminSpacing.sm),
              Text('3. Откройте Settings → API Keys'),
              SizedBox(height: AdminSpacing.sm),
              Text('4. Нажмите "Create Key"'),
              SizedBox(height: AdminSpacing.sm),
              Text('5. Скопируйте ключ (начинается с sk-ant-)'),
              SizedBox(height: AdminSpacing.lg),
              Text(
                '💡 Совет: Для тестирования Anthropic дает \$5 бесплатных кредитов',
                style: TextStyle(
                  color: AdminColors.info,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AdminColors.primary),
            SizedBox(width: AdminSpacing.sm),
            Text('Помощь - AI Генератор'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🤖 AI Генератор',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: AdminSpacing.sm),
              Text('Использует Claude 4.5 Sonnet для создания высококачественных вопросов ОРТ.'),
              SizedBox(height: AdminSpacing.lg),
              Text(
                '📝 Как использовать:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: AdminSpacing.sm),
              Text('1. Введите Claude API ключ'),
              Text('2. Выберите раздел ОРТ и предмет'),
              Text('3. Укажите тему вопросов'),
              Text('4. Настройте сложность и количество'),
              Text('5. Выберите языки и типы вопросов'),
              Text('6. Нажмите "Сгенерировать"'),
              SizedBox(height: AdminSpacing.lg),
              Text(
                '✨ Возможности:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: AdminSpacing.sm),
              Text('• Генерация до 20 вопросов за раз'),
              Text('• Многоязычная поддержка (RU, KY, EN)'),
              Text('• Различные типы вопросов'),
              Text('• Редактирование перед сохранением'),
              Text('• Выбор вопросов для сохранения'),
              Text('• Статистика использования и стоимости'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
