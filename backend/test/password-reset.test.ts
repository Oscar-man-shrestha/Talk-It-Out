import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { memoryOutbox } from '../src/mailer';
import { RESET_MAX_ATTEMPTS } from '../src/routes/passwordReset';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(async () => {
  await resetDb();
  memoryOutbox.length = 0;
});
afterAll(closePool);

const app = () => testApp({ mailTransport: 'memory' });

/** Waits for the fire-and-forget mail and returns the code in it. */
async function codeFor(email: string): Promise<string> {
  for (let i = 0; i < 50; i++) {
    const mail = memoryOutbox.find((m) => m.to === email);
    if (mail) return /(\d{6})/.exec(mail.text)![1];
    await new Promise((r) => setTimeout(r, 10));
  }
  throw new Error(`no reset mail for ${email}`);
}

const request = (a: ReturnType<typeof testApp>, email: string) =>
  api.post(a, '/auth/password-reset', undefined, { email });
const confirm = (a: ReturnType<typeof testApp>, body: object) =>
  api.post(a, '/auth/password-reset/confirm', undefined, body);

describe('password reset', () => {
  it('emails a code that sets a new password and revokes refresh tokens', async () => {
    const a = app();
    const user = await registerUser(a, 'P', 'p@example.com', 'old-password');
    const issued = await api.post(a, '/auth/refresh-tokens', user.token);

    const res = await request(a, 'P@Example.com');
    expect(res.status).toBe(202);
    expect(res.body).toEqual({ status: 'sent', expires_in_minutes: 15 });
    const code = await codeFor('p@example.com');
    expect(memoryOutbox[0].subject).toMatch(/reset code/i);
    expect(memoryOutbox[0].html).toContain(`>${code[0]}</td>`);
    expect(memoryOutbox[0].html).toContain('Hi P,');

    const done = await confirm(a, { email: 'p@example.com', code, new_password: 'new-password' });
    expect(done.status).toBe(204);

    const oldLogin = await api.post(a, '/auth/login', undefined, {
      email: 'p@example.com',
      password: 'old-password',
    });
    expect(oldLogin.status).toBe(401);
    const newLogin = await api.post(a, '/auth/login', undefined, {
      email: 'p@example.com',
      password: 'new-password',
    });
    expect(newLogin.status).toBe(200);

    const refresh = await api.post(a, '/auth/refresh', undefined, {
      refresh_token: issued.body.refresh_token,
    });
    expect(refresh.status).toBe(401);

    // A code works once.
    const again = await confirm(a, { email: 'p@example.com', code, new_password: 'third-pass' });
    expect(again.status).toBe(400);
  });

  it('says so for an unknown email and sends nothing', async () => {
    const a = app();
    const res = await request(a, 'nobody@example.com');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('no_account');
    expect(memoryOutbox).toHaveLength(0);
    const bad = await confirm(a, {
      email: 'nobody@example.com',
      code: '123456',
      new_password: 'whatever1',
    });
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('invalid_code');
  });

  it('stores only a hash of the code', async () => {
    const a = app();
    await registerUser(a, 'P', 'p@example.com');
    await request(a, 'p@example.com');
    const code = await codeFor('p@example.com');
    const { rows } = await testPool().query('SELECT code_hash FROM password_resets');
    expect(rows).toHaveLength(1);
    expect(rows[0].code_hash).not.toContain(code);
    expect(rows[0].code_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it(`kills a code after ${RESET_MAX_ATTEMPTS} wrong attempts`, async () => {
    const a = app();
    await registerUser(a, 'P', 'p@example.com');
    await request(a, 'p@example.com');
    const code = await codeFor('p@example.com');
    const wrong = code === '000000' ? '111111' : '000000';
    for (let i = 0; i < RESET_MAX_ATTEMPTS; i++) {
      const res = await confirm(a, { email: 'p@example.com', code: wrong, new_password: 'xxxxxxxx' });
      expect(res.status).toBe(400);
    }
    const right = await confirm(a, { email: 'p@example.com', code, new_password: 'new-password' });
    expect(right.status).toBe(400);
  });

  it('rejects expired codes and voids older codes on a new request', async () => {
    const a = app();
    await registerUser(a, 'P', 'p@example.com');
    await request(a, 'p@example.com');
    const first = await codeFor('p@example.com');
    memoryOutbox.length = 0;
    // A second request within a minute is refused...
    const soon = await request(a, 'p@example.com');
    expect(soon.status).toBe(429);
    expect(soon.body.error.code).toBe('too_soon');
    // ...after that it replaces the old code.
    await testPool().query("UPDATE password_resets SET created_at = now() - interval '2 minutes'");
    await request(a, 'p@example.com');
    const second = await codeFor('p@example.com');
    if (first !== second) {
      const old = await confirm(a, { email: 'p@example.com', code: first, new_password: 'xxxxxxxx' });
      expect(old.status).toBe(400);
    }
    await testPool().query("UPDATE password_resets SET expires_at = now() - interval '1 second'");
    const expired = await confirm(a, {
      email: 'p@example.com',
      code: second,
      new_password: 'new-password',
    });
    expect(expired.status).toBe(400);
  });

  it('validates input', async () => {
    const a = app();
    expect((await request(a, 'not-an-email')).status).toBe(422);
    const short = await confirm(a, { email: 'p@example.com', code: '123456', new_password: 'short' });
    expect(short.status).toBe(422);
    const badCode = await confirm(a, { email: 'p@example.com', code: '12ab56', new_password: 'longenough' });
    expect(badCode.status).toBe(422);
  });

  it('is 503 when email is not configured', async () => {
    const a = testApp({ mailTransport: 'disabled' });
    const res = await request(a, 'p@example.com');
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('email_not_configured');
  });

  it('works under /api/v1', async () => {
    const a = app();
    await registerUser(a, 'P', 'p@example.com');
    const res = await api.post(a, '/api/v1/auth/password-reset', undefined, {
      email: 'p@example.com',
    });
    expect(res.status).toBe(202);
  });
});

describe('three-step reset: code first, then new password', () => {
  const verify = (a: ReturnType<typeof testApp>, body: object) =>
    api.post(a, '/auth/password-reset/verify', undefined, body);

  it('a correct code returns a one-time token that sets the password', async () => {
    const a = app();
    await registerUser(a, 'Priya Shah', 'p@example.com', 'old-password');
    await request(a, 'p@example.com');
    const code = await codeFor('p@example.com');
    const wrong = code === '000000' ? '111111' : '000000';

    const miss = await verify(a, { email: 'p@example.com', code: wrong });
    expect(miss.status).toBe(400);
    expect(miss.body.error.message).toMatch(/4 tries left/);

    const ok = await verify(a, { email: 'p@example.com', code });
    expect(ok.status).toBe(200);
    expect(ok.body.reset_token).toMatch(/^[0-9a-f]{64}$/);
    const { rows } = await testPool().query('SELECT verify_token_hash FROM password_resets');
    expect(rows[0].verify_token_hash).not.toContain(ok.body.reset_token);

    const badToken = await confirm(a, {
      email: 'p@example.com',
      reset_token: 'f'.repeat(64),
      new_password: 'new-password',
    });
    expect(badToken.status).toBe(400);

    const done = await confirm(a, {
      email: 'p@example.com',
      reset_token: ok.body.reset_token,
      new_password: 'new-password',
    });
    expect(done.status).toBe(204);
    const login = await api.post(a, '/auth/login', undefined, {
      email: 'p@example.com',
      password: 'new-password',
    });
    expect(login.status).toBe(200);
    // The token works once.
    const again = await confirm(a, {
      email: 'p@example.com',
      reset_token: ok.body.reset_token,
      new_password: 'third-password',
    });
    expect(again.status).toBe(400);
  });

  it('needs a code or a token, and a well-formed one', async () => {
    const a = app();
    expect((await confirm(a, { email: 'p@example.com', new_password: 'longenough' })).status).toBe(422);
    expect((await verify(a, { email: 'p@example.com', code: '12' })).status).toBe(422);
    expect((await verify(a, { email: 'p@example.com', code: '123456' })).status).toBe(400);
  });

  it('reports a delivery failure instead of pretending it was sent', async () => {
    const a = testApp({ mailTransport: 'smtp', smtpUrl: 'smtp://127.0.0.1:1', smtpHost: '', smtpUser: '', smtpPass: '' });
    await registerUser(a, 'P', 'p@example.com');
    const res = await request(a, 'p@example.com');
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('email_failed');
    const { rows } = await testPool().query('SELECT count(*)::int AS n FROM password_resets');
    expect(rows[0].n).toBe(0);
  });
});

describe('mail configuration', () => {
  // Start from the real environment minus any local mail settings, so a
  // developer's own SMTP details in backend/.env cannot change the outcome.
  const base = {
    ...process.env,
    NODE_ENV: 'test',
    SMTP_URL: '',
    SMTP_HOST: '',
    SMTP_USER: '',
    SMTP_PASS: '',
    MAIL_FROM: '',
  } as NodeJS.ProcessEnv;
  it('defaults to disabled and accepts smtp with a URL', async () => {
    const { loadConfig } = await import('../src/config');
    expect(loadConfig({ ...base, MAIL_TRANSPORT: '' }).mailTransport).toBe('disabled');
    const smtp = loadConfig({ ...base, MAIL_TRANSPORT: 'smtp', SMTP_URL: 'smtp://localhost:2525' });
    expect(smtp.mailTransport).toBe('smtp');
    expect(smtp.mailFrom).toContain('Talk It Out');
  });
  it('accepts Gmail-style host/user/pass settings', async () => {
    const { loadConfig } = await import('../src/config');
    const gmail = loadConfig({
      ...base,
      MAIL_TRANSPORT: 'smtp',
      SMTP_URL: '',
      SMTP_HOST: 'smtp.gmail.com',
      SMTP_USER: 'oscar@gmail.com',
      SMTP_PASS: 'abcd efgh ijkl mnop',
      MAIL_FROM: '',
    });
    expect(gmail.smtpHost).toBe('smtp.gmail.com');
    expect(gmail.smtpPort).toBe(465);
    expect(gmail.smtpPass).toBe('abcdefghijklmnop');
    expect(gmail.mailFrom).toBe('Talk It Out <oscar@gmail.com>');
    expect(() =>
      loadConfig({ ...base, MAIL_TRANSPORT: 'smtp', SMTP_URL: '', SMTP_HOST: 'h', SMTP_USER: 'u', SMTP_PASS: '' }),
    ).toThrow(/SMTP_PASS/);
  });
  it('refuses unsafe or incomplete settings', async () => {
    const { loadConfig } = await import('../src/config');
    expect(() => loadConfig({ ...base, MAIL_TRANSPORT: 'smtp', SMTP_URL: '' })).toThrow(/SMTP_URL/);
    expect(() => loadConfig({ ...base, MAIL_TRANSPORT: 'carrier-pigeon' })).toThrow();
    const prod = {
      ...base,
      NODE_ENV: 'production',
      JWT_SECRET: 'x'.repeat(40),
      PIPELINE_API_KEY: '',
    } as NodeJS.ProcessEnv;
    expect(() => loadConfig({ ...prod, MAIL_TRANSPORT: 'log' })).toThrow(/production/);
    expect(() => loadConfig({ ...prod, MAIL_TRANSPORT: 'memory' })).toThrow(/tests only/);
  });
});
