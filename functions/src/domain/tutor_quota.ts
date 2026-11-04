/**
 * AI tutor input validation, daily quota and cost accounting (ARCHITECTURE
 * §6). The quota counter lives in ai_usage/{uid}/days/{yyyy-mm-dd} (Bishkek
 * day) and is reserved inside a transaction before the model is called.
 */
import { validationError } from './reasons';
import { bool, int, isRecord, num, str } from './types';

export const TUTOR_MODES = ['explain_mistake', 'step_by_step', 'grammar', 'practice', 'study_plan', 'chat'] as const;
export type TutorMode = (typeof TUTOR_MODES)[number];
export type TutorLanguage = 'ru' | 'ky';

export const DEFAULT_DAILY_LIMIT = 15;
export const DEFAULT_MAX_TOKENS = 1200;
export const MAX_MESSAGE_CHARS = 2000;
export const MAX_HISTORY_ITEMS = 10;
export const MAX_HISTORY_ITEM_CHARS = 4000;
export const MAX_HISTORY_TOTAL_CHARS = 16000;

export interface TutorConfig {
  enabled: boolean;
  daily_limit: number;
  max_tokens: number;
}

/** config/ai_tutor with defaults and clamping. */
export function parseTutorConfig(raw: unknown): TutorConfig {
  const r = isRecord(raw) ? raw : {};
  return {
    enabled: bool(r['enabled'], true),
    daily_limit: Math.max(0, Math.min(500, int(r['daily_limit'], DEFAULT_DAILY_LIMIT))),
    max_tokens: Math.max(300, Math.min(4000, int(r['max_tokens'], DEFAULT_MAX_TOKENS))),
  };
}

export interface QuotaDecision {
  allowed: boolean;
  /** Requests left today after this one (when allowed), else 0. */
  remainingAfter: number;
}

export function decideQuota(usedToday: number, dailyLimit: number): QuotaDecision {
  const used = Math.max(0, Math.trunc(usedToday));
  if (used >= dailyLimit) return { allowed: false, remainingAfter: 0 };
  return { allowed: true, remainingAfter: dailyLimit - used - 1 };
}

export interface HistoryTurn {
  role: 'user' | 'assistant';
  text: string;
}

export interface TutorInput {
  mode: TutorMode;
  message: string;
  language: TutorLanguage;
  questionId: string | null;
  attemptId: string | null;
  history: HistoryTurn[];
}

const ID_RE = /^[A-Za-z0-9_-]{1,128}$/;

function optionalId(v: unknown, field: string): string | null {
  if (v === undefined || v === null || v === '') return null;
  if (typeof v !== 'string' || !ID_RE.test(v)) throw validationError(`${field} is invalid`);
  return v;
}

/**
 * Validates the aiTutor payload. History is trimmed to the last
 * MAX_HISTORY_ITEMS turns, must start with a user turn, and is capped in size.
 */
export function sanitizeTutorInput(raw: unknown): TutorInput {
  if (!isRecord(raw)) throw validationError('payload must be an object');
  const mode = str(raw['mode'], 'chat');
  if (!(TUTOR_MODES as readonly string[]).includes(mode)) throw validationError('unknown mode');
  const message = str(raw['message']).trim();
  if (message.length === 0) throw validationError('message is empty');
  if (message.length > MAX_MESSAGE_CHARS) throw validationError(`message longer than ${MAX_MESSAGE_CHARS} chars`);
  const lang = str(raw['language'], 'ru');
  const language: TutorLanguage = lang === 'ky' ? 'ky' : 'ru';

  const history: HistoryTurn[] = [];
  if (Array.isArray(raw['history'])) {
    for (const item of raw['history'].slice(-MAX_HISTORY_ITEMS)) {
      if (!isRecord(item)) continue;
      const role = item['role'] === 'assistant' ? 'assistant' : item['role'] === 'user' ? 'user' : null;
      const text = str(item['text'] ?? item['content']).trim().slice(0, MAX_HISTORY_ITEM_CHARS);
      if (role && text) history.push({ role, text });
    }
  }
  while (history.length > 0 && history[0]!.role !== 'user') history.shift();
  let total = history.reduce((n, h) => n + h.text.length, 0);
  while (history.length > 0 && total > MAX_HISTORY_TOTAL_CHARS) {
    total -= history.shift()!.text.length;
    while (history.length > 0 && history[0]!.role !== 'user') total -= history.shift()!.text.length;
  }

  return {
    mode: mode as TutorMode,
    message,
    language,
    questionId: optionalId(raw['questionId'], 'questionId'),
    attemptId: optionalId(raw['attemptId'], 'attemptId'),
    history,
  };
}

/** USD per million tokens. Unknown models are priced like Opus (conservative). */
const PRICES: Record<string, { input: number; output: number; cacheWrite: number; cacheRead: number }> = {
  'claude-opus-5-5': { input: 4, output: 20, cacheWrite: 5, cacheRead: 0.2 },
  'claude-sonnet-5-5': { input: 2, output: 10, cacheWrite: 2.5, cacheRead: 0.2 },
  'claude-haiku-5-5': { input: 0.1, output: 0.5, cacheWrite: 0.125, cacheRead: 0.01 },
};

export interface UsageNumbers {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens: number;
  cache_read_input_tokens: number;
}

export function normalizeUsage(raw: unknown): UsageNumbers {
  const r = isRecord(raw) ? raw : {};
  return {
    input_tokens: Math.max(0, int(r['input_tokens'])),
    output_tokens: Math.max(0, int(r['output_tokens'])),
    cache_creation_input_tokens: Math.max(0, int(r['cache_creation_input_tokens'])),
    cache_read_input_tokens: Math.max(0, int(r['cache_read_input_tokens'])),
  };
}

/** Approximate cost; informational only (billing truth is the Anthropic console). */
export function estimateCostUsd(model: string, usage: UsageNumbers): number {
  const p = PRICES[model] ?? PRICES['claude-opus-5-5']!;
  const usd =
    (usage.input_tokens * p.input +
      usage.output_tokens * p.output +
      usage.cache_creation_input_tokens * p.cacheWrite +
      usage.cache_read_input_tokens * p.cacheRead) /
    1_000_000;
  return Math.round(num(usd) * 1e6) / 1e6;
}
