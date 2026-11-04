import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import {
  BROADCASTS_PER_DAY,
  canBroadcast,
  parseAudience,
  parseBroadcast,
  parsePair,
  recipientFor,
  tokenBatches,
  type Recipient,
} from '../src/domain/notifications';
import { DomainError } from '../src/domain/reasons';
import { buildRegionIndex, regionIdFromProfile, resolveRegionId } from '../src/domain/regions';

const regions = buildRegionIndex(JSON.parse(readFileSync(path.resolve(__dirname, '..', '..', 'assets', 'data', 'kg_regions.json'), 'utf8')));

function isValidation(e: unknown): boolean {
  return e instanceof DomainError && e.reason === 'VALIDATION_FAILED';
}

describe('regions (kg_regions.json)', () => {
  it('indexes the 9 regions by id, canonical oblast name and localized titles', () => {
    assert.equal(regions.ids.size, 9);
    assert.equal(resolveRegionId('chuy', regions), 'chuy');
    assert.equal(resolveRegionId('Чуйская область', regions), 'chuy');
    assert.equal(resolveRegionId('Чүй облусу', regions), 'chuy');
    assert.equal(resolveRegionId(' бишкек ', regions), 'bishkek');
    assert.equal(resolveRegionId('Atlantis', regions), null);
    assert.equal(resolveRegionId(5, regions), null);
  });

  it('reads the app profile map {oblast, district, settlement}, a plain string or legacy region_id', () => {
    assert.equal(regionIdFromProfile({ region: { oblast: 'Ошская область', district: 'x', settlement: 'y' } }, regions), 'osh_region');
    assert.equal(regionIdFromProfile({ region: { id: 'naryn' } }, regions), 'naryn');
    assert.equal(regionIdFromProfile({ region: 'talas' }, regions), 'talas');
    assert.equal(regionIdFromProfile({ region_id: 'Бишкек' }, regions), 'bishkek');
    assert.equal(regionIdFromProfile({ region: { oblast: '' } }, regions), null);
    assert.equal(regionIdFromProfile({}, regions), null);
    assert.equal(regionIdFromProfile(null, regions), null);
  });
});

describe('adminSendNotification input (ARCHITECTURE §9.4)', () => {
  it('title/body need at least one language; a missing one falls back to the other', () => {
    assert.deepEqual(parsePair({ ru: ' Привет ', ky: 'Салам' }, 'title', 100), { ru: 'Привет', ky: 'Салам' });
    assert.deepEqual(parsePair({ ru: 'Только ru' }, 'title', 100), { ru: 'Только ru', ky: 'Только ru' });
    assert.deepEqual(parsePair({ ky: 'Кыргызча', ru: '' }, 'title', 100), { ru: 'Кыргызча', ky: 'Кыргызча' });
    for (const bad of [null, 'text', {}, { ru: '', ky: ' ' }, { ru: 5 }, { ru: 'x'.repeat(101) }]) {
      assert.throws(() => parsePair(bad, 'title', 100), isValidation, JSON.stringify(bad));
    }
  });

  it('audiences: all / language ru|ky / region id or name / group id', () => {
    assert.deepEqual(parseAudience({ kind: 'all' }, regions), { kind: 'all', value: null });
    assert.deepEqual(parseAudience({ kind: 'all', value: 'ignored' }, regions), { kind: 'all', value: null });
    assert.deepEqual(parseAudience({ kind: 'language', value: 'ky' }, regions), { kind: 'language', value: 'ky' });
    assert.deepEqual(parseAudience({ kind: 'region', value: 'Таласская область' }, regions), { kind: 'region', value: 'talas' });
    assert.deepEqual(parseAudience({ kind: 'group', value: 'g_123' }, regions), { kind: 'group', value: 'g_123' });
    for (const bad of [
      null,
      { kind: 'everyone' },
      { kind: 'language', value: 'en' },
      { kind: 'region', value: 'mars' },
      { kind: 'group', value: 'a/b' },
      { kind: 'group' },
    ]) {
      assert.throws(() => parseAudience(bad, regions), isValidation, JSON.stringify(bad));
    }
  });

  it('dryRun must be a boolean when given', () => {
    const base = { title: { ru: 't' }, body: { ru: 'b' }, audience: { kind: 'all' } };
    assert.equal(parseBroadcast(base, regions).dryRun, false);
    assert.equal(parseBroadcast({ ...base, dryRun: true }, regions).dryRun, true);
    assert.throws(() => parseBroadcast({ ...base, dryRun: 'yes' }, regions), isValidation);
  });
});

describe('audience filter', () => {
  const ru = { fcm_tokens: ['t1', 't2'], preferred_language: 'ru', region: { oblast: 'Чуйская область' }, group_ids: ['g1'] };
  const ky = { fcm_tokens: ['t3'], preferred_language: 'ky', region: 'naryn', group_ids: [] };

  it('needs tokens and no ban; language follows preferred_language', () => {
    assert.deepEqual(recipientFor('a', ru, { kind: 'all', value: null }, regions), { uid: 'a', tokens: ['t1', 't2'], language: 'ru' });
    assert.equal(recipientFor('b', ky, { kind: 'all', value: null }, regions)!.language, 'ky');
    assert.equal(recipientFor('c', { ...ru, fcm_tokens: [] }, { kind: 'all', value: null }, regions), null);
    assert.equal(recipientFor('d', { preferred_language: 'ru' }, { kind: 'all', value: null }, regions), null);
    assert.equal(recipientFor('e', { ...ru, is_banned: true }, { kind: 'all', value: null }, regions), null);
    assert.equal(recipientFor('f', undefined, { kind: 'all', value: null }, regions), null);
  });

  it('language, region and group audiences filter exactly', () => {
    assert.ok(recipientFor('a', ru, { kind: 'language', value: 'ru' }, regions));
    assert.equal(recipientFor('a', ru, { kind: 'language', value: 'ky' }, regions), null);
    assert.ok(recipientFor('a', ru, { kind: 'region', value: 'chuy' }, regions));
    assert.equal(recipientFor('b', ky, { kind: 'region', value: 'chuy' }, regions), null);
    assert.ok(recipientFor('b', ky, { kind: 'region', value: 'naryn' }, regions));
    assert.ok(recipientFor('a', ru, { kind: 'group', value: 'g1' }, regions));
    assert.equal(recipientFor('b', ky, { kind: 'group', value: 'g1' }, regions), null);
  });

  it('batches tokens per language, at most 500 per multicast, remembering owners', () => {
    const many: Recipient[] = Array.from({ length: 260 }, (_, i) => ({ uid: `u${i}`, tokens: [`a${i}`, `b${i}`], language: 'ru' }));
    many.push({ uid: 'k1', tokens: ['k'], language: 'ky' });
    const batches = tokenBatches(many);
    assert.deepEqual(batches.map((b) => [b.language, b.tokens.length]), [['ru', 500], ['ru', 20], ['ky', 1]]);
    assert.equal(batches[0]!.owners[1], 'u0');
    assert.equal(batches[0]!.owners[2], 'u1');
    assert.equal(batches[2]!.owners[0], 'k1');
    assert.deepEqual(tokenBatches([]), []);
  });

  it('at most 3 broadcasts per day', () => {
    assert.equal(BROADCASTS_PER_DAY, 3);
    assert.ok(canBroadcast(0) && canBroadcast(2));
    assert.ok(!canBroadcast(3));
  });
});
