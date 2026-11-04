import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/admin/application/admin_providers.dart';
import 'package:knowledge_flow/features/admin/application/paged_list.dart';
import 'package:knowledge_flow/features/admin/data/admin_firebase.dart';
import 'package:knowledge_flow/features/admin/data/models/admin_records.dart';
import 'package:knowledge_flow/features/admin/data/repositories/content_repositories.dart';
import 'package:knowledge_flow/features/admin/data/repositories/people_repositories.dart';
import 'package:knowledge_flow/features/admin/domain/admin_role.dart';
import 'package:knowledge_flow/features/admin/domain/callable_errors.dart';
import 'package:knowledge_flow/features/admin/domain/exam_question.dart';
import 'package:knowledge_flow/features/admin/domain/review_workflow.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/variants_page.dart';
import 'package:knowledge_flow/features/admin/presentation/shell/admin_shell.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/file_io.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/table_editor.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/providers/admin_access_provider.dart';

/// Regression tests for the integration review fixes owned by the admin CMS:
/// CP-03, CP-04, CP-05, CP-08, AUTH-ADM-02/04/05/08, SEC-MOD-01,
/// SEC-APPCHECK-01 (CP-09 lives in variant_validation_test.dart).

/// One draft exactly as `adminAiDraftQuestions` returns it (functions/src/handlers/ai.ts).
Map<String, dynamic> _serverDraft({
  required String type,
  String stem = '',
  String? columnA,
  String? columnB,
  List<Map<String, String>> options = const [],
  String correct = 'A',
}) =>
    {
      'question': {
        'subject_id': 'math',
        'section_id': 'math',
        'part_id': type == kQuantitativeComparison ? 'math_comparison' : 'math_problems',
        'topic_id': 'math.fractions',
        'difficulty': 3,
        'language': 'ru',
        'type': type,
        'stem': stem,
        'column_a': columnA,
        'column_b': columnB,
        'options': options,
        'passage_id': null,
        'image_path': null,
        'table': null,
        'source': {'kind': 'ai_draft', 'basis': 'topic math.fractions', 'author': 'ai:claude-opus-5-5'},
        'review': {'status': 'draft', 'reviewed_by': null, 'reviewed_at': null, 'notes': ''},
        'content_version': 1,
      },
      'key': {
        'correct': correct,
        'explanation': 'Потому что',
        'wrong_option_notes': {'B': 'нет'},
        'solution_steps': ['шаг 1'],
      },
      'valid': true,
    };

AiDraft _parse(Map<String, dynamic> raw, {String type = 'single_choice'}) => parseAiDraft(
      raw,
      id: 'new1',
      subjectId: 'math',
      sectionId: 'math',
      partId: 'math_problems',
      topicId: 'fallback.topic',
      difficulty: 2,
      language: 'ru',
      type: type,
    );

ExamQuestionDoc _approved({Map<String, dynamic> extra = const {}}) => ExamQuestionDoc.fromMap('q1', {
      'subject_id': 'math',
      'section_id': 'math',
      'part_id': 'math_comparison',
      'topic_id': 'math.fractions',
      'difficulty': 2,
      'language': 'ru',
      'type': kQuantitativeComparison,
      'stem': 'Сравните величины А и Б.',
      'options': [
        {'id': 'A', 'text': 'А больше'},
        {'id': 'B', 'text': 'Б больше'},
        {'id': 'C', 'text': 'Равны'},
        {'id': 'D', 'text': 'Недостаточно данных'},
      ],
      'table': {
        'headers': ['Колонка А', 'Колонка Б'],
        'rows': [
          {
            'cells': [r'$\frac{1}{2}$', r'$\frac{2}{3}$'],
          },
        ],
      },
      'review': {'status': 'methodologist_approved', 'reviewed_by': 'm1'},
      'content_hash': 'sha256:pipeline',
      ...extra,
    });

void main() {
  group('CP-03 / CP-08: adminAiDraftQuestions drafts', () {
    test('the nested server shape is parsed (single choice)', () {
      final d = _parse(_serverDraft(
        type: 'single_choice',
        stem: r'Найдите $\frac{1}{2}+\frac{1}{3}$',
        options: const [
          {'id': 'A', 'text': '5/6'},
          {'id': 'B', 'text': '2/5'},
          {'id': 'C', 'text': '1/6'},
          {'id': 'D', 'text': '1'},
          {'id': 'E', 'text': '2/3'},
        ],
      ));
      expect(d.question.stem, r'Найдите $\frac{1}{2}+\frac{1}{3}$');
      expect(d.question.options.map((o) => o.id), ['A', 'B', 'C', 'D', 'E']);
      expect(d.question.topicId, 'math.fractions');
      expect(d.question.difficulty, 3);
      expect(d.question.type, 'single_choice');
      expect(d.question.review.status, ReviewStatus.draft);
      expect(d.question.source.kind, 'ai');
      expect(d.key.correct, 'A');
      expect(d.key.wrongOptionNotes, {'B': 'нет'});
      expect(d.serverValid, isTrue);
      expect(validateExamQuestion(d.question, d.key, expectedOptions: 5), isEmpty);
    });

    test('comparison drafts keep column_a / column_b and pass with the fixed options', () {
      final raw = _serverDraft(type: kQuantitativeComparison, columnA: r'$2^{10}$', columnB: r'$10^3$');
      var d = _parse(raw, type: kQuantitativeComparison);
      expect(d.question.columnA, r'$2^{10}$');
      expect(d.question.columnB, r'$10^3$');
      expect(d.question.stem, isEmpty);
      expect(d.question.options, isEmpty);
      // The page injects the part's fixed options (the server sends `options: []`).
      d = AiDraft(
        d.question.copyWith(options: const [
          ExamOption('A', 'А больше'),
          ExamOption('B', 'Б больше'),
          ExamOption('C', 'Равны'),
          ExamOption('D', 'Недостаточно данных'),
        ]),
        d.key,
      );
      expect(validateExamQuestion(d.question, d.key, expectedOptions: 4, requireColumns: true), isEmpty);
      final fields = d.question.toContentFields();
      expect(fields['column_a'], r'$2^{10}$');
      expect(fields['column_b'], r'$10^3$');
    });

    test('a comparison draft without its quantities is not savable', () {
      final d = _parse(_serverDraft(type: kQuantitativeComparison, stem: 'Условие', columnA: '5'),
          type: kQuantitativeComparison);
      final q = d.question.copyWith(options: const [
        ExamOption('A', 'a'),
        ExamOption('B', 'b'),
        ExamOption('C', 'c'),
        ExamOption('D', 'd'),
      ]);
      expect(validateExamQuestion(q, d.key, expectedOptions: 4, requireColumns: true),
          [ExamQuestionIssue.columnsIncomplete]);
      final none = q.copyWith(clearColumnA: true);
      expect(validateExamQuestion(none, d.key, expectedOptions: 4, requireColumns: true),
          [ExamQuestionIssue.columnsIncomplete]);
      // Outside AI drafts a stem-only comparison item is still valid.
      expect(validateExamQuestion(none, d.key, expectedOptions: 4), isEmpty);
    });

    test('columns are read in snake and camel case', () {
      final q = ExamQuestionDoc.fromMap('x', {'columnA': '1', 'column_b': '2', 'stem': ''});
      expect(q.columnA, '1');
      expect(q.columnB, '2');
      expect(q.hasColumns, isTrue);
    });
  });

  group('CP-05: tables (D2 storage shape)', () {
    test('reads both row shapes, writes {cells} and never nested arrays', () {
      final wire = ExamTableDoc.fromAny({
        'headers': ['A', 'B'],
        'rows': [
          ['1', '2'],
          ['3'],
        ],
      })!;
      final stored = ExamTableDoc.fromAny({
        'headers': ['A', 'B'],
        'rows': [
          {
            'cells': ['1', '2'],
          },
          {
            'cells': ['3', ''],
          },
        ],
      })!;
      expect(wire.paddedRows, [
        ['1', '2'],
        ['3', ''],
      ]);
      expect(wire, stored);
      final out = stored.toFirestore();
      expect(out['headers'], ['A', 'B']);
      expect(out['rows'], [
        {
          'cells': ['1', '2'],
        },
        {
          'cells': ['3', ''],
        },
      ]);
      for (final r in out['rows'] as List) {
        expect(r, isA<Map>());
        expect((r as Map)['cells'], everyElement(isA<String>()));
      }
      expect(ExamTableDoc.fromAny(null), isNull);
      expect(ExamTableDoc.fromAny({'headers': [], 'rows': []}), isNull);
    });

    test('editing operations', () {
      var t = ExamTableDoc.blank();
      expect(t.isBlank, isTrue);
      t = t.setHeader(0, 'А').setHeader(1, 'Б').setCell(0, 0, '5').setCell(0, 1, '7');
      expect(t.toFirestore(), {
        'headers': ['А', 'Б'],
        'rows': [
          {
            'cells': ['5', '7'],
          },
        ],
      });
      t = t.addColumn().setCell(0, 2, '9');
      expect(t.columnCount, 3);
      t = t.removeColumn(1);
      expect(t.paddedHeaders, ['А', '']);
      expect(t.paddedRows, [
        ['5', '9'],
      ]);
      t = t.addRow();
      expect(t.rows.length, 2);
      // Blank rows and a blank header row are not stored.
      expect(t.toFirestore()['rows'], hasLength(1));
      expect(ExamTableDoc.blank().setCell(0, 0, 'x').toFirestore()['headers'], isEmpty);
      t = t.removeRow(0).removeRow(0);
      expect(t.rows, isEmpty);
    });

    test('the question model keeps the table and treats it as review-relevant', () {
      final q = _approved();
      expect(q.table!.paddedRows.single, [r'$\frac{1}{2}$', r'$\frac{2}{3}$']);
      expect(q.toContentFields()['table'], {
        'headers': ['Колонка А', 'Колонка Б'],
        'rows': [
          {
            'cells': [r'$\frac{1}{2}$', r'$\frac{2}{3}$'],
          },
        ],
      });
      final fixed = q.copyWith(table: q.table!.setCell(0, 1, r'$\frac{3}{4}$'));
      expect(fixed.contentDiffers(q), isTrue);
      expect(fixed.changedFieldsSince(q).keys, ['table']);
      expect(q.copyWith(clearTable: true).toContentFields()['table'], isNull);
      expect(q.copyWith(table: ExamTableDoc.blank()).toContentFields()['table'], isNull);
    });
  });

  group('AUTH-ADM-04 / CP-04: what a CMS save writes', () {
    test('review-relevant fields match the exam_questions rule (plus columns)', () {
      expect(
        ExamQuestionDoc.reviewRelevantFields,
        containsAll(['stem', 'options', 'passage_id', 'image_path', 'language', 'table', 'type']),
      );
      expect(ExamQuestionDoc.reviewRelevantFields, containsAll(['column_a', 'column_b']));
    });

    test('metadata edit by a content manager keeps the status and writes only metadata', () {
      final saved = _approved();
      final edited = saved.copyWith(topicId: 'math.ratios', difficulty: 3, partId: 'math_comparison');
      expect(edited.contentDiffers(saved), isFalse);
      final fields = examQuestionWriteFields(edited, isNew: false, original: saved);
      expect(fields.keys.toSet(), {'topic_id', 'difficulty'});
      expect(fields.keys.any(ExamQuestionDoc.reviewRelevantFields.contains), isFalse);
      // The editor only calls statusAfterContentEdit when content changed.
      expect(saved.review.status, ReviewStatus.methodologistApproved);
    });

    test('content edit by a content manager sends the question back to draft', () {
      final saved = _approved();
      for (final edited in [
        saved.copyWith(stem: 'Новое условие'),
        saved.copyWith(columnA: '1', columnB: '2'),
        saved.copyWith(type: 'single_choice'),
        saved.copyWith(clearTable: true),
      ]) {
        expect(edited.contentDiffers(saved), isTrue, reason: '$edited');
      }
      expect(
        ReviewWorkflow.statusAfterContentEdit(ReviewStatus.methodologistApproved, AdminRole.contentManager),
        ReviewStatus.draft,
      );
      expect(
        ReviewWorkflow.statusAfterContentEdit(ReviewStatus.methodologistApproved, AdminRole.methodologist),
        ReviewStatus.methodologistApproved,
      );
    });

    test('legacy shapes normalised on read are not rewritten by a metadata edit', () {
      final legacy = ExamQuestionDoc.fromMap('q2', {
        'subjectId': 'history',
        'sectionId': 'history',
        'topicId': 'history.medieval',
        'language': 'kg',
        'stem': {'ky': 'Текст'},
        'options': ['a', 'b', 'c', 'd'],
        'image_path': '',
        'review': {'status': 'rejected'},
      });
      final edited = legacy.copyWith(topicId: 'history.modern');
      expect(examQuestionWriteFields(edited, isNew: false, original: legacy).keys, ['topic_id']);
      expect(examQuestionWriteFields(legacy, isNew: false, original: legacy), isEmpty);
    });

    test('a new question writes every content field but no content_hash', () {
      final fields = examQuestionWriteFields(_approved(), isNew: true);
      expect(fields, containsPair('stem', 'Сравните величины А и Б.'));
      expect(fields.containsKey('column_a'), isTrue);
      expect(fields.containsKey('content_hash'), isFalse);
      expect(fields.containsKey('review'), isFalse);
      // JSON-encodable (no nested arrays, nothing Firestore-specific).
      expect(() => jsonEncode(fields), returnsNormally);
    });

    test('key change detection ignores note order', () {
      const a = ExamKeyDoc(correct: 'A', explanation: 'e', wrongOptionNotes: {'B': 'b', 'C': 'c'});
      const b = ExamKeyDoc(correct: 'A', explanation: 'e', wrongOptionNotes: {'C': 'c', 'B': 'b'});
      expect(a.sameAs(b), isTrue);
      expect(a.sameAs(const ExamKeyDoc(correct: 'A', explanation: 'другое')), isFalse);
    });
  });

  group('AUTH-ADM-02 / SEC-MOD-01: moderation', () {
    test('ban and unban write only the moderator fields (D5)', () {
      expect(UsersRepository.moderatorWritableFields,
          {'is_banned', 'ban_reason', 'banned_at', 'banned_by', 'updated_at'});
      final ban = UsersRepository.banUpdate(true, actor: 'mod1', reason: 'спам', now: 'TS');
      expect(ban, {
        'is_banned': true,
        'ban_reason': 'спам',
        'banned_by': 'mod1',
        'banned_at': 'TS',
        'updated_at': 'TS',
      });
      final unban = UsersRepository.banUpdate(false, actor: 'mod1', now: 'TS');
      expect(UsersRepository.moderatorWritableFields.containsAll(unban.keys), isTrue);
      expect(unban['banned_by'], isNull);
      expect(unban.containsKey('isActive'), isFalse);
    });

    test('premium is super_admin only', () {
      expect([for (final r in AdminRole.values) if (r.canSetPremium) r], [AdminRole.superAdmin]);
      expect(AdminRole.moderator.can(AdminPermission.moderateUsers), isTrue);
      expect(AdminRole.moderator.canSetPremium, isFalse);
    });
  });

  group('AUTH-ADM-08: media types', () {
    test('SVG and unknown types are refused before uploading', () {
      expect(() => MediaRepository.validateUpload('diagram.svg', 10),
          throwsA(isA<UnsupportedMediaTypeException>().having((e) => e.extension, 'ext', 'svg')));
      expect(() => MediaRepository.validateUpload('scan.bmp', 10),
          throwsA(isA<UnsupportedMediaTypeException>()));
      expect(() => MediaRepository.validateUpload('noext', 10),
          throwsA(isA<UnsupportedMediaTypeException>()));
      expect(MediaRepository.validateUpload('a.PNG', 10), 'image/png');
      expect(MediaRepository.validateUpload('a.jpeg', 10), 'image/jpeg');
      expect(MediaRepository.validateUpload('doc.pdf', 10), 'application/pdf');
      expect(() => MediaRepository.validateUpload('big.png', MediaRepository.maxImageBytes + 1),
          throwsA(isA<MediaTooLargeException>()));
      expect(kPickableImageExtensions, isNot(contains('svg')));
    });

    test('the error message names the format', () async {
      final l = await AppLocalizations.delegate.load(const Locale('ru'));
      final msg = adminErrorMessage(l, const UnsupportedMediaTypeException('svg'));
      expect(msg, contains('SVG'));
      expect(msg, contains('PNG'));
    });
  });

  group('SEC-APPCHECK-01 / D5: callable errors', () {
    test('classification', () {
      AdminCallableIssue? c(String code, {String? reason, bool appCheck = true}) =>
          classifyAdminCallableError(code: code, reason: reason, appCheckAvailable: appCheck);
      expect(c('unauthenticated', appCheck: false), AdminCallableIssue.appCheckUnavailable);
      expect(c('unauthenticated'), AdminCallableIssue.appCheckRejected);
      expect(c('failed-precondition', appCheck: false), AdminCallableIssue.appCheckUnavailable);
      expect(c('failed-precondition'), isNull);
      expect(c('failed-precondition', reason: 'VALIDATION_FAILED', appCheck: false), isNull);
      expect(c('permission-denied', reason: 'FORBIDDEN_ROLE', appCheck: false), isNull);
      expect(c('permission-denied', reason: kUserBannedReason), AdminCallableIssue.userBanned);
    });

    test('adminErrorMessage shows a platform message instead of "forbidden"', () async {
      final l = await AppLocalizations.delegate.load(const Locale('ru'));
      FirebaseFunctionsException e(String code, [String? reason]) => FirebaseFunctionsException(
          code: code, message: 'x', details: reason == null ? null : {'reason': reason});
      expect(adminErrorMessage(l, e('unauthenticated'), appCheckAvailable: false), l.adminErrAppCheckPlatform);
      expect(adminErrorMessage(l, e('unauthenticated'), appCheckAvailable: true), l.adminErrAppCheckRejected);
      expect(adminErrorMessage(l, e('permission-denied', 'FORBIDDEN_ROLE'), appCheckAvailable: false),
          l.adminErrForbidden);
      expect(adminErrorMessage(l, e('permission-denied', kUserBannedReason)), l.adminErrUserBanned);
    });
  });

  group('widgets', () {
    Future<void> pump(WidgetTester tester, Widget child, List<Override> overrides,
        {Size size = const Size(360, 640)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.blue600),
            extensions: [AppTokens.light],
          ),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ));
      await tester.pumpAndSettle();
    }

    List<Override> session(AdminRole role) => [
          adminSessionProvider.overrideWith(() => _TestSession(role)),
          adminBlueprintsProvider.overrideWith((ref) async => const []),
          variantsPageProvider.overrideWith((ref, f) =>
              PagedListNotifier<VariantDoc>((after) async => const AdminPage<VariantDoc>([], null, false))),
        ];

    testWidgets('AUTH-ADM-05: methodologists get no "new variant" button', (tester) async {
      await pump(tester, const VariantsPage(), session(AdminRole.methodologist));
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('AUTH-ADM-05: content managers can create variants', (tester) async {
      await pump(tester, const VariantsPage(), session(AdminRole.contentManager));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('SEC-APPCHECK-01: the shell explains missing App Check', (tester) async {
      await pump(
        tester,
        const AdminShell(location: '/admin/dashboard', child: SizedBox()),
        [
          ...session(AdminRole.superAdmin),
          adminAppCheckAvailableProvider.overrideWithValue(false),
        ],
        size: const Size(1280, 800),
      );
      expect(find.textContaining('App Check'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SEC-APPCHECK-01: no notice where App Check runs', (tester) async {
      await pump(
        tester,
        const AdminShell(location: '/admin/dashboard', child: SizedBox()),
        [
          ...session(AdminRole.superAdmin),
          adminAppCheckAvailableProvider.overrideWithValue(true),
        ],
        size: const Size(1280, 800),
      );
      expect(find.textContaining('App Check'), findsNothing);
    });

    testWidgets('CP-05: table editor edits cells and rows on a phone', (tester) async {
      ExamTableDoc? last;
      await pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: AdminTableEditor(
              initial: ExamTableDoc.fromAny({
                'headers': ['А', 'Б'],
                'rows': [
                  {
                    'cells': ['1', '2'],
                  },
                ],
              })!,
              onChanged: (t) => last = t,
            ),
          ),
        ),
        const [],
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.widgetWithText(TextFormField, '2'), '3');
      expect(last!.paddedRows.single, ['1', '3']);
      await tester.tap(find.text('Добавить строку'));
      await tester.pumpAndSettle();
      expect(last!.rows, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });
}

class _TestSession extends AdminSessionNotifier {
  _TestSession(this.role);
  final AdminRole role;

  @override
  AdminSession? build() => AdminSession(uid: 'u1', email: 'staff@ort.kg', role: role);
}
