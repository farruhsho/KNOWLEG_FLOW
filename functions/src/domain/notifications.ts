/**
 * Admin broadcasts (ARCHITECTURE §9.4, adminSendNotification). Pure: input
 * validation, audience filter, language choice and FCM batching.
 *
 * Recipients are users with at least one FCM token (`users/{uid}.fcm_tokens`)
 * who are not banned; each gets the text in their `preferred_language`
 * (`ky*` -> ky, anything else -> ru). Tokens go out in multicast batches of
 * at most FCM_BATCH_SIZE, per language.
 */
import { reminderLanguage, reminderTokens, type ReminderLanguage } from './reminders';
import { regionIdFromProfile, resolveRegionId, type RegionIndex } from './regions';
import { leagueGroupIds } from './leaderboard';
import { validationError } from './reasons';
import { isRecord } from './types';

export const FCM_BATCH_SIZE = 500;
export const BROADCASTS_PER_DAY = 3;
export const TITLE_MAX = 100;
export const BODY_MAX = 1000;

export type AudienceKind = 'all' | 'language' | 'region' | 'group';

export interface Audience {
  kind: AudienceKind;
  /** language: 'ru' | 'ky'; region: kg_regions.json id; group: group id; all: null. */
  value: string | null;
}

export interface LocalizedPair {
  ru: string;
  ky: string;
}

export interface BroadcastInput {
  title: LocalizedPair;
  body: LocalizedPair;
  audience: Audience;
  dryRun: boolean;
}

const GROUP_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

/**
 * `{ru, ky}` with at least one non-empty value; a missing language falls
 * back to the other one so every recipient gets text.
 */
export function parsePair(raw: unknown, field: string, maxLen: number): LocalizedPair {
  if (!isRecord(raw)) throw validationError(`${field} must be {ru, ky}`, { field });
  const pick = (lang: 'ru' | 'ky'): string => {
    const v = raw[lang];
    if (v === undefined || v === null) return '';
    if (typeof v !== 'string' || v.length > maxLen) throw validationError(`${field}.${lang} must be a string of at most ${maxLen} characters`, { field });
    return v.trim();
  };
  const ru = pick('ru');
  const ky = pick('ky');
  if (!ru && !ky) throw validationError(`${field} must not be empty`, { field });
  return { ru: ru || ky, ky: ky || ru };
}

export function parseAudience(raw: unknown, regions: RegionIndex): Audience {
  if (!isRecord(raw)) throw validationError('audience must be {kind, value?}', { field: 'audience' });
  const kind = raw['kind'];
  const value = raw['value'];
  switch (kind) {
    case 'all':
      return { kind, value: null };
    case 'language':
      if (value !== 'ru' && value !== 'ky') throw validationError('audience.value must be ru or ky', { field: 'audience' });
      return { kind, value };
    case 'region': {
      const id = resolveRegionId(value, regions);
      if (!id) throw validationError('audience.value must be a region id from kg_regions.json', { field: 'audience' });
      return { kind, value: id };
    }
    case 'group':
      if (typeof value !== 'string' || !GROUP_ID_RE.test(value)) throw validationError('audience.value must be a group id', { field: 'audience' });
      return { kind, value };
    default:
      throw validationError('audience.kind must be all, language, region or group', { field: 'audience' });
  }
}

export function parseBroadcast(data: Record<string, unknown>, regions: RegionIndex): BroadcastInput {
  const dryRun = data['dryRun'];
  if (dryRun !== undefined && dryRun !== null && typeof dryRun !== 'boolean') throw validationError('dryRun must be a boolean', { field: 'dryRun' });
  return {
    title: parsePair(data['title'], 'title', TITLE_MAX),
    body: parsePair(data['body'], 'body', BODY_MAX),
    audience: parseAudience(data['audience'], regions),
    dryRun: dryRun === true,
  };
}

export interface Recipient {
  uid: string;
  tokens: string[];
  language: ReminderLanguage;
}

/**
 * The profile as a recipient when it matches the audience, has tokens and
 * is not banned. For `group` audiences the caller already restricted the
 * profiles to the group's members; group_ids is checked as well so a stale
 * member document never widens the audience.
 */
export function recipientFor(uid: string, profile: unknown, audience: Audience, regions: RegionIndex): Recipient | null {
  if (!isRecord(profile) || profile['is_banned'] === true) return null;
  const tokens = reminderTokens(profile['fcm_tokens']);
  if (tokens.length === 0) return null;
  const language = reminderLanguage(profile['preferred_language']);
  switch (audience.kind) {
    case 'language':
      if (language !== audience.value) return null;
      break;
    case 'region':
      if (regionIdFromProfile(profile, regions) !== audience.value) return null;
      break;
    case 'group':
      if (!leagueGroupIds(profile['group_ids']).includes(audience.value ?? '')) return null;
      break;
    case 'all':
      break;
  }
  return { uid, tokens, language };
}

export interface TokenBatch {
  language: ReminderLanguage;
  tokens: string[];
  /** owner uid per token (same order) for pruning invalid tokens. */
  owners: string[];
}

/** Groups recipients' tokens by language into batches of ≤ size tokens. */
export function tokenBatches(recipients: readonly Recipient[], size = FCM_BATCH_SIZE): TokenBatch[] {
  const out: TokenBatch[] = [];
  for (const lang of ['ru', 'ky'] as const) {
    let current: TokenBatch | null = null;
    for (const r of recipients) {
      if (r.language !== lang) continue;
      for (const t of r.tokens) {
        if (!current || current.tokens.length >= size) {
          current = { language: lang, tokens: [], owners: [] };
          out.push(current);
        }
        current.tokens.push(t);
        current.owners.push(r.uid);
      }
    }
  }
  return out;
}

/** True when another broadcast may be sent today (`sentToday` real sends so far). */
export function canBroadcast(sentToday: number): boolean {
  return sentToday < BROADCASTS_PER_DAY;
}
