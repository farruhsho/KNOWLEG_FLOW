import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  isInvalidTokenError,
  isQuietHours,
  MAX_TOKENS_PER_USER,
  reminderLanguage,
  reminderTarget,
  reminderText,
  reminderTokens,
} from '../src/domain/reminders';
import { bishkek } from './fixtures';

describe('sendStudyReminders rules (D12)', () => {
  const at18 = bishkek(2026, 11, 4, 18, 0, 5);
  const profile = { daily_reminder_enabled: true, fcm_tokens: ['tok1', 'tok2'], preferred_language: 'ky', reminder_timezone: 'Asia/Bishkek' };

  it('quiet hours are 22:00-08:00 Bishkek time; 18:00 is not quiet', () => {
    assert.equal(isQuietHours(at18), false);
    assert.equal(isQuietHours(bishkek(2026, 11, 4, 21, 59)), false);
    assert.equal(isQuietHours(bishkek(2026, 11, 4, 22, 0)), true);
    assert.equal(isQuietHours(bishkek(2026, 11, 5, 3, 0)), true);
    assert.equal(isQuietHours(bishkek(2026, 11, 5, 7, 59)), true);
    assert.equal(isQuietHours(bishkek(2026, 11, 5, 8, 0)), false);
  });

  it('targets enabled users with tokens who were not active today', () => {
    assert.deepEqual(reminderTarget(profile, { last_active_day: '2026-11-03' }, at18), { tokens: ['tok1', 'tok2'], language: 'ky' });
    assert.deepEqual(reminderTarget(profile, undefined, at18), { tokens: ['tok1', 'tok2'], language: 'ky' });
  });

  it('skips users active today, disabled, banned or without tokens', () => {
    assert.equal(reminderTarget(profile, { last_active_day: '2026-11-04' }, at18), null);
    assert.equal(reminderTarget({ ...profile, daily_reminder_enabled: false }, {}, at18), null);
    assert.equal(reminderTarget({ ...profile, fcm_tokens: [] }, {}, at18), null);
    assert.equal(reminderTarget({ ...profile, fcm_tokens: undefined }, {}, at18), null);
    assert.equal(reminderTarget({ ...profile, is_banned: true }, {}, at18), null);
  });

  it('localizes ru/ky (default ru)', () => {
    assert.equal(reminderLanguage('ky'), 'ky');
    assert.equal(reminderLanguage('ky_KG'), 'ky');
    assert.equal(reminderLanguage('ru'), 'ru');
    assert.equal(reminderLanguage('en'), 'ru');
    assert.equal(reminderLanguage(undefined), 'ru');
    assert.match(reminderText('ky').body, /[ңөү]/);
    assert.match(reminderText('ru').title, /[а-я]/);
  });

  it('dedupes and caps tokens; recognizes dead-token errors for pruning', () => {
    const many = Array.from({ length: 15 }, (_, i) => `t${i}`);
    assert.equal(reminderTokens([...many, 't1', '', 5]).length, MAX_TOKENS_PER_USER);
    assert.deepEqual(reminderTokens(['a', 'a', 'b']), ['a', 'b']);
    assert.equal(isInvalidTokenError('messaging/registration-token-not-registered'), true);
    assert.equal(isInvalidTokenError('messaging/invalid-registration-token'), true);
    assert.equal(isInvalidTokenError('messaging/internal-error'), false);
    assert.equal(isInvalidTokenError(undefined), false);
  });
});
