/**
 * Adapter selection (ARCHITECTURE §10.3): PAYMENT_PROVIDER = `none`
 * (default) | `sandbox` | a provider name. `sandbox` is loaded ONLY inside
 * the Functions emulator for a `demo-*` project; anywhere else it resolves
 * to `none`, so paymentCreateOrder answers PAYMENTS_DISABLED and no
 * fictitious payment can ever be created in a real project. Unknown names
 * (a provider whose adapter is not written yet) also resolve to `none`.
 */
import { noneAdapter } from './none';
import { sandboxAdapter } from './sandbox';
import type { PaymentAdapter } from './types';

export interface RuntimeEnv {
  FUNCTIONS_EMULATOR?: string | undefined;
  GCLOUD_PROJECT?: string | undefined;
  GCP_PROJECT?: string | undefined;
  FIREBASE_CONFIG?: string | undefined;
}

/** Project id of the running functions (emulator or Cloud). */
export function projectIdOf(env: RuntimeEnv): string {
  if (env.GCLOUD_PROJECT) return env.GCLOUD_PROJECT;
  if (env.GCP_PROJECT) return env.GCP_PROJECT;
  try {
    const cfg = JSON.parse(env.FIREBASE_CONFIG ?? '{}') as { projectId?: unknown };
    return typeof cfg.projectId === 'string' ? cfg.projectId : '';
  } catch {
    return '';
  }
}

/** The sandbox may run only in the emulator AND for a demo-* project. */
export function sandboxAllowed(env: RuntimeEnv): boolean {
  return env.FUNCTIONS_EMULATOR === 'true' && projectIdOf(env).startsWith('demo-');
}

/** Adapters by name (real providers are added here). */
const PROVIDERS: Readonly<Record<string, PaymentAdapter>> = Object.freeze({});

export type Resolution = { adapter: PaymentAdapter; enabled: boolean; why?: 'none' | 'sandbox_outside_emulator' | 'unknown_provider' };

export function resolveAdapter(name: string, env: RuntimeEnv): Resolution {
  const n = name.trim().toLowerCase();
  if (n === '' || n === 'none') return { adapter: noneAdapter, enabled: false, why: 'none' };
  if (n === 'sandbox') {
    return sandboxAllowed(env) ? { adapter: sandboxAdapter, enabled: true } : { adapter: noneAdapter, enabled: false, why: 'sandbox_outside_emulator' };
  }
  const real = Object.prototype.hasOwnProperty.call(PROVIDERS, n) ? PROVIDERS[n] : undefined;
  return real ? { adapter: real, enabled: true } : { adapter: noneAdapter, enabled: false, why: 'unknown_provider' };
}

/** Adapter that owns an existing order (refunds go to the provider that took the money). */
export function adapterForOrder(provider: string, env: RuntimeEnv): PaymentAdapter | null {
  const r = resolveAdapter(provider, env);
  return r.enabled && r.adapter.name === provider ? r.adapter : null;
}
