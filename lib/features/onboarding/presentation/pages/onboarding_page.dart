import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/onboarding_provider.dart';
import '../../domain/onboarding_answers.dart';
import '../widgets/choice_tile.dart';
import '../widgets/region_picker.dart';

/// Four short, skippable steps (ONB-01): language (= exam language), grade +
/// region, target score, daily goal. Answers are stored locally and merged
/// into `users/{uid}` once the user is signed in.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _universityController = TextEditingController();
  int _step = 0;
  bool _saving = false;
  late OnboardingAnswers _answers;

  @override
  void initState() {
    super.initState();
    final service = ref.read(onboardingServiceProvider);
    final pending = service.pendingAnswers;
    final uiLanguage = ref.read(localeProvider).languageCode;
    _answers = (pending ?? const OnboardingAnswers()).copyWith(
      language: pending?.language ?? contentLanguageFor(uiLanguage),
    );
    _universityController.text = _answers.targetUniversity ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  void _update(OnboardingAnswers answers) => setState(() => _answers = answers);

  Future<void> _selectLanguage(String code) async {
    _update(_answers.copyWith(language: code));
    await ref.read(localeProvider.notifier).setLanguageCode(code);
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: AppMotion.of(context, AppMotion.slow),
      curve: AppMotion.standard,
    );
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      _goTo(_step + 1);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) _goTo(_step - 1);
  }

  Future<void> _finish({bool skipped = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(onboardingServiceProvider);

    final university = _universityController.text.trim();
    final answers = _answers.copyWith(
      targetUniversity: university.isEmpty ? null : university,
    );

    await service.setOnboardingCompleted();
    // A skip before answering anything beyond the language must not mark
    // the profile as set up (the dashboard keeps offering the setup card).
    final hasAnswers = !skipped ||
        answers.grade != null ||
        answers.goalBand != null ||
        answers.oblast != null ||
        answers.dailyGoalMinutes != null ||
        university.isNotEmpty;
    if (hasAnswers) await service.savePendingAnswers(answers);

    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      if (hasAnswers) {
        final ok = await service.flushPendingAnswers(uid);
        if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.shellOnbSavedLater)));
      }
      if (!mounted) return;
      context.go(RoutePaths.home);
    } else {
      if (!mounted) return;
      context.go(RoutePaths.signup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    final isLast = _step == _stepCount - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, AppSpacing.xs, 0),
                child: Row(
                  children: [
                    Expanded(child: _StepIndicator(step: _step, count: _stepCount)),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _saving ? null : () => _finish(skipped: true),
                      child: Text(l.shellOnbSkip),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _LanguageStep(
                      selected: _answers.language,
                      onSelected: _selectLanguage,
                    ),
                    _AboutStep(
                      answers: _answers,
                      onChanged: _update,
                    ),
                    _GoalStep(
                      answers: _answers,
                      universityController: _universityController,
                      onChanged: _update,
                    ),
                    _DailyGoalStep(
                      answers: _answers,
                      onChanged: _update,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.lg),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _saving ? null : _back,
                        child: Text(l.shellOnbBack),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isLast ? l.shellOnbStart : l.shellOnbNext),
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

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: l.shellOnbStepOf(step + 1, count),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.normal),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? scheme.primary : context.tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Common layout for a step: title, subtitle, scrollable content.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gutter = AppSpacing.gutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.xxl, gutter, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: text.bodyMedium?.copyWith(color: context.tokens.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ...children,
        ],
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
      title: l.shellOnbLanguageTitle,
      subtitle: l.shellOnbLanguageSubtitle,
      children: [
        ChoiceTile(
          title: l.shellLangRuNative,
          subtitle: l.shellOnbLangRuHint,
          leading: const _LangBadge('RU'),
          selected: selected == 'ru',
          onTap: () => onSelected('ru'),
        ),
        const SizedBox(height: AppSpacing.md),
        ChoiceTile(
          title: l.shellLangKyNative,
          subtitle: l.shellOnbLangKyHint,
          leading: const _LangBadge('KG'),
          selected: selected == 'ky',
          onTap: () => onSelected('ky'),
        ),
      ],
    );
  }
}

class _LangBadge extends StatelessWidget {
  const _LangBadge(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.tokens.surfaceMuted,
        borderRadius: AppRadii.smAll,
      ),
      child: Text(
        code,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}

class _AboutStep extends StatelessWidget {
  const _AboutStep({required this.answers, required this.onChanged});

  final OnboardingAnswers answers;
  final ValueChanged<OnboardingAnswers> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return _StepScaffold(
      title: l.shellOnbAboutTitle,
      subtitle: l.shellOnbAboutSubtitle,
      children: [
        Text(l.shellGradeLabel, style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final grade in OnboardingAnswers.gradeOptions)
              ChoiceChip(
                label: Text(gradeLabel(l, grade)),
                selected: answers.grade == grade,
                onSelected: (_) => onChanged(answers.copyWith(grade: grade)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(l.shellRegionLabel, style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        RegionPicker(
          oblast: answers.oblast,
          district: answers.district,
          onChanged: (oblast, district) => onChanged(
            answers.copyWith(
              oblast: oblast,
              district: district,
              clearDistrict: district == null,
            ),
          ),
        ),
      ],
    );
  }
}

/// "9 класс" / "Выпускник".
String gradeLabel(AppLocalizations l, int grade) =>
    grade == OnboardingAnswers.gradeGraduate
        ? l.shellGradeGraduate
        : l.shellGradeNumber(grade);

/// Localized description of a goal band.
String goalBandDescription(AppLocalizations l, String band) {
  switch (band) {
    case '110+':
      return l.shellGoalBand110Desc;
    case '150+':
      return l.shellGoalBand150Desc;
    case '190+':
      return l.shellGoalBand190Desc;
  }
  return '';
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    required this.answers,
    required this.universityController,
    required this.onChanged,
  });

  final OnboardingAnswers answers;
  final TextEditingController universityController;
  final ValueChanged<OnboardingAnswers> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
      title: l.shellOnbGoalTitle,
      subtitle: l.shellOnbGoalSubtitle,
      children: [
        for (final band in OnboardingAnswers.goalBands) ...[
          ChoiceTile(
            title: band,
            subtitle: goalBandDescription(l, band),
            selected: answers.goalBand == band,
            onTap: () => onChanged(answers.copyWith(goalBand: band)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ChoiceTile(
          title: l.shellGoalUnsure,
          selected: answers.goalBand == null,
          onTap: () => onChanged(answers.copyWith(clearGoalBand: true)),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: universityController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: l.shellOnbUniversityLabel,
            hintText: l.shellOnbUniversityHint,
            helperText: l.shellOptional,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class _DailyGoalStep extends StatelessWidget {
  const _DailyGoalStep({required this.answers, required this.onChanged});

  final OnboardingAnswers answers;
  final ValueChanged<OnboardingAnswers> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String describe(int minutes) => switch (minutes) {
          10 => l.shellDaily10Desc,
          20 => l.shellDaily20Desc,
          _ => l.shellDaily30Desc,
        };
    return _StepScaffold(
      title: l.shellOnbDailyTitle,
      subtitle: l.shellOnbDailySubtitle,
      children: [
        for (final minutes in OnboardingAnswers.dailyGoalOptions) ...[
          ChoiceTile(
            title: l.shellDailyMinutes(minutes),
            subtitle: describe(minutes),
            leading: Icon(
              Icons.timer_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            selected: answers.dailyGoalMinutes == minutes,
            onTap: () => onChanged(answers.copyWith(dailyGoalMinutes: minutes)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
