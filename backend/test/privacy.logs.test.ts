/**
 * Privacy: nothing the server prints may contain raw message text (or
 * credentials or tokens). We spy on every console method across a full
 * request path and assert a unique sentinel never appears.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
import {
  api,
  closePool,
  ensureSchema,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const SENTINEL = `SENTINEL-raw-${Math.random().toString(36).slice(2)}-text`;

describe('log privacy', () => {
  it('console output never contains raw message text, tokens, or passwords', async () => {
    const spies = ['log', 'error', 'warn', 'info', 'debug'].map((method) =>
      vi.spyOn(console, method as keyof Console),
    );
    try {
      const app = testApp();
      const { controller, contributor, groupId } = await seedGroup(app);

      // Full lifecycle, including a decision and a worker failure for the
      // error path.
      const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
        text: `please keep ${SENTINEL} out of the logs`,
        is_anonymous: true,
      });
      await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
      await api.get(app, `/groups/${groupId}/review-queue/${sent.body.id}`, controller.token);
      await runStubWorkerOnce(testPool(), { shouldFailJob: () => true });
      await testPool().query(
        `UPDATE jobs SET run_after = now() - interval '1 second' WHERE raw_message_id = $1`,
        [sent.body.id],
      );
      await runStubWorkerOnce(testPool());
      await api.post(app, `/messages/${sent.body.id}/accept`, controller.token).catch(() => undefined);
      await api.post(app, `/messages/${sent.body.id}/reject`, controller.token).catch(() => undefined);
      await api.get(app, `/groups/${groupId}/messages`, contributor.token);
      await api.get(app, '/notifications', controller.token);

      // Requests with bad input exercise validation-error paths too.
      await api.post(app, '/auth/register', undefined, {
        name: 'X',
        email: 'bad',
        password: 'short',
      });
      await api.get(app, '/nope', contributor.token);
      await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
        text: '   ',
        is_anonymous: false,
      });

      const printed = spies.flatMap((spy) =>
        spy.mock.calls.flatMap((call) =>
          call.map((arg) => (typeof arg === 'string' ? arg : JSON.stringify(arg) ?? '')),
        ),
      );
      for (const line of printed) {
        expect(line).not.toContain(SENTINEL);
        expect(line).not.toContain(contributor.token);
        expect(line).not.toContain('secret123');
      }
    } finally {
      for (const spy of spies) spy.mockRestore();
    }
  });

  it('the stub rewrite (which embeds the original) is only served, never logged', async () => {
    const spies = ['log', 'error', 'warn', 'info', 'debug'].map((method) =>
      vi.spyOn(console, method as keyof Console),
    );
    try {
      const app = testApp();
      const { controller, contributor, groupId } = await seedGroup(app);
      const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
        text: `wrapped ${SENTINEL} inside`,
        is_anonymous: false,
      });
      await runStubWorkerOnce(testPool());
      await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
      const chat = await api.get(app, `/groups/${groupId}/messages`, controller.token);
      // The chat response DOES contain the stub rewrite (by design of the stub).
      expect(JSON.stringify(chat.body)).toContain(SENTINEL);
      // ...but nothing printed does.
      const printed = spies.flatMap((spy) =>
        spy.mock.calls.map((call) => call.map(String).join(' ')),
      );
      for (const line of printed) {
        expect(line).not.toContain(SENTINEL);
      }
    } finally {
      for (const spy of spies) spy.mockRestore();
    }
  });
});
