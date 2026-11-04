import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/admin_access_provider.dart';
import '../data/admin_firebase.dart';
import '../data/models/admin_records.dart';
import '../data/models/subject_doc.dart';
import '../data/repositories/content_repositories.dart';
import '../data/repositories/exam_repositories.dart';
import '../data/repositories/people_repositories.dart';
import '../domain/blueprint_spec.dart';
import '../domain/exam_question.dart';
import '../domain/lesson_doc.dart';
import '../domain/practice_question_codec.dart';
import '../domain/pricing_config.dart';
import 'paged_list.dart';

// --- Repositories -----------------------------------------------------------

final subjectsRepoProvider =
    Provider((ref) => SubjectsRepository(ref.watch(adminFirestoreProvider)));
final lessonsRepoProvider =
    Provider((ref) => LessonsRepository(ref.watch(adminFirestoreProvider)));
final practiceRepoProvider =
    Provider((ref) => PracticeQuestionsRepository(ref.watch(adminFirestoreProvider)));
final mediaRepoProvider = Provider((ref) => MediaRepository(ref.watch(adminStorageProvider)));
final examBankRepoProvider =
    Provider((ref) => ExamBankRepository(ref.watch(adminFirestoreProvider)));
final variantsRepoProvider =
    Provider((ref) => VariantsRepository(ref.watch(adminFirestoreProvider)));
final blueprintsRepoProvider =
    Provider((ref) => BlueprintsRepository(ref.watch(adminFirestoreProvider)));
final usersRepoProvider = Provider((ref) => UsersRepository(ref.watch(adminFirestoreProvider)));
final paymentsRepoProvider =
    Provider((ref) => PaymentsRepository(ref.watch(adminFirestoreProvider)));
final adminLogsRepoProvider =
    Provider((ref) => AdminLogsRepository(ref.watch(adminFirestoreProvider)));
final statsRepoProvider = Provider((ref) => StatsRepository(ref.watch(adminFirestoreProvider)));

/// uid of the signed-in admin, written into `*_by` audit fields.
final adminActorProvider =
    Provider<String>((ref) => ref.watch(adminSessionProvider)?.uid ?? 'unknown');

// --- Reference data ---------------------------------------------------------

final adminSubjectsProvider = FutureProvider.autoDispose<List<SubjectDoc>>(
    (ref) => ref.watch(subjectsRepoProvider).list());

final adminBlueprintsProvider =
    FutureProvider<List<BlueprintSpec>>((ref) => ref.watch(blueprintsRepoProvider).list());

final adminStatProvider = FutureProvider.autoDispose.family<int, AdminStat>(
    (ref, stat) => ref.watch(statsRepoProvider).count(stat));

final lessonsBySubjectProvider = FutureProvider.autoDispose.family<List<LessonDoc>, String>(
    (ref, subjectId) => ref.watch(lessonsRepoProvider).bySubject(subjectId));

final pricingProvider =
    FutureProvider.autoDispose<PricingConfig>((ref) => ref.watch(paymentsRepoProvider).pricing());

final passagesProvider = FutureProvider.autoDispose
    .family<List<ExamPassageDoc>, ({String? sectionId, String? language})>(
        (ref, f) => ref.watch(examBankRepoProvider).passages(
              sectionId: f.sectionId,
              language: f.language,
            ));

final translationsProvider = FutureProvider.autoDispose.family<List<ExamQuestionDoc>, String>(
    (ref, groupId) => ref.watch(examBankRepoProvider).translations(groupId));

// --- User detail ------------------------------------------------------------

final adminUserProvider = FutureProvider.autoDispose.family<AdminUserRecord?, String>(
    (ref, uid) => ref.watch(usersRepoProvider).get(uid));
final adminEntitlementProvider = FutureProvider.autoDispose.family<EntitlementInfo, String>(
    (ref, uid) => ref.watch(usersRepoProvider).entitlement(uid));
final adminLedgerProvider = FutureProvider.autoDispose.family<List<LedgerEntry>, String>(
    (ref, uid) => ref.watch(usersRepoProvider).ledger(uid));
final adminUserStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
    (ref, uid) => ref.watch(usersRepoProvider).stats(uid));

// --- Paginated lists (FB-17) -------------------------------------------------

final practicePageProvider = StateNotifierProvider.autoDispose.family<
    PagedListNotifier<PracticeQuestionDraft>, PagedState<PracticeQuestionDraft>, PracticeFilter>(
  (ref, f) {
    final repo = ref.watch(practiceRepoProvider);
    return PagedListNotifier((after) => repo.page(f, after: after));
  },
);

final examBankPageProvider = StateNotifierProvider.autoDispose
    .family<PagedListNotifier<ExamQuestionDoc>, PagedState<ExamQuestionDoc>, ExamBankFilter>(
  (ref, f) {
    final repo = ref.watch(examBankRepoProvider);
    return PagedListNotifier((after) => repo.page(f, after: after));
  },
);

final variantsPageProvider = StateNotifierProvider.autoDispose
    .family<PagedListNotifier<VariantDoc>, PagedState<VariantDoc>, VariantFilter>(
  (ref, f) {
    final repo = ref.watch(variantsRepoProvider);
    return PagedListNotifier((after) => repo.page(f, after: after));
  },
);

final usersPageProvider = StateNotifierProvider.autoDispose
    .family<PagedListNotifier<AdminUserRecord>, PagedState<AdminUserRecord>, String>(
  (ref, prefix) {
    final repo = ref.watch(usersRepoProvider);
    return PagedListNotifier((after) => repo.page(prefix, after: after));
  },
);

final purchasesPageProvider = StateNotifierProvider.autoDispose
    .family<PagedListNotifier<PurchaseRecord>, PagedState<PurchaseRecord>, String?>(
  (ref, state) {
    final repo = ref.watch(paymentsRepoProvider);
    return PagedListNotifier((after) => repo.page(state, after: after));
  },
);

final adminLogsPageProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<AdminLogRecord>, PagedState<AdminLogRecord>>(
  (ref) {
    final repo = ref.watch(adminLogsRepoProvider);
    return PagedListNotifier((after) => repo.page(after: after));
  },
);
