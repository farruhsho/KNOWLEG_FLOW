import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/language_toggle_widget.dart';
import '../../../auth/domain/auth_validation.dart';
import '../../../onboarding/domain/onboarding_answers.dart';
import '../../../onboarding/presentation/pages/onboarding_page.dart'
    show gradeLabel, goalBandDescription;
import '../../../onboarding/presentation/widgets/region_picker.dart';

/// Opens the profile editor. Returns true when something was saved.
Future<bool?> showProfileEditSheet(BuildContext context, UserModel? user) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProfileEditSheet(user: user),
  );
}

/// Edits the non-privileged profile fields (name, grade, region, school,
/// preferred language, goals). Writes are merged into `users/{uid}`; the
/// rules forbid `role`/`subscription`, which are never sent.
class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key, required this.user});

  final UserModel? user;

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _school;
  late final TextEditingController _university;
  int? _grade;
  String? _oblast;
  String? _district;
  late String _language;
  String? _goalBand;
  int? _dailyGoal;
  bool _saving = false;
  String? _error;

  UserModel? get _user => widget.user;

  @override
  void initState() {
    super.initState();
    final u = _user;
    _name = TextEditingController(text: u?.name ?? '');
    _school = TextEditingController(text: u?.school ?? '');
    _university = TextEditingController(
      text: (u?.targetUniversities.isNotEmpty ?? false)
          ? u!.targetUniversities.first
          : '',
    );
    _grade = OnboardingAnswers.gradeOptions.contains(u?.grade) ? u!.grade : null;
    _oblast = u?.region?.oblast;
    _district = (u?.region?.district.isEmpty ?? true) ? null : u!.region!.district;
    final pref = u?.preferredLanguage;
    _language = kContentLanguageCodes.contains(pref)
        ? pref!
        : ref.read(contentLanguageProvider);
    _goalBand = OnboardingAnswers.goalBands.contains(u?.goalBand) ? u!.goalBand : null;
    _dailyGoal = OnboardingAnswers.dailyGoalOptions.contains(u?.dailyGoalMinutes)
        ? u!.dailyGoalMinutes
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _university.dispose();
    super.dispose();
  }

  bool get _regionLocked => !(_user?.canUpdateRegion() ?? true);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });

    final previousOblast = _user?.region?.oblast;
    final regionChanged = _oblast != null &&
        (_oblast != previousOblast || (_district ?? '') != (_user?.region?.district ?? ''));
    final university = _university.text.trim();
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'school': _school.text.trim().isEmpty ? null : _school.text.trim(),
      'preferred_language': _language,
      if (_grade != null) 'grade': _grade,
      'goal_band': _goalBand,
      if (_dailyGoal != null) 'daily_goal_minutes': _dailyGoal,
      'target_universities': university.isEmpty ? <String>[] : [university],
      if (regionChanged && !_regionLocked)
        'region': {
          'oblast': _oblast,
          'district': _district ?? '',
          'settlement': '',
        },
      // Changing an existing region starts the once-a-year lock; the first
      // time a region is set does not.
      if (regionChanged && !_regionLocked && previousOblast != null)
        'region_last_updated': FieldValue.serverTimestamp(),
      if (_user?.onboardingCompletedAt == null)
        'onboarding_completed_at': FieldValue.serverTimestamp(),
    };

    try {
      await ref
          .read(authServiceProvider)
          .updateProfileFields(fields)
          .timeout(const Duration(seconds: 8));
      if (ref.read(localeProvider).languageCode != 'en') {
        await changeAppLanguage(ref, _language);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.shellProfileSaved)));
      navigator.pop(true);
    } on TimeoutException {
      // Firestore keeps the write queued offline and syncs it later.
      messenger.showSnackBar(SnackBar(content: Text(l.shellProfileSavedOffline)));
      navigator.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.shellProfileSaveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final gutter = AppSpacing.gutter(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.shellProfileEditTitle, style: text.titleLarge),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: l.shellAuthNameLabel,
                  counterText: '',
                ),
                validator: (v) => l.shellValidate(AuthValidators.name(v)),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.shellGradeLabel, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final g in OnboardingAnswers.gradeOptions)
                    ChoiceChip(
                      label: Text(gradeLabel(l, g)),
                      selected: _grade == g,
                      onSelected: (_) => setState(() => _grade = g),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.shellRegionLabel, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              RegionPicker(
                oblast: _oblast,
                district: _district,
                enabled: !_regionLocked,
                onChanged: (o, d) => setState(() {
                  _oblast = o;
                  _district = d;
                }),
              ),
              if (_regionLocked) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.shellProfileRegionLocked,
                  style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _school,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l.shellProfileSchool,
                  helperText: l.shellOptional,
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.shellProfileExamLanguage, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ru', label: Text(l.shellLangRuNative)),
                  ButtonSegment(value: 'ky', label: Text(l.shellLangKyNative)),
                ],
                selected: {_language},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _language = s.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.shellProfileGoal, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final band in OnboardingAnswers.goalBands)
                    ChoiceChip(
                      label: Text(band),
                      tooltip: goalBandDescription(l, band),
                      selected: _goalBand == band,
                      onSelected: (_) => setState(() => _goalBand = band),
                    ),
                  ChoiceChip(
                    label: Text(l.shellGoalUnsure),
                    selected: _goalBand == null,
                    onSelected: (_) => setState(() => _goalBand = null),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _university,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l.shellOnbUniversityLabel,
                  hintText: l.shellOnbUniversityHint,
                  helperText: l.shellOptional,
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.shellProfileDailyGoal, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in OnboardingAnswers.dailyGoalOptions)
                    ChoiceChip(
                      label: Text(l.shellDailyMinutes(m)),
                      selected: _dailyGoal == m,
                      onSelected: (_) => setState(() => _dailyGoal = m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_error != null) ...[
                Text(_error!, style: text.bodyMedium?.copyWith(color: tokens.danger)),
                const SizedBox(height: AppSpacing.md),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.shellSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
