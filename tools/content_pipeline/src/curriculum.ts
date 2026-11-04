/** Loader for content/curriculum/topics.json (subjects → topics → subtopics with slot weights). */
import { z } from 'zod';
import { Language } from './schema';
import { readJson } from './io';

const Title = z.strictObject({ ru: z.string().min(1), ky: z.string().min(1), en: z.string().min(1) });
const Grades = z.tuple([z.number().int().min(1).max(11), z.number().int().min(1).max(11)]).refine((g) => g[0] <= g[1], { message: 'grades must be [from, to]' });

export const Subtopic = z.strictObject({ id: z.string(), grades: Grades, title: Title });
export const Topic = z.strictObject({
  id: z.string().regex(/^[a-z0-9_]+\.[a-z0-9_]+$/, 'topic id is <prefix>.<name>'),
  grades: Grades,
  title: Title,
  /** Restricts the topic to item languages (grammar_ru → ru). Absent = every language of the blueprint. */
  languages: z.array(Language).optional(),
  /** Slot key `blueprint/section/part` → items of this topic in one variant. */
  slots: z.record(z.string(), z.number().int().min(0)),
  subtopics: z.array(Subtopic),
});
export type Topic = z.infer<typeof Topic>;

export const PassagePlan = z.strictObject({
  standalone_texts: z.number().int().min(0),
  paired_texts: z.number().int().min(0),
  questions_per_text: z.number().int().min(1),
  /** Topics asked about the texts in a mixed part (e.g. 15 standalone + 5 on a text); absent = every topic of the part. */
  passage_topics: z.array(z.string()).optional(),
  words: z.tuple([z.number().int().min(50), z.number().int().min(50)]).optional(),
});
export type PassagePlan = z.infer<typeof PassagePlan>;

export const Curriculum = z
  .strictObject({
    schema_version: z.literal(1),
    note: z.string(),
    programme: z.string(),
    slot_settings: z.record(z.string(), z.strictObject({ passage_plan: PassagePlan.optional() })),
    subjects: z.array(z.strictObject({ id: z.string(), title: Title, topics: z.array(Topic) })),
  })
  .superRefine((c, ctx) => {
    const seen = new Set<string>();
    for (const s of c.subjects) {
      for (const t of s.topics) {
        if (seen.has(t.id)) ctx.addIssue({ code: 'custom', message: `duplicate topic ${t.id}` });
        seen.add(t.id);
        for (const st of t.subtopics) {
          if (!st.id.startsWith(`${t.id}.`)) ctx.addIssue({ code: 'custom', message: `subtopic ${st.id} must start with ${t.id}.` });
          if (seen.has(st.id)) ctx.addIssue({ code: 'custom', message: `duplicate subtopic ${st.id}` });
          seen.add(st.id);
        }
      }
    }
  });
export type Curriculum = z.infer<typeof Curriculum>;

export function loadCurriculum(path: string): Curriculum {
  return Curriculum.parse(readJson(path));
}

export interface TopicInSlot {
  topic: Topic;
  subjectId: string;
  weight: number;
}

/** Topics that feed a slot for one item language, in catalog order. */
export function topicsForSlot(c: Curriculum, slot: string, language: string): TopicInSlot[] {
  const out: TopicInSlot[] = [];
  for (const s of c.subjects) {
    for (const t of s.topics) {
      const w = t.slots[slot];
      if (w === undefined || w <= 0) continue;
      if (t.languages && !t.languages.includes(language as Language)) continue;
      out.push({ topic: t, subjectId: s.id, weight: w });
    }
  }
  return out;
}

export function findTopic(c: Curriculum, topicId: string): Topic | undefined {
  for (const s of c.subjects) for (const t of s.topics) if (t.id === topicId) return t;
  return undefined;
}

export function allTopicIds(c: Curriculum): Set<string> {
  const ids = new Set<string>();
  for (const s of c.subjects) for (const t of s.topics) {
    ids.add(t.id);
    for (const st of t.subtopics) ids.add(st.id);
  }
  return ids;
}
