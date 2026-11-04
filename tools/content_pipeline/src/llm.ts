/**
 * Claude access for the opt-in paid stages (generate, verify, translate-check
 * --api). The key never lives in the repo or the app: the operator exports
 * ANTHROPIC_API_KEY in their own shell. Every paid command refuses to run
 * without --i-understand-this-costs-money.
 *
 * Requests use structured outputs (output_config.format = json_schema) and
 * are validated again with zod by the caller. No temperature/top_p/top_k.
 */
import Anthropic from '@anthropic-ai/sdk';
import { Usage } from './schema';

export const DEFAULT_MODEL = 'claude-opus-5-5';

/** USD per million tokens (input / output), as given for the 2026-11 plan. */
export const PRICES_PER_MTOK: Record<string, { input: number; output: number }> = {
  'claude-opus-5-5': { input: 4, output: 20 },
  'claude-sonnet-5-5': { input: 2, output: 10 },
  'claude-haiku-5-5': { input: 0.1, output: 0.5 },
};

export function costUsd(model: string, inputTokens: number, outputTokens: number): number {
  const p = PRICES_PER_MTOK[model] ?? PRICES_PER_MTOK[DEFAULT_MODEL]!;
  return Math.round(((inputTokens * p.input + outputTokens * p.output) / 1e6) * 1e6) / 1e6;
}

export interface LlmRequest {
  purpose: 'generate' | 'translate' | 'verify' | 'translate_check';
  system: string;
  user: string;
  schema: Record<string, unknown>;
  maxTokens?: number;
}

export interface LlmResponse {
  json: unknown;
  model: string;
  usage: Usage;
}

export interface LlmClient {
  readonly model: string;
  complete(req: LlmRequest): Promise<LlmResponse>;
}

export class LlmError extends Error {
  constructor(
    message: string,
    readonly kind: 'refusal' | 'truncated' | 'invalid_json' | 'api',
  ) {
    super(message);
  }
}

export const COST_FLAG = '--i-understand-this-costs-money';

/** Guards every paid stage. Throws with an operator-facing message. */
export function requirePaidConsent(consent: boolean, env: NodeJS.ProcessEnv = process.env): void {
  if (!consent) {
    throw new Error(`This stage calls the Anthropic API and costs money. Re-run with ${COST_FLAG} (see docs/modernization/CONTENT_PIPELINE.md for the cost estimate).`);
  }
  if (!env.ANTHROPIC_API_KEY) {
    throw new Error('ANTHROPIC_API_KEY is not set in this shell. Export the operator key in your environment; never commit it or put it in the app.');
  }
}

/** Extracts a JSON object from model text (structured outputs return pure JSON; this is the fallback). */
export function parseJsonText(text: string): unknown {
  const t = text.trim();
  try {
    return JSON.parse(t);
  } catch {
    const start = t.indexOf('{');
    const end = t.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(t.slice(start, end + 1));
      } catch {
        /* fall through */
      }
    }
    throw new LlmError('response is not valid JSON', 'invalid_json');
  }
}

export interface AnthropicLlmOptions {
  model?: string;
  effort?: 'low' | 'medium' | 'high' | 'xhigh' | 'max';
  /** Server-side refusal fallback (Claude API only; not for Haiku). */
  fallbacks?: boolean;
  maxRetries?: number;
}

export class AnthropicLlm implements LlmClient {
  readonly model: string;
  private readonly client: Anthropic;
  private readonly effort: NonNullable<AnthropicLlmOptions['effort']>;
  private readonly fallbacks: boolean;

  constructor(opts: AnthropicLlmOptions = {}) {
    this.model = opts.model ?? process.env.CONTENT_MODEL ?? DEFAULT_MODEL;
    this.effort = opts.effort ?? 'high';
    this.fallbacks = (opts.fallbacks ?? true) && !this.model.includes('haiku');
    this.client = new Anthropic({ maxRetries: opts.maxRetries ?? 4 });
  }

  async complete(req: LlmRequest): Promise<LlmResponse> {
    const base = {
      model: this.model,
      max_tokens: req.maxTokens ?? 32000,
      system: [{ type: 'text' as const, text: req.system, cache_control: { type: 'ephemeral' as const } }],
      messages: [{ role: 'user' as const, content: req.user }],
      output_config: { effort: this.effort, format: { type: 'json_schema' as const, schema: req.schema } },
    };
    let message: { content: Array<{ type: string; text?: string }>; stop_reason: string | null; model: string; usage: { input_tokens: number; output_tokens: number; cache_read_input_tokens?: number | null; cache_creation_input_tokens?: number | null } };
    try {
      if (this.fallbacks) {
        message = await this.client.beta.messages
          .stream({ ...base, betas: ['server-side-fallback-2026-07-01'], fallbacks: 'default' } as never)
          .finalMessage() as never;
      } else {
        message = (await this.client.messages.stream(base as never).finalMessage()) as never;
      }
    } catch (e) {
      if (e instanceof Anthropic.APIError) throw new LlmError(`Anthropic API error ${e.status ?? ''}: ${e.message}`, 'api');
      throw e;
    }
    if (message.stop_reason === 'refusal') throw new LlmError('model declined the request (stop_reason=refusal)', 'refusal');
    if (message.stop_reason === 'max_tokens') throw new LlmError('response truncated at max_tokens', 'truncated');
    const text = message.content.filter((b) => b.type === 'text').map((b) => b.text ?? '').join('');
    const u = message.usage;
    const input = u.input_tokens + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
    return {
      json: parseJsonText(text),
      model: message.model,
      usage: { input_tokens: input, output_tokens: u.output_tokens, cost_usd: costUsd(this.model, input, u.output_tokens) },
    };
  }
}

/** Accumulates spend and stops a run at --max-cost-usd. */
export class CostMeter {
  input = 0;
  output = 0;
  usd = 0;
  calls = 0;
  constructor(readonly limitUsd: number | null) {}
  add(u: Usage): void {
    this.input += u.input_tokens;
    this.output += u.output_tokens;
    this.usd += u.cost_usd;
    this.calls++;
  }
  exhausted(): boolean {
    return this.limitUsd !== null && this.usd >= this.limitUsd;
  }
  toString(): string {
    return `${this.calls} calls, ${this.input} in / ${this.output} out tokens, ≈ $${this.usd.toFixed(2)}`;
  }
}
