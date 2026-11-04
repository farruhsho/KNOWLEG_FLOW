/**
 * Admin callables (ARCHITECTURE §2/§3). Every call checks the permission
 * matrix against fresh custom claims (legacy users.role=='admin' fallback)
 * and writes admin_logs.
 */
import '../config';
import { getAuth } from 'firebase-admin/auth';
import { onCall } from 'firebase-functions/v2/https';
import { validateVariant } from '../domain/blueprint_validation';
import { applyAdminDelta, parseEntitlement } from '../domain/entitlements';
import { isValidProductId } from '../domain/purchase';
import { DomainError, Reasons } from '../domain/reasons';
import { isRole, legacyUserRoleFor, ROLES, type Role } from '../domain/roles';
import { isRecord, num } from '../domain/types';
import { adminCallableOptions, db, FieldValue, payload, reqId, reqInt, reqString, requirePermission, wrap, writeAdminLog } from './common';
import { loadBlueprint, loadKeys, loadPassages, loadQuestions, loadVariant } from './content';

async function requireUser(uid: string) {
  try {
    return await getAuth().getUser(uid);
  } catch {
    throw new DomainError(Reasons.VALIDATION_FAILED, 'user not found', { field: 'uid' });
  }
}

const ROLE_RANK: Record<Role, number> = { super_admin: 5, content_manager: 4, methodologist: 3, moderator: 2, support: 1 };

// ---------------------------------------------------------------------------
// adminSetRole {uid, role|null} -> {ok}

export const adminSetRole = onCall(
  adminCallableOptions(),
  wrap('adminSetRole', async (req) => {
    const actor = await requirePermission(req, 'manage_roles');
    const data = payload(req);
    const targetUid = reqId(data['uid'], 'uid');
    const roleRaw = data['role'];
    if (roleRaw !== null && roleRaw !== undefined && !isRole(roleRaw)) {
      throw new DomainError(Reasons.VALIDATION_FAILED, `role must be one of ${ROLES.join(', ')} or null`, { field: 'role' });
    }
    const role: Role | null = isRole(roleRaw) ? roleRaw : null;
    if (targetUid === actor.uid && role !== 'super_admin') {
      throw new DomainError(Reasons.VALIDATION_FAILED, 'you cannot remove your own super_admin role');
    }
    const user = await requireUser(targetUid);
    const claims: Record<string, unknown> = { ...(user.customClaims ?? {}) };
    const previous = isRole(claims['role']) ? (claims['role'] as Role) : null;
    if (role) claims['role'] = role;
    else delete claims['role'];
    await getAuth().setCustomUserClaims(targetUid, claims);

    // Keep the legacy users.role field consistent so the 'admin' fallback can
    // never outlive a revoked claim.
    const userRef = db().doc(`users/${targetUid}`);
    const snap = await userRef.get();
    if (snap.exists) {
      await userRef.update({
        role: legacyUserRoleFor(role),
        admin_role: role,
        role_updated_at: FieldValue.serverTimestamp(),
        role_updated_by: actor.uid,
      });
    }
    const downgraded = previous !== null && (role === null || ROLE_RANK[role] < ROLE_RANK[previous]);
    const legacyRevoked = snap.get('role') === 'admin' && role !== 'super_admin';
    if (downgraded || legacyRevoked) await getAuth().revokeRefreshTokens(targetUid);

    await writeAdminLog(actor, 'set_role', { uid: targetUid }, { from: previous ?? (snap.get('role') === 'admin' ? 'legacy_admin' : null), to: role });
    return { ok: true };
  }),
);

// ---------------------------------------------------------------------------
// adminGrantCredits {uid, delta, reason} -> {credits}

export const adminGrantCredits = onCall(
  adminCallableOptions(),
  wrap('adminGrantCredits', async (req) => {
    const actor = await requirePermission(req, 'grant_credits');
    const data = payload(req);
    const targetUid = reqId(data['uid'], 'uid');
    const delta = reqInt(data['delta'], 'delta', -1000, 1000);
    if (delta === 0) throw new DomainError(Reasons.VALIDATION_FAILED, 'delta must not be 0', { field: 'delta' });
    const reason = reqString(data['reason'], 'reason', 3, 200);
    await requireUser(targetUid);

    const entRef = db().doc(`entitlements/${targetUid}`);
    const out = await db().runTransaction(async (tx) => {
      const snap = await tx.get(entRef);
      const applied = applyAdminDelta(parseEntitlement(snap.data()), delta);
      tx.set(entRef, { credits: applied.entitlement.credits, updated_at: FieldValue.serverTimestamp() }, { merge: true });
      tx.set(entRef.collection('ledger').doc(), {
        ...applied.ledger,
        requested_delta: delta,
        note: reason,
        ref: 'admin',
        actor_uid: actor.uid,
        at: FieldValue.serverTimestamp(),
      });
      return applied;
    });
    await writeAdminLog(actor, 'grant_credits', { uid: targetUid }, { delta, applied: out.applied, reason, balance_after: out.entitlement.credits });
    return { credits: out.entitlement.credits };
  }),
);

// ---------------------------------------------------------------------------
// adminPublishVariant {variantId, publish} -> {status, problems}

export const adminPublishVariant = onCall(
  adminCallableOptions({ timeoutSeconds: 120, memory: '512MiB' }),
  wrap('adminPublishVariant', async (req) => {
    const actor = await requirePermission(req, 'publish_variants');
    const data = payload(req);
    const variantId = reqId(data['variantId'], 'variantId');
    if (typeof data['publish'] !== 'boolean') throw new DomainError(Reasons.VALIDATION_FAILED, 'publish must be a boolean', { field: 'publish' });
    const publish = data['publish'];
    const variant = await loadVariant(variantId);
    if (!variant) throw new DomainError(Reasons.VALIDATION_FAILED, 'variant not found', { field: 'variantId' });
    const ref = db().doc(`exam_variants/${variantId}`);

    if (!publish) {
      await ref.update({ status: 'archived', archived_at: FieldValue.serverTimestamp(), archived_by: actor.uid });
      await writeAdminLog(actor, 'unpublish_variant', { variantId }, { from: variant.status });
      return { status: 'archived', problems: [] };
    }

    const blueprint = await loadBlueprint(variant.blueprint_id);
    if (!blueprint) {
      return { status: variant.status, problems: [{ code: 'blueprint_mismatch', expected: variant.blueprint_id, actual: null }] };
    }
    const qids = variant.sections.flatMap((s) => s.question_ids);
    const [questions, keys] = await Promise.all([loadQuestions(qids), loadKeys(qids)]);
    const passageIds = [...questions.values()].map((q) => q.passage_id).filter((p): p is string => !!p);
    const passages = await loadPassages(passageIds);
    const problems = validateVariant({ blueprint, variant, questions, keys, passageIds: new Set(passages.keys()) });
    if (problems.length > 0) {
      await writeAdminLog(actor, 'publish_variant_rejected', { variantId }, { problems: problems.length });
      return { status: variant.status, problems };
    }
    await ref.update({
      status: 'published',
      published_at: FieldValue.serverTimestamp(),
      published_by: actor.uid,
      blueprint_version: blueprint.version,
    });
    await writeAdminLog(actor, 'publish_variant', { variantId }, { questions: qids.length });
    return { status: 'published', problems: [] };
  }),
);

// ---------------------------------------------------------------------------
// adminUpdatePricing {products, freeExamsPerUser} -> {ok}

export const adminUpdatePricing = onCall(
  adminCallableOptions(),
  wrap('adminUpdatePricing', async (req) => {
    const actor = await requirePermission(req, 'manage_pricing');
    const data = payload(req);
    const rawProducts = data['products'];
    const products: Record<string, number> = {};
    const entries: Array<[unknown, unknown]> = Array.isArray(rawProducts)
      ? rawProducts.filter(isRecord).map((p) => [p['productId'] ?? p['product_id'] ?? p['id'], p['credits']])
      : isRecord(rawProducts)
        ? Object.entries(rawProducts).map(([k, v]) => [k, isRecord(v) ? v['credits'] : v])
        : [];
    for (const [id, credits] of entries) {
      const c = num(credits, NaN);
      if (!isValidProductId(id) || !Number.isInteger(c) || c < 1 || c > 1000) {
        throw new DomainError(Reasons.VALIDATION_FAILED, `invalid product entry ${String(id)}`, { field: 'products' });
      }
      products[id] = c;
    }
    if (Object.keys(products).length === 0) throw new DomainError(Reasons.VALIDATION_FAILED, 'products must not be empty', { field: 'products' });
    const freeExamsPerUser = reqInt(data['freeExamsPerUser'], 'freeExamsPerUser', 0, 5);

    const ref = db().doc('config/pricing');
    const before = (await ref.get()).data() ?? null;
    await ref.set(
      { products, free_exams_per_user: freeExamsPerUser, updated_at: FieldValue.serverTimestamp(), updated_by: actor.uid },
      { merge: true },
    );
    await writeAdminLog(actor, 'update_pricing', { doc: 'config/pricing' }, {
      before: before ? { products: before['products'] ?? null, free_exams_per_user: before['free_exams_per_user'] ?? null } : null,
      after: { products, free_exams_per_user: freeExamsPerUser },
    });
    return { ok: true };
  }),
);
