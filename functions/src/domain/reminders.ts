/**
 * Daily study reminder rules (decision D12). Pure; the scheduled function
 * sendStudyReminders (handlers/reminders.ts) applies them.
 *
 * Field names are the ones the Flutter client writes
 * (lib/features/settings/data/reminder_settings.dart): users/{uid}
 * `daily_reminder_enabled` (bool), `fcm_tokens` (array of FCM tokens),
 * `reminder_timezone` ('Asia/Bishkek'), plus the profile's
 * `preferred_language`; activity comes from user_stats/{uid}.last_active_day.
 */
import { BISHKEK_OFFSET_MS, bishkekDayKey } from './time';
import { isRecord } from './types';

/** Local Bishkek hours in [QUIET_FROM, 24) and [0, QUIET_UNTIL) never get reminders. */
export const QUIET_FROM_HOUR = 22;
export const QUIET_UNTIL_HOUR = 8;
/** At most this many device tokens are messaged per user. */
export const MAX_TOKENS_PER_USER = 10;

export type ReminderLanguage = 'ru' | 'ky';

/** Hour of day (0-23) in Asia/Bishkek (fixed UTC+6, no DST). */
export function bishkekHour(nowMs: number): number {
  return new Date(nowMs + BISHKEK_OFFSET_MS).getUTCHours();
}

/** True between 22:00 and 08:00 Bishkek time: no reminders are sent. */
export function isQuietHours(nowMs: number): boolean {
  const h = bishkekHour(nowMs);
  return h >= QUIET_FROM_HOUR || h < QUIET_UNTIL_HOUR;
}

export function reminderLanguage(preferred: unknown): ReminderLanguage {
  return typeof preferred === 'string' && preferred.trim().toLowerCase().startsWith('ky') ? 'ky' : 'ru';
}

const TEXT: Record<ReminderLanguage, { title: string; body: string }> = {
  ru: {
    title: 'Время позаниматься',
    body: 'Сегодня вы ещё не занимались. 10 минут практики помогут не прервать серию!',
  },
  ky: {
    title: 'Окууга убакыт келди',
    body: 'Бүгүн сиз али машыга элексиз. 10 мүнөт машыгуу күн катарыңызды үзбөөгө жардам берет!',
  },
};

export function reminderText(lang: ReminderLanguage): { title: string; body: string } {
  return TEXT[lang];
}

/** Unique, non-empty string tokens from users/{uid}.fcm_tokens (capped). */
export function reminderTokens(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const t of raw) {
    if (typeof t === 'string' && t.length > 0 && t.length <= 4096 && !out.includes(t)) out.push(t);
  }
  return out.slice(-MAX_TOKENS_PER_USER);
}

export interface ReminderTarget {
  tokens: string[];
  language: ReminderLanguage;
}

/**
 * Who gets today's reminder: daily_reminder_enabled == true, at least one
 * FCM token, not banned, and user_stats.last_active_day != today (Bishkek).
 * Returns null when the user must not be messaged.
 */
export function reminderTarget(profile: unknown, stats: unknown, nowMs: number): ReminderTarget | null {
  if (!isRecord(profile) || profile['daily_reminder_enabled'] !== true) return null;
  if (profile['is_banned'] === true) return null;
  const tokens = reminderTokens(profile['fcm_tokens']);
  if (tokens.length === 0) return null;
  const lastActive = isRecord(stats) ? stats['last_active_day'] : null;
  if (lastActive === bishkekDayKey(nowMs)) return null;
  return { tokens, language: reminderLanguage(profile['preferred_language']) };
}

/** FCM error codes meaning the token is dead and must be removed from fcm_tokens. */
const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
  'messaging/mismatched-credential',
]);

export function isInvalidTokenError(code: unknown): boolean {
  return typeof code === 'string' && INVALID_TOKEN_CODES.has(code);
}
