import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import {
  api,
  closePool,
  ensureSchema,
  registerUser,
  resetDb,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

async function setup() {
  const app = testApp();
  const asker = await registerUser(app, 'Asker', 'asker@example.com');
  const commenter = await registerUser(app, 'Commenter', 'commenter@example.com');
  const reader = await registerUser(app, 'Reader', 'reader@example.com');
  const post = await api.post(app, '/posts', asker.token, {
    title: 'How do we share feedback on the rota?',
    topic: 'culture',
    content: 'Looking for ideas on giving feedback about the rota.',
  });
  expect(post.status).toBe(201);
  const postId = post.body.id as string;
  const comment = await api.post(app, `/posts/${postId}/comments`, commenter.token, {
    content: 'We use a short retro every Friday.',
  });
  expect(comment.status).toBe(201);
  return { app, asker, commenter, reader, postId, commentId: comment.body.id as string };
}

describe('comment reports', () => {
  it('a reader can report once; only the question author sees the count', async () => {
    const { app, asker, commenter, reader, postId, commentId } = await setup();
    const path = `/posts/${postId}/comments/${commentId}/report`;
    expect((await api.post(app, path, reader.token)).status).toBe(204);
    expect((await api.post(app, path, reader.token)).status).toBe(204); // idempotent

    const forReader = await api.get(app, `/posts/${postId}/comments`, reader.token);
    expect(forReader.body.items[0].reported_by_me).toBe(true);
    expect(forReader.body.items[0].report_count).toBeNull();

    const forAsker = await api.get(app, `/posts/${postId}/comments`, asker.token);
    expect(forAsker.body.items[0].report_count).toBe(1);
    expect(forAsker.body.items[0].reported_by_me).toBe(false);

    // Nothing is hidden by a report.
    const forCommenter = await api.get(app, `/posts/${postId}/comments`, commenter.token);
    expect(forCommenter.body.items).toHaveLength(1);

    // Withdraw.
    expect((await api.del(app, path, reader.token)).status).toBe(204);
    const again = await api.get(app, `/posts/${postId}/comments`, asker.token);
    expect(again.body.items[0].report_count).toBe(0);
  });

  it('you cannot report your own comment; unknown ids are 404', async () => {
    const { app, commenter, reader, postId, commentId } = await setup();
    const own = await api.post(app, `/posts/${postId}/comments/${commentId}/report`, commenter.token);
    expect(own.status).toBe(400);
    expect(own.body.error.code).toBe('own_comment');
    const missing = await api.post(
      app,
      `/posts/${postId}/comments/00000000-0000-4000-8000-000000000000/report`,
      reader.token,
    );
    expect(missing.status).toBe(404);
  });
});

describe('removing a comment', () => {
  it('the comment author or the question author may remove it; others may not', async () => {
    const { app, asker, commenter, reader, postId, commentId } = await setup();
    const path = `/posts/${postId}/comments/${commentId}`;
    expect((await api.del(app, path, reader.token)).status).toBe(403);
    expect((await api.del(app, path, asker.token)).status).toBe(204);
    expect((await api.get(app, `/posts/${postId}/comments`, reader.token)).body.items).toEqual([]);

    const second = await api.post(app, `/posts/${postId}/comments`, commenter.token, {
      content: 'Another idea: anonymous suggestion box.',
    });
    await api.post(app, `/posts/${postId}/comments/${second.body.id}/report`, reader.token);
    expect((await api.del(app, `/posts/${postId}/comments/${second.body.id}`, commenter.token)).status).toBe(
      204,
    );
    const { rows } = await testPool().query(
      `SELECT
         (SELECT count(*)::int FROM comment_reports) AS reports,
         (SELECT count(*)::int FROM jobs
          WHERE kind = 'analyze_feed_content' AND content_type = 'comment') AS jobs`,
    );
    expect(rows[0]).toEqual({ reports: 0, jobs: 0 });
  });
});

describe('deleting a question', () => {
  it('only its author may delete it; likes, comments and reports go with it', async () => {
    const { app, asker, reader, postId, commentId } = await setup();
    await api.post(app, `/posts/${postId}/reactions`, reader.token, { type: 'like' });
    await api.post(app, `/posts/${postId}/comments/${commentId}/report`, reader.token);
    const group = await api.post(app, `/posts/${postId}/group`, asker.token);
    expect(group.status).toBe(201);

    expect((await api.del(app, `/posts/${postId}`, reader.token)).status).toBe(403);
    expect((await api.del(app, `/posts/${postId}`, asker.token)).status).toBe(204);
    expect((await api.get(app, `/posts/${postId}`, reader.token)).status).toBe(404);
    expect((await api.del(app, `/posts/${postId}`, asker.token)).status).toBe(404);

    const { rows } = await testPool().query(
      `SELECT (SELECT count(*)::int FROM comments) AS comments,
              (SELECT count(*)::int FROM post_likes) AS likes,
              (SELECT count(*)::int FROM comment_reports) AS reports,
              (SELECT count(*)::int FROM jobs WHERE kind = 'analyze_feed_content') AS jobs,
              (SELECT source_post_id FROM groups WHERE id = $1) AS source`,
      [group.body.id],
    );
    expect(rows[0]).toEqual({ comments: 0, likes: 0, reports: 0, jobs: 0, source: null });
  });
});
