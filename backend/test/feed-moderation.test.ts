import { describe, expect, it } from 'vitest';
import { createFeedProvider, createLexiconFeedProvider } from '../src/feed-analysis/provider';
import { moderationFlags } from '../src/nlp/moderation';

const req = (text: string) => ({
  request_id: 'r1',
  content_type: 'post' as const,
  content_id: 'c1',
  content_revision: 1,
  text,
});

describe('feed moderation (FEED_PROVIDER=lexicon)', () => {
  it('flags hate speech, threats, abuse and profanity', () => {
    expect(moderationFlags('all immigrants are criminals')).toContain('hate_speech');
    expect(moderationFlags("women can't do backend work")).toContain('hate_speech');
    expect(moderationFlags('women may not be suited for backend work')).toContain('hate_speech');
    expect(moderationFlags('I will kill you')).toContain('threat');
    expect(moderationFlags('you guys are total idiots')).toContain('abusive_language');
    expect(moderationFlags('this is f.u.c.k.i.n.g broken')).toContain('profanity');
    expect(moderationFlags('honestly I want to die')).toEqual(['self_harm']);
  });

  it('leaves criticism of things and normal questions alone', () => {
    for (const text of [
      'The dashboard is useless and slow',
      'How do you give feedback to a senior without sounding rude?',
      "I'm late bc of traffic",
    ]) {
      expect(moderationFlags(text)).toEqual([]);
    }
  });

  it('marks abusive content as flagged; self-harm alone is not a warning', async () => {
    const provider = createLexiconFeedProvider();
    const abusive = await provider.analyze(req('you idiots, go back to your country'));
    expect(abusive).toMatchObject({ outcome: 'ok', nsfw: true, provider_version: 'lexicon-1' });
    expect(abusive.flags).toEqual({ hate_speech: true, abusive_language: true });
    const care = await provider.analyze(req('some days I want to die'));
    expect(care).toMatchObject({ nsfw: false, flags: { self_harm: true } });
    const clean = await provider.analyze(req('How should we run retros?'));
    expect(clean).toMatchObject({ nsfw: false, flags: {} });
  });

  it('is selectable by name', () => {
    expect(() => createFeedProvider('lexicon')).not.toThrow();
    expect(() => createFeedProvider('nope')).toThrow(/fake, lexicon/);
  });
});
