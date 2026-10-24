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

const POST_KEYS = [
  'author',
  'comment_count',
  'content',
  'created_at',
  'id',
  'my_reaction',
  'nsfw_flag',
  'other_flags',
  'reaction_count',
];

async function createPost(
  app: ReturnType<typeof testApp>,
  token: string,
  content: string,
): Promise<string> {
  const res = await api.post(app, '/posts', token, { content });
  if (res.status !== 201) throw new Error(`createPost failed: ${JSON.stringify(res.body)}`);
  return res.body.id as string;
}

describe('posts', () => {
  it('creates a post with the exact Post shape; empty content is 422', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Poster', 'poster@example.com');
    const res = await api.post(app, '/posts', user.token, {
      content: 'How do we label borderline relevance?',
    });
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual(POST_KEYS);
    expect(res.body.author).toEqual({ id: user.id, name: 'Poster' });
    expect(res.body.content).toBe('How do we label borderline relevance?');
    expect(res.body.nsfw_flag).toBe(false);
    expect(res.body.other_flags).toEqual({});
    expect(res.body.reaction_count).toBe(0);
    expect(res.body.comment_count).toBe(0);
    expect(res.body.my_reaction).toBeNull();
    expect(new Date(res.body.created_at).toString()).not.toBe('Invalid Date');

    const empty = await api.post(app, '/posts', user.token, { content: '   ' });
    expect(empty.status).toBe(422);
    expect(empty.body.error.code).toBe('validation');
  });

  it('lists posts newest first and paginates with the cursor', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Poster', 'poster2@example.com');
    // Insert with spaced timestamps so ordering is deterministic.
    for (let i = 0; i < 3; i += 1) {
      await createPost(app, user.token, `ordered post ${i}`);
      await testPool().query(`SELECT pg_sleep(0.01)`);
    }
    const first = await api.get(app, '/posts?limit=2', user.token);
    expect(first.status).toBe(200);
    expect(Object.keys(first.body).sort()).toEqual(['items', 'next_cursor']);
    expect(first.body.items).toHaveLength(2);
    expect(first.body.items[0].content).toBe('ordered post 2');
    expect(typeof first.body.next_cursor).toBe('string');

    const second = await api.get(app, `/posts?limit=2&cursor=${first.body.next_cursor}`, user.token);
    expect(second.body.items).toHaveLength(1);
    expect(second.body.items[0].content).toBe('ordered post 0');
    expect(second.body.next_cursor).toBeNull();
  });

  it('GET /posts/:postId returns the post; unknown and malformed ids are 404', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Poster', 'poster3@example.com');
    const id = await createPost(app, user.token, 'single post');
    const res = await api.get(app, `/posts/${id}`, user.token);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(id);

    expect(
      (await api.get(app, '/posts/00000000-0000-0000-0000-000000000000', user.token)).status,
    ).toBe(404);
    expect((await api.get(app, '/posts/not-a-uuid', user.token)).status).toBe(404);
  });
});

describe('reactions', () => {
  it('is idempotent per user and counts come from rows', async () => {
    const app = testApp();
    const poster = await registerUser(app, 'Poster', 'reaction-poster@example.com');
    const liker = await registerUser(app, 'Liker', 'liker@example.com');
    const other = await registerUser(app, 'Other', 'other-liker@example.com');
    const postId = await createPost(app, poster.token, 'likeable post');

    const first = await api.post(app, `/posts/${postId}/reactions`, liker.token, { type: 'like' });
    expect(first.status).toBe(200);
    expect(Object.keys(first.body).sort()).toEqual(['my_reaction', 'reaction_count']);
    expect(first.body).toEqual({ reaction_count: 1, my_reaction: 'like' });

    const again = await api.post(app, `/posts/${postId}/reactions`, liker.token, { type: 'like' });
    expect(again.body).toEqual({ reaction_count: 1, my_reaction: 'like' });

    await api.post(app, `/posts/${postId}/reactions`, other.token, { type: 'like' });
    const post = await api.get(app, `/posts/${postId}`, liker.token);
    expect(post.body.reaction_count).toBe(2);
    expect(post.body.my_reaction).toBe('like');

    const removed = await api.del(app, `/posts/${postId}/reactions`, liker.token);
    expect(removed.body).toEqual({ reaction_count: 1, my_reaction: null });
    const removedAgain = await api.del(app, `/posts/${postId}/reactions`, liker.token);
    expect(removedAgain.body).toEqual({ reaction_count: 1, my_reaction: null });
  });

  it('only type "like" is accepted; unknown post 404', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Poster', 'reaction-poster2@example.com');
    const postId = await createPost(app, user.token, 'strict post');

    const badType = await api.post(app, `/posts/${postId}/reactions`, user.token, {
      type: 'heart',
    });
    expect(badType.status).toBe(422);
    expect(badType.body.error.message).toContain('like');

    expect(
      (
        await api.post(app, '/posts/00000000-0000-0000-0000-000000000000/reactions', user.token, {
          type: 'like',
        })
      ).status,
    ).toBe(404);
    expect(
      (await api.del(app, '/posts/00000000-0000-0000-0000-000000000000/reactions', user.token))
        .status,
    ).toBe(404);
  });
});

describe('comments', () => {
  it('creates comments and lists them oldest first; empty content 422; unknown post 404', async () => {
    const app = testApp();
    const poster = await registerUser(app, 'Poster', 'comment-poster@example.com');
    const commenter = await registerUser(app, 'Commenter', 'commenter@example.com');
    const postId = await createPost(app, poster.token, 'commentable post');

    const created = await api.post(app, `/posts/${postId}/comments`, commenter.token, {
      content: 'first comment',
    });
    expect(created.status).toBe(201);
    expect(Object.keys(created.body).sort()).toEqual([
      'author',
      'content',
      'created_at',
      'id',
      'nsfw_flag',
      'other_flags',
      'post_id',
    ]);
    expect(created.body.post_id).toBe(postId);
    expect(created.body.author).toEqual({ id: commenter.id, name: 'Commenter' });
    expect(created.body.nsfw_flag).toBe(false);
    expect(created.body.other_flags).toEqual({});

    await api.post(app, `/posts/${postId}/comments`, poster.token, { content: 'second comment' });
    const empty = await api.post(app, `/posts/${postId}/comments`, poster.token, { content: ' ' });
    expect(empty.status).toBe(422);

    const list = await api.get(app, `/posts/${postId}/comments`, poster.token);
    expect(list.body.items.map((c: { content: string }) => c.content)).toEqual([
      'first comment',
      'second comment',
    ]);

    const post = await api.get(app, `/posts/${postId}`, poster.token);
    expect(post.body.comment_count).toBe(2);

    expect(
      (
        await api.post(app, '/posts/00000000-0000-0000-0000-000000000000/comments', poster.token, {
          content: 'x',
        })
      ).status,
    ).toBe(404);
  });

  it('paginates comments oldest first with the cursor', async () => {
    const app = testApp();
    const poster = await registerUser(app, 'Poster', 'comment-pager@example.com');
    const postId = await createPost(app, poster.token, 'paginated post');
    for (let i = 0; i < 3; i += 1) {
      await api.post(app, `/posts/${postId}/comments`, poster.token, { content: `c${i}` });
      await testPool().query(`SELECT pg_sleep(0.01)`);
    }
    const first = await api.get(app, `/posts/${postId}/comments?limit=2`, poster.token);
    expect(first.body.items.map((c: { content: string }) => c.content)).toEqual(['c0', 'c1']);
    const second = await api.get(
      app,
      `/posts/${postId}/comments?limit=2&cursor=${first.body.next_cursor}`,
      poster.token,
    );
    expect(second.body.items.map((c: { content: string }) => c.content)).toEqual(['c2']);
    expect(second.body.next_cursor).toBeNull();
  });
});

describe('post to group conversion', () => {
  it('the post author creates a group whose agenda is the post content', async () => {
    const app = testApp();
    const author = await registerUser(app, 'Author', 'group-author@example.com');
    const postId = await createPost(app, author.token, 'Should we split preprocessing notes?');

    const res = await api.post(app, `/posts/${postId}/group`, author.token);
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual([
      'agenda',
      'controller_id',
      'created_at',
      'id',
      'my_role',
      'pending_count',
      'source_post_id',
    ]);
    expect(res.body.agenda).toBe('Should we split preprocessing notes?');
    expect(res.body.source_post_id).toBe(postId);
    expect(res.body.controller_id).toBe(author.id);
    expect(res.body.my_role).toBe('controller');
    expect(res.body.pending_count).toBe(0);

    const groups = await api.get(app, '/groups', author.token);
    expect(groups.body.items).toHaveLength(1);
    expect(groups.body.items[0].id).toBe(res.body.id);
  });

  it('a second conversion is 409; non-authors get 403; unknown post 404', async () => {
    const app = testApp();
    const author = await registerUser(app, 'Author', 'group-author2@example.com');
    const other = await registerUser(app, 'Other', 'group-other@example.com');
    const postId = await createPost(app, author.token, 'Convert me once');

    expect((await api.post(app, `/posts/${postId}/group`, author.token)).status).toBe(201);
    const second = await api.post(app, `/posts/${postId}/group`, author.token);
    expect(second.status).toBe(409);
    expect(second.body.error.message).toContain('already been created');

    expect((await api.post(app, `/posts/${postId}/group`, other.token)).status).toBe(403);
    expect(
      (
        await api.post(app, '/posts/00000000-0000-0000-0000-000000000000/group', author.token)
      ).status,
    ).toBe(404);
  });
});
