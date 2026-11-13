import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { runFeedWorkerOnce } from '../src/feed-analysis/worker';
import { createFeedProvider } from '../src/feed-analysis/provider';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('feed questions: title and topic (API 42)', () => {
  it('stores and returns title and topic; both optional', async () => {
    const app = testApp();
    const u = await registerUser(app, 'Asker', 'asker@example.com');
    const q = await api.post(app, '/posts', u.token, {
      title: '  How do we estimate spikes?  ',
      topic: 'engineering',
      content: 'Our sprint estimates for research spikes keep slipping.',
    });
    expect(q.status).toBe(201);
    expect(q.body.title).toBe('How do we estimate spikes?');
    expect(q.body.topic).toBe('engineering');

    const plain = await api.post(app, '/posts', u.token, { content: 'Old-style post' });
    expect(plain.status).toBe(201);
    expect(plain.body.title).toBeNull();
    expect(plain.body.topic).toBeNull();

    const list = await api.get(app, '/posts', u.token);
    const fetched = list.body.items.find((p: { id: string }) => p.id === q.body.id);
    expect(fetched).toMatchObject({ title: 'How do we estimate spikes?', topic: 'engineering' });
    const one = await api.get(app, `/posts/${q.body.id}`, u.token);
    expect(one.body.title).toBe('How do we estimate spikes?');
  });

  it('validates title length and topic', async () => {
    const app = testApp();
    const u = await registerUser(app, 'Asker', 'asker@example.com');
    const long = await api.post(app, '/posts', u.token, { title: 'x'.repeat(151), content: 'c' });
    expect(long.status).toBe(422);
    const blank = await api.post(app, '/posts', u.token, { title: '   ', content: 'c' });
    expect(blank.status).toBe(422);
    const topic = await api.post(app, '/posts', u.token, { topic: 'sports', content: 'c' });
    expect(topic.status).toBe(422);
    expect(topic.body.error.message).toContain('listed topics');
  });

  it('a group made from a question uses its title as the agenda', async () => {
    const app = testApp();
    const u = await registerUser(app, 'Asker', 'asker@example.com');
    const q = await api.post(app, '/posts', u.token, {
      title: 'Should retros be anonymous?',
      content: 'Long explanation '.repeat(50),
    });
    const g = await api.post(app, `/posts/${q.body.id}/group`, u.token);
    expect(g.status).toBe(201);
    expect(g.body.agenda).toBe('Should retros be anonymous?');
  });

  it('the content check sees the title too', async () => {
    const app = testApp();
    const u = await registerUser(app, 'Asker', 'asker@example.com');
    // The fake provider flags the keyword "nsfw-test".
    const q = await api.post(app, '/posts', u.token, {
      title: 'nsfw-test in the title only',
      content: 'Perfectly ordinary body.',
    });
    await runFeedWorkerOnce(testPool(), createFeedProvider('fake'));
    const one = await api.get(app, `/posts/${q.body.id}`, u.token);
    expect(one.body.nsfw_flag).toBe(true);
  });
});
