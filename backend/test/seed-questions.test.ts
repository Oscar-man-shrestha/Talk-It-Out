import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { POST_TOPICS } from '../src/routes/feed';
import { classify, INTEREST_IDS } from '../src/nlp/topics';
import { loadSeedQuestions, removeSeedQuestions, SEED_EMAIL, seedQuestions } from '../src/seedQuestions';
import { closePool, ensureSchema, resetDb, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('starter questions', () => {
  const questions = loadSeedQuestions();

  it('cover every interest with valid post topics', () => {
    expect(questions.length).toBeGreaterThanOrEqual(30);
    for (const q of questions) {
      expect(INTEREST_IDS, q.title).toContain(q.topic);
      expect(q.title.length).toBeLessThanOrEqual(150);
    }
    // The classifier finds a topic for every question.
    const tagged = new Set(questions.flatMap((q) => classify(q.title, q.content).slice(0, 2).map((t) => t.id)));
    for (const id of INTEREST_IDS) expect(tagged.has(id), id).toBe(true);
  });

  it('adds once, repeats safely, and removes cleanly', async () => {
    const pool = testPool();
    expect(await seedQuestions(pool, questions)).toBe(questions.length);
    expect(await seedQuestions(pool, questions)).toBe(0);
    const login = await pool.query('SELECT username_chosen FROM users WHERE email = $1', [SEED_EMAIL]);
    expect(login.rows[0].username_chosen).toBe(true);
    const topics = await pool.query('SELECT DISTINCT topic FROM posts WHERE topic IS NOT NULL');
    for (const r of topics.rows) expect(POST_TOPICS).toContain(r.topic);
    expect(await removeSeedQuestions(pool)).toBe(true);
    const left = await pool.query('SELECT count(*)::int AS n FROM posts');
    expect(left.rows[0].n).toBe(0);
    expect(await removeSeedQuestions(pool)).toBe(false);
  });
});
