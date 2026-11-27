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
  'best_comment_id',
  'comment_count',
  'content',
  'created_at',
  'edited_at',
  'following',
  'id',
  'my_reaction',
  'nsfw_flag',
  'other_flags',
  'reaction_count',
  'title',
  'topic',
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
    expect(res.body.author).toEqual({ id: user.id, name: 'Poster', premium: false });
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
      'edited_at',
      'id',
      'is_best',
      'nsfw_flag',
      'other_flags',
      'post_id',
      'report_count',
      'reported_by_me',
      'vote_count',
      'voted_by_me',
    ]);
    expect(created.body.post_id).toBe(postId);
    expect(created.body.author).toEqual({ id: commenter.id, name: 'Commenter', premium: false });
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
      'description',
      'id',
      'member_count',
      'muted',
      'my_role',
      'pending_count',
      'pinned',
      'rules',
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

describe('feed filters (API.md 70)', () => {
  it('filters by topic in the database, including untagged posts by keyword', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Poster', 'filters1@example.com');
    const tagged = await api.post(app, '/posts', user.token, {
      content: 'How should we size sprint work?',
      topic: 'engineering',
    });
    expect(tagged.status).toBe(201);
    const untagged = await createPost(app, user.token, 'The NLP pipeline needs a review');
    await createPost(app, user.token, 'Where is the offsite this year?');
    await api.post(app, '/posts', user.token, { content: 'Raise bands?', topic: 'compensation' });

    const res = await api.get(app, '/posts?topic=engineering', user.token);
    expect(res.status).toBe(200);
    expect(res.body.items.map((p: { id: string }) => p.id).sort()).toEqual(
      [tagged.body.id, untagged].sort(),
    );

    const bad = await api.get(app, '/posts?topic=gossip', user.token);
    expect(bad.status).toBe(422);
  });

  it('filters by answered state and keeps cursor paging within the filter', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Poster', 'filters2@example.com');
    const other = await registerUser(app, 'Answerer', 'filters3@example.com');
    const ids: string[] = [];
    for (let i = 0; i < 4; i += 1) {
      ids.push(await createPost(app, user.token, `question ${i}`));
      await testPool().query(`SELECT pg_sleep(0.01)`);
    }
    // question 1: one answer; question 3: two answers.
    await api.post(app, `/posts/${ids[1]}/comments`, other.token, { content: 'one' });
    await api.post(app, `/posts/${ids[3]}/comments`, other.token, { content: 'a' });
    await api.post(app, `/posts/${ids[3]}/comments`, user.token, { content: 'b' });

    const contents = (body: { items: { content: string }[] }) =>
      body.items.map((p) => p.content);

    const unanswered = await api.get(app, '/posts?filter=unanswered', user.token);
    expect(contents(unanswered.body)).toEqual(['question 2', 'question 0']);

    const answered = await api.get(app, '/posts?filter=answered', user.token);
    expect(contents(answered.body)).toEqual(['question 3', 'question 1']);

    const discussed = await api.get(app, '/posts?filter=discussed', user.token);
    expect(contents(discussed.body)).toEqual(['question 3']);

    const page1 = await api.get(app, '/posts?filter=unanswered&limit=1', user.token);
    expect(contents(page1.body)).toEqual(['question 2']);
    const page2 = await api.get(
      app,
      `/posts?filter=unanswered&limit=1&cursor=${page1.body.next_cursor}`,
      user.token,
    );
    expect(contents(page2.body)).toEqual(['question 0']);
    expect(page2.body.next_cursor).toBeNull();

    expect((await api.get(app, '/posts?filter=popular', user.token)).status).toBe(422);
  });
});
