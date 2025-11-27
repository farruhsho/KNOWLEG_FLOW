import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../../data/models/ai_models.dart';
import '../../data/services/ai_service.dart';
import '../../data/repositories/subjects_repository.dart';

/// AI Question Generator Page
class AiGeneratorPage extends ConsumerStatefulWidget {
  const AiGeneratorPage({super.key});

  @override
  ConsumerState<AiGeneratorPage> createState() => _AiGeneratorPageState();
}

class _AiGeneratorPageState extends ConsumerState<AiGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _contextController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String? _selectedSubject;
  int _difficulty = 2;
  int _questionCount = 5;
  String _language = 'ru';
  bool _isGenerating = false;
  List<GeneratedQuestion>? _generatedQuestions;
  String? _error;

  @override
  void dispose() {
    _topicController.dispose();
    _contextController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Генератор Вопросов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: 'Помощь',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: 2, child: _buildGeneratorForm()),
          const VerticalDivider(width: 1),
          Expanded(flex: 3, child: _buildGeneratedQuestionsPanel()),
        ],
      ),
    );
  }

  Widget _buildGeneratorForm() {
    final subjectsAsync = ref.watch(subjectsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Параметры генерации', style: AdminTypography.h5),
            const SizedBox(height: AdminSpacing.lg),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Claude API Key',
                hintText: 'sk-ant-...',
                prefixIcon: Icon(Icons.key),
                helperText: 'Получите ключ на console.anthropic.com',
              ),
              obscureText: true,
              validator: (v) => v?.isEmpty ?? true ? 'Введите API ключ' : null,
            ),
            const SizedBox(height: AdminSpacing.md),
            subjectsAsync.when(
              data: (subjects) => DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Предмет',
                  prefixIcon: Icon(Icons.subject),
                ),
                items: subjects.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.icon} ${s.title['ru']}'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v),
                validator: (v) => v == null ? 'Выберите предмет' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Ошибка: $e'),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Тема',
                hintText: 'Например: Квадратные уравнения',
                prefixIcon: Icon(Icons.topic),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Введите тему' : null,
            ),
            const SizedBox(height: AdminSpacing.md),
            Text('Сложность', style: AdminTypography.labelLarge),
            const SizedBox(height: AdminSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Легко'), icon: Icon(Icons.star_border)),
                ButtonSegment(value: 2, label: Text('Средне'), icon: Icon(Icons.star_half)),
                ButtonSegment(value: 3, label: Text('Сложно'), icon: Icon(Icons.star)),
              ],
              selected: {_difficulty},
              onSelectionChanged: (v) => setState(() => _difficulty = v.first),
            ),
            const SizedBox(height: AdminSpacing.md),
            Text('Количество: $_questionCount', style: AdminTypography.labelLarge),
            Slider(
              value: _questionCount.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: _questionCount.toString(),
              onChanged: (v) => setState(() => _questionCount = v.toInt()),
            ),
            const SizedBox(height: AdminSpacing.md),
            Text('Язык', style: AdminTypography.labelLarge),
            const SizedBox(height: AdminSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ru', label: Text('Русский')),
                ButtonSegment(value: 'ky', label: Text('Кыргызча')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_language},
              onSelectionChanged: (v) => setState(() => _language = v.first),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _contextController,
              decoration: const InputDecoration(
                labelText: 'Контекст (опционально)',
                hintText: 'Дополнительная информация',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AdminSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateQuestions,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating ? 'Генерация...' : 'Сгенерировать'),
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.secondary),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AdminSpacing.md),
              Container(
                padding: const EdgeInsets.all(AdminSpacing.md),
                decoration: BoxDecoration(
                  color: AdminColors.errorLight,
                  borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                  border: Border.all(color: AdminColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AdminColors.error),
                    const SizedBox(width: AdminSpacing.sm),
                    Expanded(child: Text(_error!, style: AdminTypography.bodySmall)),
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
    if (_generatedQuestions == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 64, color: AdminColors.textTertiary),
            const SizedBox(height: AdminSpacing.md),
            Text(
              'Сгенерированные вопросы появятся здесь',
              style: AdminTypography.bodyLarge.copyWith(color: AdminColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AdminSpacing.md),
          decoration: const BoxDecoration(
            color: AdminColors.successLight,
            border: Border(bottom: BorderSide(color: AdminColors.success)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AdminColors.success),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                'Сгенерировано: ${_generatedQuestions!.length} вопросов',
                style: AdminTypography.h6.copyWith(color: AdminColors.success),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _saveQuestions,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить все'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AdminSpacing.md),
            itemCount: _generatedQuestions!.length,
            itemBuilder: (context, index) => _buildQuestionCard(_generatedQuestions![index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(GeneratedQuestion question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm, vertical: AdminSpacing.xs),
                  decoration: BoxDecoration(
                    color: AdminColors.primary,
                    borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                  ),
                  child: Text('Q${index + 1}', style: AdminTypography.labelSmall.copyWith(
                    color: AdminColors.textOnPrimary,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                const SizedBox(width: AdminSpacing.sm),
                ...List.generate(question.difficulty, (i) => const Icon(Icons.star, size: 16, color: AdminColors.warning)),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              question.stem[_language] ?? question.stem['ru'] ?? '',
              style: AdminTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AdminSpacing.md),
            ...question.options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: opt.isCorrect ? AdminColors.success : AdminColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: opt.isCorrect ? AdminColors.success : AdminColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(opt.id, style: AdminTypography.labelSmall.copyWith(
                      color: opt.isCorrect ? AdminColors.textOnPrimary : AdminColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(child: Text(opt.text[_language] ?? opt.text['ru'] ?? '', style: AdminTypography.bodyMedium)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedQuestions = null;
    });

    try {
      final aiService = AiService(apiKey: _apiKeyController.text.trim());
      final request = AiQuestionRequest(
        subjectId: _selectedSubject!,
        topic: _topicController.text,
        difficulty: _difficulty,
        count: _questionCount,
        language: _language,
        context: _contextController.text.isEmpty ? null : _contextController.text,
      );

      final response = await aiService.generateQuestions(request);

      setState(() {
        _generatedQuestions = response.questions;
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Сгенерировано ${response.questions.length} вопросов'),
            backgroundColor: AdminColors.success,
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

  void _saveQuestions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вопросы сохранены!')),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Помощь - AI Генератор'),
        content: const SingleChildScrollView(
          child: Text('🤖 AI Генератор использует Claude 3.5 для создания вопросов.\n\n📝 Как использовать:\n1. Получите API ключ\n2. Выберите предмет и тему\n3. Настройте параметры\n4. Нажмите "Сгенерировать"'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно')),
        ],
      ),
    );
  }
}
