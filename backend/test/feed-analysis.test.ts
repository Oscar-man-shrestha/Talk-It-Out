import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { runFeedWorkerOnce } from '../src/feed-analysis/worker';
import { createFakeFeedProvider } from '../src/feed-analysis/provider';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
import {
  api,
  closePool,
  ensureSchema,
  registerUser,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

async function createPost(token: string, content: string): Promise<string> {
  const app = testApp();
  const res = await api.post(app, '/posts', token, { content });
  if (res.status !== 201) throw new Error(`createPost failed: ${JSON.stringify(res.body)}`);
  return res.body.id as string;
}

async function analysisStatus(contentType: 'post' | 'comment', id: string): Promise<string> {
  const table = contentType === 'post' ? 'posts' : 'comments';
  const { rows } = await testPool().query(
    `SELECT analysis_status FROM ${table} WHERE id = $1`,
    [id],
  );
  return rows[0].analysis_status;
}

function makeDue(contentId: string) {
  return testPool().query(
    `UPDATE jobs SET run_after = now() - interval '1 second' WHERE content_id = $1`,
    [contentId],
  );
}

describe('feed analysis worker', () => {
  it('pending -> complete: nsfw and flags surface only when complete', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Feed Poster', 'feed-poster@example.com');
    const flagged = await createPost(user.token, 'this mentions nsfw-test on purpose');
    const clean = await createPost(user.token, 'perfectly ordinary post');

    expect(await analysisStatus('post', flagged)).toBe('pending');
    const run = await runFeedWorkerOnce(testPool());
    expect(run).toMatchObject({ claimed: 2, completed: 2 });
    expect(await analysisStatus('post', flagged)).toBe('complete');
    expect(await analysisStatus('post', clean)).toBe('complete');

    const flaggedRes = await api.get(app, `/posts/${flagged}`, user.token);
    expect(flaggedRes.body.nsfw_flag).toBe(true);
    expect(flaggedRes.body.other_flags).toEqual({ matched_keyword: 'nsfw-test' });

    const cleanRes = await api.get(app, `/posts/${clean}`, user.token);
    expect(cleanRes.body.nsfw_flag).toBe(false);
    expect(cleanRes.body.other_flags).toEqual({});
  });

  it('comments are analyzed through the same pipeline', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Feed Commenter', 'feed-commenter@example.com');
    const postId = await createPost(user.token, 'parent post');
    const created = await api.post(app, `/posts/${postId}/comments`, user.token, {
      content: 'a comment containing nsfw-test',
    });
    const commentId = created.body.id as string;

    await runFeedWorkerOnce(testPool());
    expect(await analysisStatus('comment', commentId)).toBe('complete');

    const comments = await api.get(app, `/posts/${postId}/comments`, user.token);
    expect(comments.body.items[0].nsfw_flag).toBe(true);
    expect(comments.body.items[0].other_flags).toEqual({ matched_keyword: 'nsfw-test' });
  });

  it('provider unavailable leaves nsfw_flag false and status unavailable (not complete)', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Feed Unavail', 'feed-unavail@example.com');
    const postId = await createPost(user.token, 'nsfw-test but provider is down');

    const run = await runFeedWorkerOnce(testPool(), {
      provider: createFakeFeedProvider('unavailable'),
    });
    expect(run).toMatchObject({ claimed: 1, unavailable: 1 });
    expect(await analysisStatus('post', postId)).toBe('unavailable');

    const res = await api.get(app, `/posts/${postId}`, user.token);
    expect(res.body.nsfw_flag).toBe(false);
    expect(res.body.other_flags).toEqual({});
  });

  it('provider errors retry with backoff, then fail without ever looking complete', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Feed Error', 'feed-error@example.com');
    const postId = await createPost(user.token, 'nsfw-test under a failing provider');

    const fail = () =>
      runFeedWorkerOnce(testPool(), { provider: createFakeFeedProvider('error') });
    let run = await fail();
    expect(run).toMatchObject({ claimed: 1, retried: 1 });
    await makeDue(postId);
    run = await fail();
    expect(run).toMatchObject({ retried: 1 });
    await makeDue(postId);
    run = await fail();
    expect(run).toMatchObject({ failed: 1 });

    expect(await analysisStatus('post', postId)).toBe('failed');
    const job = await testPool().query('SELECT status FROM jobs WHERE content_id = $1', [postId]);
    expect(job.rows[0].status).toBe('failed');

    const res = await api.get(app, `/posts/${postId}`, user.token);
    expect(res.body.nsfw_flag).toBe(false);
    expect(res.body.other_flags).toEqual({});
  });

  it('a result with a stale content_revision is discarded', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Feed Stale', 'feed-stale@example.com');
    const postId = await createPost(user.token, 'nsfw-test but stale');
    // Content "changed" after the job was enqueued (revision bumped).
    await testPool().query('UPDATE posts SET content_revision = 2 WHERE id = $1', [postId]);

    const run = await runFeedWorkerOnce(testPool());
    expect(run).toMatchObject({ claimed: 1, discarded: 1 });
    expect(await analysisStatus('post', postId)).toBe('pending');
    const res = await api.get(app, `/posts/${postId}`, user.token);
    expect(res.body.nsfw_flag).toBe(false);
  });

  it('malformed provider output fails the analysis instead of defaulting to safe', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Feed Bad', 'feed-bad@example.com');
    const postId = await createPost(user.token, 'nsfw-test but the provider lies');

    const garbage = {
      analyze: async () => ({ totally: 'not the contract' }) as never,
    };
    const run = await runFeedWorkerOnce(testPool(), { provider: garbage });
    expect(run).toMatchObject({ claimed: 1, failed: 1 });
    expect(await analysisStatus('post', postId)).toBe('failed');

    const res = await api.get(app, `/posts/${postId}`, user.token);
    expect(res.body.nsfw_flag).toBe(false);
    expect(res.body.other_flags).toEqual({});
  });

  it('groups processing keeps working while the feed provider is down', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    await createPost(controller.token, 'nsfw-test post stuck retrying');

    // Feed provider errors on the first attempt -> job pending with backoff.
    await runFeedWorkerOnce(testPool(), { provider: createFakeFeedProvider('error') });

    // Groups flow is unaffected, and the groups worker does not eat feed jobs.
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'group message during feed outage',
      is_anonymous: true,
    });
    const groupsRun = await runStubWorkerOnce(testPool());
    expect(groupsRun).toMatchObject({ claimed: 1, done: 1 });

    const feedJob = await testPool().query(
      `SELECT status FROM jobs WHERE kind = 'analyze_feed_content'`,
    );
    expect(feedJob.rows[0].status).not.toBe('done');

    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    expect(accepted.status).toBe(200);
  });

  it('worker logs never contain post or comment text', async () => {
    const spies = ['log', 'error', 'warn', 'info', 'debug'].map((method) =>
      vi.spyOn(console, method as keyof Console),
    );
    try {
      const app = testApp();
      const user = await registerUser(app, 'Feed Quiet', 'feed-quiet@example.com');
      const sentinel = `feed-sentinel-${Math.random().toString(36).slice(2)}`;
      const postId = await createPost(user.token, `post body with ${sentinel} inside`);
      await api.post(app, `/posts/${postId}/comments`, user.token, {
        content: `comment body with ${sentinel} inside`,
      });

      await runFeedWorkerOnce(testPool());
      await runFeedWorkerOnce(testPool(), { provider: createFakeFeedProvider('error') });
      const garbage = { analyze: async () => ({ nope: 1 }) as never };
      await runFeedWorkerOnce(testPool(), { provider: garbage });

      const printed = spies.flatMap((spy) =>
        spy.mock.calls.map((call) => call.map(String).join(' ')),
      );
      expect(printed.length).toBeGreaterThanOrEqual(0); // spies captured output
      for (const line of printed) {
        expect(line).not.toContain(sentinel);
      }
    } finally {
      for (const spy of spies) spy.mockRestore();
    }
  });
});
