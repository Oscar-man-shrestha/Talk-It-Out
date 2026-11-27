import { z } from 'zod';
import { moderationFlags } from '../nlp/moderation';

/**
 * OUR internal feed-analysis boundary contract — contract_version: 1.
 *
 * This is NOT Team 12's contract. Team 12 (or any future moderation vendor)
 * gets a thin adapter that converts their protocol into this shape; nothing
 * in this codebase may depend on Team 12's wire format. Version this
 * contract whenever its fields change.
 *
 * Privacy rules for every provider, fake or real:
 * - The request carries only the content type, content id, content revision,
 *   and the post/comment TEXT. No group data, no group sender identities,
 *   no user credentials ever leave the database through this interface.
 * - Providers may never access our database.
 */
export const FEED_ANALYSIS_CONTRACT_VERSION = 1;

export type FeedContentType = 'post' | 'comment';

export interface FeedAnalysisRequest {
  /** Correlation id (the analysis job id); echoed back by the provider. */
  request_id: string;
  content_type: FeedContentType;
  content_id: string;
  /** Revision of the content at enqueue time; guards stale results. */
  content_revision: number;
  text: string;
}

export interface FeedAnalysisResult {
  request_id: string;
  content_id: string;
  content_revision: number;
  outcome: 'ok' | 'unavailable' | 'error';
  /** Present when outcome is 'ok'. */
  nsfw?: boolean;
  flags?: Record<string, unknown>;
  provider_version?: string;
  /** Present when outcome is 'error'. */
  error_code?: string;
}

export interface FeedAnalysisProvider {
  analyze(request: FeedAnalysisRequest): Promise<FeedAnalysisResult>;
}

/**
 * Strict validation of provider output. Anything that does not match this
 * shape is treated as a provider contract violation and fails the analysis
 * (never silently defaults to "safe").
 */
export const feedAnalysisResultSchema = z.object({
  request_id: z.string().min(1),
  content_id: z.string().min(1),
  content_revision: z.number().int().min(1),
  outcome: z.enum(['ok', 'unavailable', 'error']),
  nsfw: z.boolean().optional(),
  flags: z.record(z.string(), z.unknown()).optional(),
  provider_version: z.string().min(1).optional(),
  error_code: z.string().min(1).optional(),
});

export type FakeProviderMode = 'normal' | 'unavailable' | 'error';

/**
 * Deterministic fake provider used by default (FEED_PROVIDER=fake).
 * Clearly NOT moderation: it flags any content containing the literal
 * word "nsfw-test" so flows are testable end to end.
 */
export function createFakeFeedProvider(mode: FakeProviderMode = 'normal'): FeedAnalysisProvider {
  return {
    async analyze(request) {
      if (mode === 'unavailable') {
        return {
          request_id: request.request_id,
          content_id: request.content_id,
          content_revision: request.content_revision,
          outcome: 'unavailable',
        };
      }
      if (mode === 'error') {
        return {
          request_id: request.request_id,
          content_id: request.content_id,
          content_revision: request.content_revision,
          outcome: 'error',
          error_code: 'fake_injected_error',
        };
      }
      const nsfw = request.text.includes('nsfw-test');
      return {
        request_id: request.request_id,
        content_id: request.content_id,
        content_revision: request.content_revision,
        outcome: 'ok',
        nsfw,
        flags: nsfw ? { matched_keyword: 'nsfw-test' } : {},
        provider_version: 'fake-1',
      };
    },
  };
}

/**
 * Real, local moderation for the public feed (FEED_PROVIDER=lexicon): hate
 * speech, threats, insults, profanity and self-harm signals, with the same
 * rules as the rewrite worker (src/nlp/moderation.ts). Flagged content is
 * marked for readers ("Flagged"); nothing is removed automatically.
 */
export function createLexiconFeedProvider(): FeedAnalysisProvider {
  return {
    async analyze(request) {
      const flags = moderationFlags(request.text);
      // Self-harm is a reason to care, not a reason to warn readers.
      const flagged = flags.some((f) => f !== 'self_harm');
      return {
        request_id: request.request_id,
        content_id: request.content_id,
        content_revision: request.content_revision,
        outcome: 'ok',
        nsfw: flagged,
        flags: Object.fromEntries(flags.map((f) => [f, true])),
        provider_version: 'lexicon-1',
      };
    },
  };
}

/** Maps FEED_PROVIDER to a provider instance; unknown names fail loudly. */
export function createFeedProvider(name: string): FeedAnalysisProvider {
  if (name === 'fake') return createFakeFeedProvider();
  if (name === 'lexicon') return createLexiconFeedProvider();
  throw new Error(
    `Unknown FEED_PROVIDER "${name}". Supported providers: fake, lexicon.`,
  );
}
