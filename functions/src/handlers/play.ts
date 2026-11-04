/**
 * Thin Google Play Developer API adapter. Uses Application Default
 * Credentials of the function's runtime service account, which must be
 * invited in Play Console (View financial data + Manage orders).
 */
import { androidpublisher, auth as googleAuth, type androidpublisher_v3 } from '@googleapis/androidpublisher';
import { logger } from 'firebase-functions';
import { adaptV1ToV2, type ProductPurchaseV2Like } from '../domain/purchase';

let client: androidpublisher_v3.Androidpublisher | null = null;

function api(): androidpublisher_v3.Androidpublisher {
  if (!client) {
    const authClient = new googleAuth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    client = androidpublisher({ version: 'v3', auth: authClient });
  }
  return client;
}

function httpStatus(e: unknown): number | null {
  const err = e as { status?: unknown; code?: unknown; response?: { status?: unknown } };
  for (const v of [err?.status, err?.response?.status, err?.code]) {
    if (typeof v === 'number') return v;
    if (typeof v === 'string' && /^\d{3}$/.test(v)) return Number(v);
  }
  return null;
}

/** Token unknown to Play (or not for this package): never retry, never grant. */
function isNotFound(status: number | null): boolean {
  return status === 400 || status === 404 || status === 410;
}

export type FetchResult = { found: true; purchase: ProductPurchaseV2Like; api: 'v2' | 'v1' } | { found: false };

/**
 * purchases.productsv2.getproductpurchasev2, falling back to the legacy
 * purchases.products.get when the v2 call fails for a reason other than an
 * unknown token. Throws on transient errors so the client can retry.
 */
export async function fetchPurchase(packageName: string, productId: string, token: string): Promise<FetchResult> {
  try {
    const res = await api().purchases.productsv2.getproductpurchasev2({ packageName, token });
    return { found: true, purchase: res.data as ProductPurchaseV2Like, api: 'v2' };
  } catch (e) {
    const status = httpStatus(e);
    if (isNotFound(status)) return { found: false };
    logger.warn('getproductpurchasev2 failed, trying products.get', { status, error: String(e) });
  }
  try {
    const res = await api().purchases.products.get({ packageName, productId, token });
    return { found: true, purchase: adaptV1ToV2(res.data, productId), api: 'v1' };
  } catch (e) {
    if (isNotFound(httpStatus(e))) return { found: false };
    throw e;
  }
}

/** Consumes (and thereby acknowledges) a one-time product. */
export async function consumePurchase(packageName: string, productId: string, token: string): Promise<boolean> {
  try {
    await api().purchases.products.consume({ packageName, productId, token });
    return true;
  } catch (e) {
    logger.error('consume failed', { productId, status: httpStatus(e), error: String(e) });
    return false;
  }
}

export interface VoidedItem {
  purchaseToken: string;
  orderId: string | null;
  voidedTimeMs: number | null;
  voidedQuantity: number | null;
  voidedSource: number | null;
  voidedReason: number | null;
}

/** All one-time-product voided purchases since `startTimeMs` (paginated). */
export async function listVoided(packageName: string, startTimeMs: number): Promise<VoidedItem[]> {
  const out: VoidedItem[] = [];
  let pageToken: string | undefined;
  for (let page = 0; page < 50; page++) {
    const res = await api().purchases.voidedpurchases.list({
      packageName,
      startTime: String(startTimeMs),
      maxResults: 1000,
      type: 0,
      ...(pageToken ? { token: pageToken } : {}),
    });
    for (const v of res.data.voidedPurchases ?? []) {
      if (!v.purchaseToken) continue;
      out.push({
        purchaseToken: v.purchaseToken,
        orderId: v.orderId ?? null,
        voidedTimeMs: v.voidedTimeMillis ? Number(v.voidedTimeMillis) : null,
        voidedQuantity: v.voidedQuantity ?? null,
        voidedSource: v.voidedSource ?? null,
        voidedReason: v.voidedReason ?? null,
      });
    }
    pageToken = res.data.tokenPagination?.nextPageToken ?? undefined;
    if (!pageToken) break;
  }
  return out;
}
