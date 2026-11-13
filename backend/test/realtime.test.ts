import type { AddressInfo } from 'node:net';
import type { Server } from 'node:http';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { RealtimeHub } from '../src/realtime';
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

interface Received {
  event: string;
  data: Record<string, unknown>;
}

interface Stream {
  events: Received[];
  waitFor: (pred: (e: Received) => boolean, ms?: number) => Promise<Received>;
  closed: Promise<void>;
  close: () => void;
}

let server: Server | undefined;
let hub: RealtimeHub | undefined;
let base = '';

async function start() {
  const app = testApp();
  hub = app.locals.realtime as RealtimeHub;
  server = app.listen(0);
  await new Promise<void>((r) => server!.once('listening', () => r()));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  return app;
}

afterEach(async () => {
  await hub?.close();
  server?.closeAllConnections();
  await new Promise<void>((r) => (server ? server.close(() => r()) : r()));
  server = undefined;
  hub = undefined;
});

async function ticketFor(token: string): Promise<string> {
  const res = await fetch(`${base}/events/ticket`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { ticket: string }).ticket;
}

async function open(token: string): Promise<Stream> {
  const controller = new AbortController();
  const res = await fetch(`${base}/events?ticket=${encodeURIComponent(await ticketFor(token))}`, {
    signal: controller.signal,
  });
  expect(res.status).toBe(200);
  expect(res.headers.get('content-type')).toContain('text/event-stream');
  const events: Received[] = [];
  const waiters: { pred: (e: Received) => boolean; resolve: (e: Received) => void }[] = [];
  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  const closed = (async () => {
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) return;
        buffer += decoder.decode(value, { stream: true });
        let idx;
        while ((idx = buffer.indexOf('\n\n')) >= 0) {
          const block = buffer.slice(0, idx);
          buffer = buffer.slice(idx + 2);
          const event = /^event: (.*)$/m.exec(block)?.[1];
          const data = /^data: (.*)$/m.exec(block)?.[1];
          if (!event || !data) continue;
          const e = { event, data: JSON.parse(data) };
          events.push(e);
          for (const w of [...waiters]) {
            if (w.pred(e)) {
              waiters.splice(waiters.indexOf(w), 1);
              w.resolve(e);
            }
          }
        }
      }
    } catch {
      // aborted
    }
  })();
  const waitFor = (pred: (e: Received) => boolean, ms = 3000) =>
    new Promise<Received>((resolve, reject) => {
      const hit = events.find(pred);
      if (hit) return resolve(hit);
      const timer = setTimeout(() => reject(new Error('timed out waiting for event')), ms);
      waiters.push({
        pred,
        resolve: (e) => {
          clearTimeout(timer);
          resolve(e);
        },
      });
    });
  await waitFor((e) => e.event === 'ready');
  await hub!.ready();
  return { events, waitFor, closed, close: () => controller.abort() };
}

const settle = () => new Promise((r) => setTimeout(r, 300));

describe('live updates (SSE)', () => {
  it('needs a valid ticket; tickets and access tokens are not interchangeable', async () => {
    const app = await start();
    const user = await registerUser(app, 'P', 'p@example.com');
    expect((await fetch(`${base}/events`)).status).toBe(401);
    expect((await fetch(`${base}/events?ticket=garbage`)).status).toBe(401);
    // An access token is not a ticket...
    expect((await fetch(`${base}/events?ticket=${user.token}`)).status).toBe(401);
    // ...and a ticket is not an access token.
    const ticket = await ticketFor(user.token);
    expect((await api.get(app, '/me', ticket)).status).toBe(401);
    expect((await fetch(`${base}/events/ticket`, { method: 'POST' })).status).toBe(401);
  });

  it('moderation flow: each person gets only the signals meant for them', async () => {
    const app = await start();
    const { controller, contributor, groupId } = await seedGroup(app);
    const outsider = await registerUser(app, 'Out', 'out@example.com');
    const c = await open(controller.token);
    const m = await open(contributor.token);
    const o = await open(outsider.token);

    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'secret draft text for the live test',
      is_anonymous: true,
    });
    await c.waitFor((e) => e.event === 'review' && e.data.group_id === groupId);
    await c.waitFor((e) => e.event === 'notifications');
    await m.waitFor((e) => e.event === 'mine' && e.data.group_id === groupId);

    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    expect(accepted.status).toBe(200);
    await c.waitFor((e) => e.event === 'chat' && e.data.group_id === groupId);
    await m.waitFor((e) => e.event === 'chat' && e.data.group_id === groupId);
    await settle();

    // The contributor never receives review signals; the outsider nothing.
    expect(m.events.some((e) => e.event === 'review')).toBe(false);
    expect(o.events.filter((e) => e.event !== 'ready')).toEqual([]);

    // Payloads carry ids only: no text, no sender of the anonymous draft.
    const wire = JSON.stringify([...c.events, ...m.events]);
    expect(wire).not.toContain('secret draft text');
    expect(wire).not.toContain(contributor.id);
    expect(wire).not.toContain(sent.body.id);

    for (const s of [c, m, o]) s.close();
  });

  it('reactions and deletions reach group members', async () => {
    const app = await start();
    const { controller, contributor, groupId } = await seedGroup(app);
    const ann = await api.post(app, `/groups/${groupId}/messages/controller`, controller.token, {
      text: 'Announcement',
    });
    const m = await open(contributor.token);
    await api.post(app, `/groups/${groupId}/messages/${ann.body.id}/reactions`, controller.token, {
      emoji: '🔥',
    });
    const r = await m.waitFor((e) => e.event === 'reaction');
    expect(r.data).toEqual({ type: 'reaction', group_id: groupId, message_id: ann.body.id });
    await api.del(app, `/groups/${groupId}/messages/${ann.body.id}`, controller.token);
    await m.waitFor((e) => e.event === 'chat' && e.data.group_id === groupId);
    m.close();
  });

  it('membership changes reach the added user and the group', async () => {
    const app = await start();
    const controller = await registerUser(app, 'C', 'c@example.com');
    const newcomer = await registerUser(app, 'N', 'newcomer@example.com');
    const g = await api.post(app, '/groups', controller.token, { agenda: 'Live members' });
    const n = await open(newcomer.token);
    const c = await open(controller.token);
    await api.post(app, `/groups/${g.body.id}/members`, controller.token, {
      username: 'newcomer',
      role: 'contributor',
    });
    await n.waitFor((e) => e.event === 'groups');
    await c.waitFor((e) => e.event === 'members' && e.data.group_id === g.body.id);
    n.close();
    c.close();
  });

  it('feed changes reach everyone connected', async () => {
    const app = await start();
    const a = await registerUser(app, 'A', 'a@example.com');
    const b = await registerUser(app, 'B', 'b@example.com');
    const sb = await open(b.token);
    const post = await api.post(app, '/posts', a.token, { content: 'Live post' });
    const e = await sb.waitFor((x) => x.event === 'feed');
    expect(e.data).toEqual({ type: 'feed', post_id: post.body.id });
    sb.close();
  });

  it('sign out everywhere closes live streams', async () => {
    const app = await start();
    const user = await registerUser(app, 'P', 'p@example.com');
    const s = await open(user.token);
    expect(hub!.size).toBe(1);
    expect((await api.post(app, '/auth/logout-all', user.token)).status).toBe(204);
    await s.closed;
    expect(hub!.size).toBe(0);
  });

  it('listens only while someone is connected', async () => {
    await start();
    expect(hub!.listening).toBe(false);
  });
});
