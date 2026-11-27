import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { sentencesOf, summarize } from '../src/nlp/summarize';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

const t = (min: number) => new Date(Date.UTC(2026, 10, 15, 9, min));

const retro = [
  'The release slipped again because code reviews are taking three days.',
  'Agreed, code reviews are the bottleneck. Pull requests sit waiting for a reviewer.',
  'Lunch was great today.',
  'Could we set a rule that every pull request gets a review within one day?',
  'On-call was rough this week too, with pages every night.',
  'A one day review rule would help the release a lot.',
  'Who owns the on-call rota?',
].map((text, i) => ({ text, at: t(i) }));

describe('TextRank summary', () => {
  it('picks the sentences the conversation keeps returning to', () => {
    const s = summarize(retro);
    expect(s.message_count).toBe(7);
    expect(s.highlights.length).toBeGreaterThanOrEqual(2);
    expect(s.highlights.join(' ')).toMatch(/review/i);
    expect(s.highlights).not.toContain('Lunch was great today.');
    // Shown in the order they were said.
    const positions = s.highlights.map((h) => retro.findIndex((m) => m.text.includes(h.slice(0, 20))));
    expect([...positions].sort((a, b) => a - b)).toEqual(positions);
    expect(s.open_questions.length).toBeGreaterThan(0);
    expect(s.open_questions.every((q) => q.endsWith('?'))).toBe(true);
    expect(s.key_topics).toContain('review');
    expect(s.themes.map((x) => x.id)).toContain('engineering');
  });

  it('handles empty and tiny conversations', () => {
    expect(summarize([])).toMatchObject({ message_count: 0, highlights: [] });
    expect(summarize([{ text: 'ok', at: t(0) }]).highlights).toEqual([]);
    expect(sentencesOf('Budget planning starts Monday morning. Design review moved to Friday afternoon!\nHiring panel needs two more interviewers')).toHaveLength(3);
  });

  it('shortens very long sentences', () => {
    const long = `${'word '.repeat(80)}end.`;
    const s = summarize([{ text: long, at: t(0) }]);
    expect(s.highlights[0].length).toBeLessThanOrEqual(220);
    expect(s.highlights[0].endsWith('...')).toBe(true);
  });
});

describe('GET /groups/:id/summary (API 63)', () => {
  beforeAll(ensureSchema);
  beforeEach(resetDb);
  afterAll(closePool);

  it('summarises published messages for members only, without names', async () => {
    const app = testApp();
    const ctrl = await registerUser(app, 'Controller Person', 'c@example.com');
    const outsider = await registerUser(app, 'Outsider', 'o@example.com');
    const g = await api.post(app, '/groups', ctrl.token, { agenda: 'Retro' });
    for (const [i, m] of retro.entries()) {
      await testPool().query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous, published_at)
         VALUES ($1, $2, $3, $4, $5)`,
        [g.body.id, i % 2 ? null : ctrl.id, m.text, i % 2 === 1, m.at],
      );
    }
    const res = await api.get(app, `/groups/${g.body.id}/summary`, ctrl.token);
    expect(res.status).toBe(200);
    expect(res.body.message_count).toBe(7);
    expect(res.body.highlights.length).toBeGreaterThan(0);
    expect(res.body.from).toBe(t(0).toISOString());
    expect(JSON.stringify(res.body)).not.toContain('Controller Person');
    expect((await api.get(app, `/groups/${g.body.id}/summary`, outsider.token)).status).toBe(403);
    expect((await api.get(app, '/groups/not-a-uuid/summary', ctrl.token)).status).toBe(404);
  });
});
