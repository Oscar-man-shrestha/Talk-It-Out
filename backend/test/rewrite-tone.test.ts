import supertest from 'supertest';
import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import {
  api,
  closePool,
  ensureSchema,
  resetDb,
  seedGroup,
  testApp,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const KEY = 'tone-test-key';
const withKey = { 'X-Pipeline-Key': KEY, 'Content-Type': 'application/json' };

describe('rewrite tone (migration 013)', () => {
  it('is private, defaults to professional and can be changed', async () => {
    const app = testApp();
    const { controller, contributor } = await seedGroup(app);
    const mine = await api.get(app, '/users/me/profile', contributor.token);
    expect(mine.body.user.rewrite_tone).toBe('professional');

    const put = await api.put(app, '/users/me/profile', contributor.token, {
      rewrite_tone: 'empathetic',
    });
    expect(put.status).toBe(200);
    expect(put.body.user.rewrite_tone).toBe('empathetic');

    // Someone else's view of the profile never shows it.
    const theirs = await api.get(app, `/users/${contributor.id}/profile`, controller.token);
    expect(theirs.body.user).not.toHaveProperty('rewrite_tone');

    const bad = await api.put(app, '/users/me/profile', contributor.token, {
      rewrite_tone: 'sarcastic',
    });
    expect(bad.status).toBe(422);
  });

  it('named messages carry the author\'s tone to the worker; anonymous ones get the default', async () => {
    const app = testApp({ pipelineApiKey: KEY, runStubWorker: false });
    const { contributor, groupId } = await seedGroup(app);
    await api.put(app, '/users/me/profile', contributor.token, { rewrite_tone: 'direct' });
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'named message about the rota',
      is_anonymous: false,
    });
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'anonymous message about the rota',
      is_anonymous: true,
    });
    const res = await supertest(app)
      .post('/internal/pipeline/claim')
      .set(withKey)
      .send('{"max_jobs":5}');
    expect(res.status).toBe(200);
    const byText = Object.fromEntries(
      (res.body.jobs as { text: string; tone: string | null }[]).map((j) => [j.text, j.tone]),
    );
    expect(byText['named message about the rota']).toBe('direct');
    expect(byText['anonymous message about the rota']).toBe('professional');
  });
});
