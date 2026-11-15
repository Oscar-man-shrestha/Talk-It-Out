/**
 * Starter questions for an empty feed (docs/STARTUP_PLAN.md section 8), so
 * For You has something to rank on day one. They are posted by a clearly
 * named community account and can be removed in one step.
 */
import crypto from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import argon2 from 'argon2';
import { Pool } from 'pg';
import { withTransaction } from './db';
import { deleteAccount } from './routes/account';
import { POST_TOPICS } from './routes/feed';

export const SEED_EMAIL = 'community@talkitout.invalid';
export const SEED_NAME = 'Talk It Out Community';
export const SEED_HANDLE = 'talkitout.community';

export interface SeedQuestion {
  /** An interest id (one of 15); stored only if it is a question topic. */
  topic: string;
  title: string;
  content: string;
}

export function loadSeedQuestions(
  file = path.join(__dirname, '..', 'scripts', 'seed-questions.json'),
): SeedQuestion[] {
  return JSON.parse(readFileSync(file, 'utf8')) as SeedQuestion[];
}

/** Adds the questions that are not there yet. Returns how many were added. */
export async function seedQuestions(pool: Pool, questions: SeedQuestion[]): Promise<number> {
  return withTransaction(pool, async (client) => {
    let { rows } = await client.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [SEED_EMAIL]);
    if (!rows[0]) {
      // Nobody knows this password: the account cannot be signed in to.
      const hash = await argon2.hash(crypto.randomBytes(32).toString('hex'));
      ({ rows } = await client.query<{ id: string }>(
        `INSERT INTO users (email, username, username_chosen, password_hash, name)
         VALUES ($1, $2, true, $3, $4) RETURNING id`,
        [SEED_EMAIL, SEED_HANDLE, hash, SEED_NAME],
      ));
    }
    const authorId = rows[0].id;
    const existing = await client.query<{ title: string }>(
      'SELECT title FROM posts WHERE author_id = $1',
      [authorId],
    );
    const have = new Set(existing.rows.map((r) => r.title));
    let added = 0;
    for (const [i, q] of questions.entries()) {
      if (have.has(q.title)) continue;
      // Spread over the last two weeks so the feed looks lived-in.
      const hoursAgo = Math.round(((i * 37) % (14 * 24)) + 1);
      const inserted = await client.query<{ id: string; content_revision: number }>(
        `INSERT INTO posts (author_id, title, topic, content, created_at)
         VALUES ($1, $2, $3, $4, now() - make_interval(hours => $5))
         RETURNING id, content_revision`,
        [
          authorId,
          q.title,
          // Only the six question topics are stored; the rest are tagged by
          // the topic classifier.
          (POST_TOPICS as readonly string[]).includes(q.topic) ? q.topic : null,
          q.content,
          hoursAgo,
        ],
      );
      await client.query(
        `INSERT INTO jobs (kind, content_type, content_id, content_revision)
         VALUES ('analyze_feed_content', 'post', $1, $2)`,
        [inserted.rows[0].id, inserted.rows[0].content_revision],
      );
      added++;
    }
    return added;
  });
}

/** Removes the community account and everything it posted. */
export async function removeSeedQuestions(pool: Pool): Promise<boolean> {
  const { rows } = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [SEED_EMAIL]);
  if (!rows[0]) return false;
  await withTransaction(pool, (client) => deleteAccount(client, rows[0].id));
  return true;
}
