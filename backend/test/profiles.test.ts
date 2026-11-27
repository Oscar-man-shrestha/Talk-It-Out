import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import supertest from 'supertest';
import { sniffImageType } from '../src/routes/profiles';
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

const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(32, 1),
]);
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(32, 2)]);

const put = (app: ReturnType<typeof testApp>, path: string, token: string, body: unknown) =>
  supertest(app).put(path).set({ Authorization: `Bearer ${token}` }).send(body as object);

describe('profiles', () => {
  it('a new user has a blank profile; email only on your own', async () => {
    const app = testApp();
    const priya = await registerUser(app, 'Priya', 'priya@example.com');
    const maya = await registerUser(app, 'Maya', 'maya@example.com');

    const own = await api.get(app, '/users/me/profile', priya.token);
    expect(own.status).toBe(200);
    expect(Object.keys(own.body).sort()).toEqual(['educations', 'experiences', 'user']);
    expect(own.body.user).toMatchObject({
      id: priya.id,
      name: 'Priya',
      email: 'priya@example.com',
      headline: '',
      skills: [],
      avatar_url: null,
      cover_url: null,
    });
    expect(own.body.experiences).toEqual([]);

    const other = await api.get(app, `/users/${priya.id}/profile`, maya.token);
    expect(other.status).toBe(200);
    expect(other.body.user.name).toBe('Priya');
    expect(other.body.user).not.toHaveProperty('email');
    expect(JSON.stringify(other.body)).not.toContain('priya@example.com');
  });

  it('requires auth and 404s unknown ids', async () => {
    const app = testApp();
    const user = await registerUser(app, 'U', 'u@example.com');
    expect((await api.get(app, '/users/me/profile')).status).toBe(401);
    const missing = await api.get(
      app,
      '/users/00000000-0000-4000-8000-000000000000/profile',
      user.token,
    );
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('not_found');
    expect((await api.get(app, '/users/not-a-uuid/profile', user.token)).status).toBe(404);
  });

  it('updates fields partially, renames the user, and de-duplicates skills', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Old Name', 'p@example.com');
    const res = await put(app, '/users/me/profile', user.token, {
      name: 'New Name',
      headline: 'Engineer',
      skills: ['Go', 'go', 'Rust'],
    });
    expect(res.status).toBe(200);
    expect(res.body.user).toMatchObject({
      name: 'New Name',
      headline: 'Engineer',
      bio: '',
      skills: ['Go', 'Rust'],
    });
    const second = await put(app, '/users/me/profile', user.token, { bio: 'Hi' });
    expect(second.body.user).toMatchObject({ headline: 'Engineer', bio: 'Hi' });
    // /me reflects the new name.
    const me = await api.get(app, '/me', user.token);
    expect(me.body.name).toBe('New Name');
  });

  it('rejects unknown fields and invalid values with the 422 envelope', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const unknown = await put(app, '/users/me/profile', user.token, { email: 'x@y.z' });
    expect(unknown.status).toBe(422);
    expect(unknown.body.error.code).toBe('validation');
    const tooLong = await put(app, '/users/me/profile', user.token, {
      headline: 'x'.repeat(201),
    });
    expect(tooLong.status).toBe(422);
    const blankName = await put(app, '/users/me/profile', user.token, { name: '  ' });
    expect(blankName.status).toBe(422);
  });

  it('experience CRUD with date rules and ownership', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const other = await registerUser(app, 'O', 'o@example.com');

    const created = await api.post(app, '/users/me/experiences', user.token, {
      title: 'Engineer',
      company: 'Acme',
      start_date: '2023-01-01',
      is_current: true,
    });
    expect(created.status).toBe(201);
    expect(created.body).toEqual({
      id: expect.any(String),
      title: 'Engineer',
      company: 'Acme',
      location: '',
      start_date: '2023-01-01',
      end_date: null,
      is_current: true,
      description: '',
    });

    const bad = await api.post(app, '/users/me/experiences', user.token, {
      title: 'X',
      company: 'Y',
      start_date: '2023-05-01',
      end_date: '2023-01-01',
    });
    expect(bad.status).toBe(422);
    const currentWithEnd = await api.post(app, '/users/me/experiences', user.token, {
      title: 'X',
      company: 'Y',
      start_date: '2023-01-01',
      end_date: '2023-02-01',
      is_current: true,
    });
    expect(currentWithEnd.status).toBe(422);

    const id = created.body.id;
    const updated = await put(app, `/users/me/experiences/${id}`, user.token, {
      title: 'Lead',
      company: 'Acme',
      start_date: '2023-01-01',
      end_date: '2024-06-30',
    });
    expect(updated.status).toBe(200);
    expect(updated.body).toMatchObject({ title: 'Lead', end_date: '2024-06-30', is_current: false });

    // Another user can neither edit nor delete it.
    const stolen = await put(app, `/users/me/experiences/${id}`, other.token, {
      title: 'Hacked',
      company: 'Acme',
      start_date: '2023-01-01',
    });
    expect(stolen.status).toBe(404);
    expect((await api.del(app, `/users/me/experiences/${id}`, other.token)).status).toBe(404);

    const profile = await api.get(app, `/users/${user.id}/profile`, other.token);
    expect(profile.body.experiences).toHaveLength(1);

    expect((await api.del(app, `/users/me/experiences/${id}`, user.token)).status).toBe(204);
    expect((await api.del(app, `/users/me/experiences/${id}`, user.token)).status).toBe(404);
  });

  it('education CRUD with year rules', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const created = await api.post(app, '/users/me/educations', user.token, {
      school: 'Berkeley',
      degree: 'B.S.',
      start_year: 2016,
      end_year: 2020,
    });
    expect(created.status).toBe(201);
    expect(created.body).toEqual({
      id: expect.any(String),
      school: 'Berkeley',
      degree: 'B.S.',
      field_of_study: '',
      start_year: 2016,
      end_year: 2020,
    });
    const bad = await api.post(app, '/users/me/educations', user.token, {
      school: 'X',
      start_year: 2020,
      end_year: 2010,
    });
    expect(bad.status).toBe(422);
    const updated = await put(app, `/users/me/educations/${created.body.id}`, user.token, {
      school: 'UC Berkeley',
    });
    expect(updated.body).toMatchObject({ school: 'UC Berkeley', start_year: null });
    expect(
      (await api.del(app, `/users/me/educations/${created.body.id}`, user.token)).status,
    ).toBe(204);
  });
});

describe('profile images', () => {
  it('sniffs image types from bytes, not headers', () => {
    expect(sniffImageType(PNG)).toBe('image/png');
    expect(sniffImageType(JPEG)).toBe('image/jpeg');
    const webp = Buffer.concat([
      Buffer.from('RIFF'),
      Buffer.alloc(4),
      Buffer.from('WEBP'),
      Buffer.alloc(8),
    ]);
    expect(sniffImageType(webp)).toBe('image/webp');
    expect(sniffImageType(Buffer.from('<svg onload=alert(1)>'))).toBeNull();
  });

  it('uploads an avatar, serves it publicly with its real type, and replaces it', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');

    const first = await supertest(app)
      .post('/users/me/avatar')
      .set({ Authorization: `Bearer ${user.token}` })
      // Lies about the type; the server sniffs PNG.
      .attach('file', PNG, { filename: 'a.jpg', contentType: 'image/jpeg' });
    expect(first.status).toBe(201);
    expect(first.body.url).toMatch(/\/media\/[0-9a-f-]{36}$/);
    const path = new URL(first.body.url).pathname;

    const served = await supertest(app).get(path);
    expect(served.status).toBe(200);
    expect(served.headers['content-type']).toBe('image/png');
    expect(served.headers['cross-origin-resource-policy']).toBe('cross-origin');
    expect(served.headers['x-content-type-options']).toBe('nosniff');
    expect(Buffer.compare(served.body as Buffer, PNG)).toBe(0);

    const profile = await api.get(app, '/users/me/profile', user.token);
    expect(new URL(profile.body.user.avatar_url).pathname).toBe(path);

    const second = await supertest(app)
      .post('/users/me/avatar')
      .set({ Authorization: `Bearer ${user.token}` })
      .attach('file', JPEG, 'b.jpg');
    expect(second.status).toBe(201);
    // Only the latest avatar is kept.
    expect((await supertest(app).get(path)).status).toBe(404);
    const { rows } = await testPool().query(
      "SELECT count(*)::int AS n FROM media WHERE owner_id = $1 AND kind = 'avatar'",
      [user.id],
    );
    expect(rows[0].n).toBe(1);

    expect((await api.del(app, '/users/me/avatar', user.token)).status).toBe(204);
    const cleared = await api.get(app, '/users/me/profile', user.token);
    expect(cleared.body.user.avatar_url).toBeNull();
  });

  it('works under /api/v1 and builds URLs with that prefix', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const res = await supertest(app)
      .post('/api/v1/users/me/cover')
      .set({ Authorization: `Bearer ${user.token}` })
      .attach('file', PNG, 'c.png');
    expect(res.status).toBe(201);
    expect(new URL(res.body.url).pathname).toMatch(/^\/api\/v1\/media\//);
    expect((await supertest(app).get(new URL(res.body.url).pathname)).status).toBe(200);
  });

  it('rejects non-images, oversize files, missing files, and anonymous callers', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const auth = { Authorization: `Bearer ${user.token}` };

    const html = await supertest(app)
      .post('/users/me/avatar')
      .set(auth)
      .attach('file', Buffer.from('<html>hi</html>'), { filename: 'x.png', contentType: 'image/png' });
    expect(html.status).toBe(415);
    expect(html.body.error.code).toBe('unsupported_media_type');

    const big = await supertest(app)
      .post('/users/me/avatar')
      .set(auth)
      .attach('file', Buffer.concat([PNG, Buffer.alloc(2 * 1024 * 1024)]), 'big.png');
    expect(big.status).toBe(413);
    expect(big.body.error.code).toBe('file_too_large');

    const none = await supertest(app).post('/users/me/avatar').set(auth).send({});
    expect(none.status).toBe(422);

    const wrongField = await supertest(app)
      .post('/users/me/avatar')
      .set(auth)
      .attach('image', PNG, 'a.png');
    expect(wrongField.status).toBe(422);

    const anon = await supertest(app).post('/users/me/avatar').attach('file', PNG, 'a.png');
    expect(anon.status).toBe(401);

    expect((await supertest(app).get('/media/not-a-uuid')).status).toBe(404);
  });
});
