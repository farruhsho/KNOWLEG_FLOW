/**
 * Data contracts of the content pipeline.
 *
 * The Firestore document shapes (ExamQuestion, ExamQuestionKey, ExamPassage,
 * ExamVariant) mirror docs/modernization/ARCHITECTURE.md §1.2–1.3 field for
 * field (snake_case). Timestamps are ISO-8601 strings in the files under
 * content/ and become Firestore Timestamps only in the import stage.
 *
 * The "bank" wrappers (BankItem, BankPassage, BankFile, VariantFile) are
 * pipeline-only: they carry the target blueprint slot and the audit trail of
 * every stage. Nothing outside `question` / `key` / `passage` / `variant` is
 * ever written to Firestore.
 */
import { z } from 'zod';

export const LANGUAGES = ['ru', 'ky', 'en'] as const;
export const Language = z.enum(LANGUAGES);
export type Language = z.infer<typeof Language>;

export const ITEM_TYPES = [
  'single_choice',
  'quantitative_comparison',
  'analogy',
  'completion',
  'text_based',
] as const;
export const ItemType = z.enum(ITEM_TYPES);
export type ItemType = z.infer<typeof ItemType>;

export const REVIEW_STATUSES = ['draft', 'ai_verified', 'methodologist_approved', 'rejected'] as const;
export const ReviewStatus = z.enum(REVIEW_STATUSES);
export type ReviewStatus = z.infer<typeof ReviewStatus>;

/** Ordering used when a stage must not downgrade a status. `rejected` is outside the chain. */
export const REVIEW_RANK: Record<ReviewStatus, number> = {
  rejected: -1,
  draft: 0,
  ai_verified: 1,
  methodologist_approved: 2,
};

export const VARIANT_STATUSES = ['draft', 'in_review', 'published', 'archived'] as const;
export const VariantStatus = z.enum(VARIANT_STATUSES);
export type VariantStatus = z.infer<typeof VariantStatus>;

export const OPTION_IDS = ['A', 'B', 'C', 'D', 'E'] as const;
export const OptionId = z.enum(OPTION_IDS);
export type OptionId = z.infer<typeof OptionId>;

export const Difficulty = z.union([z.literal(1), z.literal(2), z.literal(3)]);
export type Difficulty = z.infer<typeof Difficulty>;
export const DIFFICULTIES: readonly Difficulty[] = [1, 2, 3];

export const IsoTimestamp = z.iso.datetime({ offset: true });
const NonEmpty = z.string().trim().min(1);
const Slug = z.string().regex(/^[a-z0-9][a-z0-9_.-]*$/, 'lowercase slug expected');

export const ContentHash = z.string().regex(/^sha256:[0-9a-f]{64}$/, 'expected sha256:<64 hex>');
export const QuestionId = z.string().regex(/^q_[0-9a-f]{20}$/, 'expected q_<20 hex> (content_hash based)');
export const PassageId = z.string().regex(/^p_[0-9a-f]{20}$/, 'expected p_<20 hex> (content_hash based)');

export const QuestionOption = z.strictObject({ id: OptionId, text: NonEmpty });
export type QuestionOption = z.infer<typeof QuestionOption>;

export const QuestionTable = z
  .strictObject({
    headers: z.array(z.string()).min(1),
    rows: z.array(z.array(z.string())).min(1),
  })
  .refine((t) => t.rows.every((r) => r.length === t.headers.length), {
    message: 'every table row must have as many cells as headers',
  });
export type QuestionTable = z.infer<typeof QuestionTable>;

export const ContentSource = z.strictObject({
  /** Only original or licensed material may enter the bank (CONTENT_PIPELINE.md, legal rules). */
  kind: z.enum(['original', 'licensed']),
  basis: NonEmpty,
  author: NonEmpty,
});
export type ContentSource = z.infer<typeof ContentSource>;

export const Review = z.strictObject({
  status: ReviewStatus,
  reviewed_by: z.string().nullable(),
  reviewed_at: IsoTimestamp.nullable(),
  notes: z.string(),
});
export type Review = z.infer<typeof Review>;

/** `exam_questions/{questionId}` — ARCHITECTURE §1.3. One document = one language. */
export const ExamQuestion = z
  .strictObject({
    subject_id: Slug,
    section_id: Slug,
    topic_id: Slug,
    subtopic_id: Slug.nullable(),
    difficulty: Difficulty,
    language: Language,
    translation_group_id: z.string().regex(/^tg_[0-9a-z_]+$/).nullable(),
    type: ItemType,
    stem: NonEmpty,
    options: z.array(QuestionOption).min(2).max(5),
    passage_id: PassageId.nullable(),
    image_path: z.string().regex(/^exam_media\/[^/]+\/.+/, 'image_path must be exam_media/{questionId}/{file}').nullable(),
    table: QuestionTable.nullable(),
    source: ContentSource,
    review: Review,
    content_version: z.number().int().min(1),
    content_hash: ContentHash,
    created_at: IsoTimestamp,
    updated_at: IsoTimestamp,
  })
  .superRefine((q, ctx) => {
    q.options.forEach((o, i) => {
      if (o.id !== OPTION_IDS[i]) {
        ctx.addIssue({ code: 'custom', path: ['options', i, 'id'], message: `option ids must be sequential A..; got ${o.id} at position ${i}` });
      }
    });
    const texts = q.options.map((o) => o.text.trim().toLowerCase());
    if (new Set(texts).size !== texts.length) {
      ctx.addIssue({ code: 'custom', path: ['options'], message: 'option texts must be unique' });
    }
    if (q.type === 'text_based' && q.passage_id === null) {
      ctx.addIssue({ code: 'custom', path: ['passage_id'], message: 'text_based items need a passage_id' });
    }
    if (q.type === 'quantitative_comparison' && q.table === null) {
      ctx.addIssue({ code: 'custom', path: ['table'], message: 'quantitative_comparison items carry columns A/Б in `table`' });
    }
  });
export type ExamQuestion = z.infer<typeof ExamQuestion>;

/** `exam_question_keys/{questionId}` — never readable by clients. */
export const ExamQuestionKey = z.strictObject({
  correct: OptionId,
  explanation: NonEmpty,
  wrong_option_notes: z.partialRecord(OptionId, z.string()),
  solution_steps: z.array(NonEmpty),
});
export type ExamQuestionKey = z.infer<typeof ExamQuestionKey>;

/** `exam_passages/{passageId}`. */
export const ExamPassage = z.strictObject({
  language: Language,
  subject_id: Slug,
  section_id: Slug,
  title: z.string(),
  text: NonEmpty,
  source: ContentSource,
});
export type ExamPassage = z.infer<typeof ExamPassage>;

export const LocalizedTitle = z
  .strictObject({ ru: z.string().optional(), ky: z.string().optional(), en: z.string().optional() })
  .refine((t) => Object.values(t).some((v) => typeof v === 'string' && v.length > 0), { message: 'title needs at least one language' });

/** `exam_variants/{variantId}` — ARCHITECTURE §1.2. */
export const ExamVariant = z.strictObject({
  blueprint_id: Slug,
  blueprint_version: z.number().int().min(1),
  number: z.number().int().min(1),
  title: LocalizedTitle,
  language: Language,
  status: VariantStatus,
  sections: z.array(z.strictObject({ section_id: Slug, question_ids: z.array(z.string().min(1)).min(1) })).min(1),
  content_version: z.number().int().min(1),
  difficulty_label: z.enum(['standard', 'advanced']),
  created_by: NonEmpty,
  published_at: IsoTimestamp.nullable(),
  published_by: z.string().nullable(),
  stats: z.strictObject({ attempts: z.number().int().min(0), avg_percent: z.number().min(0).max(100) }),
});
export type ExamVariant = z.infer<typeof ExamVariant>;

// ---------------------------------------------------------------------------
// Pipeline-only wrappers
// ---------------------------------------------------------------------------

export const Slot = z.strictObject({ blueprint_id: Slug, section_id: Slug, part_id: Slug });
export type Slot = z.infer<typeof Slot>;
export const slotKey = (s: Slot): string => `${s.blueprint_id}/${s.section_id}/${s.part_id}`;

export const ISSUE_KINDS = [
  'ambiguity',
  'multiple_correct',
  'no_correct',
  'factual_error',
  'language_quality',
  'off_programme',
  'copyright_risk',
  'other',
] as const;
export const IssueKind = z.enum(ISSUE_KINDS);
export const IssueSeverity = z.enum(['blocker', 'major', 'minor']);
export const Issue = z.strictObject({ kind: IssueKind, severity: IssueSeverity, note: z.string() });
export type Issue = z.infer<typeof Issue>;

export const Usage = z.strictObject({
  input_tokens: z.number().int().min(0),
  output_tokens: z.number().int().min(0),
  cost_usd: z.number().min(0),
});
export type Usage = z.infer<typeof Usage>;

export const VerifyRecord = z.strictObject({
  content_hash: ContentHash,
  model: z.string(),
  at: IsoTimestamp,
  blind_answer: z.union([OptionId, z.literal('NONE'), z.literal('MULTIPLE')]).nullable(),
  correct_options: z.array(OptionId),
  agrees: z.boolean(),
  confidence: z.enum(['low', 'medium', 'high']),
  issues: z.array(Issue),
  language_quality: z.enum(['ok', 'minor_issues', 'poor']),
  arithmetic: z.strictObject({ checked: z.boolean(), ok: z.boolean().nullable(), detail: z.string() }),
  verdict: z.enum(['ai_verified', 'rejected', 'unchanged']),
  usage: Usage.nullable(),
});
export type VerifyRecord = z.infer<typeof VerifyRecord>;

export const TranslateCheckRecord = z.strictObject({
  at: IsoTimestamp,
  counterpart_ids: z.array(QuestionId),
  structural_ok: z.boolean(),
  structural_problems: z.array(z.string()),
  api: z
    .strictObject({
      model: z.string(),
      equivalent: z.boolean(),
      target_language_quality: z.enum(['ok', 'minor_issues', 'poor']),
      issues: z.array(z.strictObject({ field: z.string(), severity: IssueSeverity, note: z.string() })),
      usage: Usage.nullable(),
    })
    .nullable(),
  status: z.enum(['passed', 'failed']),
});
export type TranslateCheckRecord = z.infer<typeof TranslateCheckRecord>;

export const DedupRecord = z.strictObject({
  at: IsoTimestamp,
  cluster_id: z.string(),
  duplicate_of: QuestionId.nullable(),
  max_similarity: z.number().min(0).max(1),
});
export type DedupRecord = z.infer<typeof DedupRecord>;

export const PipelineMeta = z.looseObject({
  batch_id: NonEmpty,
  /** `hand:<who>` for hand-written items, `model:<model id>` for generated ones. */
  generated_by: NonEmpty,
  prompt_version: z.string().nullable(),
  verify: VerifyRecord.optional(),
  translate_check: TranslateCheckRecord.optional(),
  dedup: DedupRecord.optional(),
});
export type PipelineMeta = z.infer<typeof PipelineMeta>;

export const BankItem = z.strictObject({
  id: QuestionId,
  target: Slot,
  question: ExamQuestion,
  key: ExamQuestionKey,
  /** Order of the item inside its passage group (1-based), null for standalone items. */
  passage_order: z.number().int().min(1).nullable(),
  pipeline: PipelineMeta,
});
export type BankItem = z.infer<typeof BankItem>;

export const BankPassage = z.strictObject({
  id: PassageId,
  layout: z.enum(['standalone', 'paired']),
  translation_group_id: z.string().regex(/^tg_[0-9a-z_]+$/).nullable(),
  content_hash: ContentHash,
  passage: ExamPassage,
});
export type BankPassage = z.infer<typeof BankPassage>;

export const BankFile = z.strictObject({
  schema_version: z.literal(1),
  batch: z.strictObject({
    id: NonEmpty,
    kind: z.enum(['sample', 'generated', 'translated', 'imported']),
    created_at: IsoTimestamp,
    note: z.string(),
  }),
  passages: z.array(BankPassage),
  items: z.array(BankItem),
});
export type BankFile = z.infer<typeof BankFile>;

export const VariantFile = z.strictObject({
  id: z.string().regex(/^v_[a-z0-9_]+$/),
  variant: ExamVariant,
  assembly: z.looseObject({
    assembled_at: IsoTimestamp,
    seed: z.string(),
    allow_unapproved: z.boolean(),
    allow_reuse: z.boolean(),
  }),
});
export type VariantFile = z.infer<typeof VariantFile>;

/** Formats zod issues as `path: message` lines. */
export function formatIssues(error: z.ZodError): string[] {
  return error.issues.map((i) => `${i.path.length ? i.path.join('.') : '(root)'}: ${i.message}`);
}

/** JSON Schemas exported to content/schema/ for reviewers and other tools. */
export function exportJsonSchemas(): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  const entries: Array<[string, z.ZodType]> = [
    ['exam_question', ExamQuestion],
    ['exam_question_key', ExamQuestionKey],
    ['exam_passage', ExamPassage],
    ['exam_variant', ExamVariant],
    ['bank_file', BankFile],
    ['variant_file', VariantFile],
  ];
  for (const [name, schema] of entries) {
    out[name] = z.toJSONSchema(schema, { io: 'input', unrepresentable: 'any' });
  }
  return out;
}
