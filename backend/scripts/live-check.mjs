#!/usr/bin/env node
/* global process, console, setTimeout, fetch, FormData, Blob, Buffer */
/**
 * npm run check:live [-- http://localhost:3000]
 *
 * Exercises every feature of a RUNNING backend + database end to end with
 * throwaway accounts, prints PASS/FAIL per check, and deletes the accounts
 * at the end. Synthetic text only. Uses 8 rate-limited auth calls, so wait
 * 15 minutes (or restart the server) between back-to-back runs.
 *
 * The rewrite step needs the pipeline to be running: PIPELINE_MODE=stub
 * with RUN_STUB_WORKER=true, or PIPELINE_MODE=external plus the Python
 * worker (pipeline/) and a reachable model.
 */
const BASE = (process.argv[2] || process.env.BASE || 'http://localhost:3000').replace(/\/$/, '');
const run = Date.now().toString(36);
const results = [];
const created = [];

async function call(method, path, { token, body, raw, headers = {} } = {}) {
  const init = { method, headers: { ...headers } };
  if (token) init.headers.Authorization = `Bearer ${token}`;
  if (raw) init.body = raw;
  else if (body !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  }
  const res = await fetch(BASE + path, init);
  const type = res.headers.get('content-type') || '';
  const data = type.includes('json') ? await res.json() : await res.arrayBuffer();
  return { status: res.status, body: data, headers: res.headers };
}

function check(name, ok, detail = '') {
  results.push({ name, ok: Boolean(ok), detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${!ok && detail ? `  -> ${detail}` : ''}`);
  return Boolean(ok);
}

async function waitFor(fn, seconds) {
  for (let i = 0; i < seconds * 2; i++) {
    const value = await fn();
    if (value) return value;
    await new Promise((r) => setTimeout(r, 500));
  }
  return null;
}

async function register(name, local, password = 'live-check-pw-1') {
  const email = `${local}-${run}@example.com`;
  const res = await call('POST', '/auth/register', { body: { name, email, password } });
  const user = { name, email, password, token: res.body.token, id: res.body.user?.id, username: `${local}-${run}` };
  if (res.status === 201) created.push(user);
  return { res, user };
}

async function main() {
  console.log(`Live check against ${BASE} (run ${run})\n`);

  // --- Health and database ------------------------------------------------
  check('health', (await call('GET', '/health')).body.status === 'ok');
  check('ready (database reachable)', (await call('GET', '/ready')).body.status === 'ready');
  check('same API under /api/v1', (await call('GET', '/api/v1/health')).status === 200);

  // --- Auth ------------------------------------------------------------------
  const c = await register('Live Controller', 'lc');
  const m = await register('Live Member', 'lm');
  const o = await register('Live Outsider', 'lo');
  check('register x3', [c, m, o].every((x) => x.res.status === 201), JSON.stringify(c.res.body));
  const C = c.user;
  const M = m.user;
  const O = o.user;
  const login = await call('POST', '/auth/login', { body: { email: M.email, password: M.password } });
  check('login returns {token, user}', login.status === 200 && Object.keys(login.body).sort().join() === 'token,user');
  check('/me', (await call('GET', '/me', { token: M.token })).body.id === M.id);
  check('wrong password is 401', (await call('POST', '/auth/login', { body: { email: M.email, password: 'nope-nope' } })).status === 401);

  // --- Groups and moderated messaging ------------------------------------
  const group = await call('POST', '/groups', { token: C.token, body: { agenda: `Live check ${run}` } });
  check('create group (creator is controller)', group.status === 201 && group.body.my_role === 'controller');
  const gid = group.body.id;
  const add = await call('POST', `/groups/${gid}/members`, { token: C.token, body: { username: M.username, role: 'contributor' } });
  check('add member by username', add.status === 201, JSON.stringify(add.body));
  check('outsider gets 403 on the group', (await call('GET', `/groups/${gid}/messages`, { token: O.token })).status === 403);
  check('contributor gets 403 on the review queue', (await call('GET', `/groups/${gid}/review-queue`, { token: M.token })).status === 403);

  const sent = await call('POST', `/groups/${gid}/messages`, {
    token: M.token,
    body: { text: 'The weekly report should list the 3 open bugs before the demo.', is_anonymous: true },
  });
  check('anonymous submission is queued, not published', sent.status === 201 && sent.body.status === 'pending');
  check('chat stays empty before review', (await call('GET', `/groups/${gid}/messages`, { token: M.token })).body.items.length === 0);

  const item = await waitFor(async () => {
    const q = await call('GET', `/groups/${gid}/review-queue`, { token: C.token });
    const it = q.body.items?.find((x) => x.id === sent.body.id);
    return it && ['done', 'failed'].includes(it.pipeline_status) ? it : null;
  }, 90);
  const rewritten = check(
    'pipeline rewrote the message (worker or stub running)',
    item && item.pipeline_status === 'done' && item.rewritten_text,
    item ? `pipeline_status=${item.pipeline_status}` : 'still queued after 90 s: no worker is processing jobs',
  );
  if (item) {
    check('controller sees original + sender', item.original_text?.startsWith('The weekly report') && item.sender_id === M.id);
  }
  if (rewritten) {
    const acc = await call('POST', `/messages/${sent.body.id}/accept`, { token: C.token });
    check('accept publishes the rewrite', acc.status === 200 && acc.body.status === 'accepted');
    const chat = await call('GET', `/groups/${gid}/messages`, { token: M.token });
    const pub = chat.body.items.find((x) => x.id === acc.body.published_message_id);
    check('published anonymously (display_sender null)', pub && pub.display_sender === null);
    check('chat never contains the original text', !JSON.stringify(chat.body).includes('The weekly report should list'));
    const mine = await call('GET', `/groups/${gid}/messages/mine`, { token: M.token });
    const mineItem = mine.body.items.find((x) => x.id === sent.body.id);
    check('My messages: status only', mineItem?.status === 'accepted' && !('text' in mineItem) && !('rewrite' in mineItem));

    const r1 = await call('POST', `/groups/${gid}/messages/${pub.id}/reactions`, { token: M.token, body: { emoji: '👍' } });
    check('reaction toggle (counts only)', r1.status === 200 && r1.body.reactions['👍'] === 1 && !JSON.stringify(r1.body).includes(M.id));
  }

  const second = await call('POST', `/groups/${gid}/messages`, { token: M.token, body: { text: 'Second message for the reject path.', is_anonymous: false } });
  await waitFor(async () => {
    const q = await call('GET', `/groups/${gid}/review-queue/${second.body.id}`, { token: C.token });
    return q.status === 200 && ['done', 'failed'].includes(q.body.pipeline_status);
  }, 90);
  const rej = await call('POST', `/messages/${second.body.id}/reject`, { token: C.token });
  check('reject', rej.status === 200 && rej.body.status === 'rejected');
  const notes = await call('GET', '/notifications', { token: M.token });
  const rejNote = notes.body.items.find((n) => n.ref_id === second.body.id);
  check('rejection notification has no reason', rejNote?.type === 'message_rejected' && !('reason' in rejNote));
  check('unread count', (await call('GET', '/notifications/unread-count', { token: M.token })).body.count >= 1);
  check('read-all', (await call('POST', '/notifications/read-all', { token: M.token })).body.marked_count >= 1);

  const ann = await call('POST', `/groups/${gid}/messages/controller`, { token: C.token, body: { text: 'Announcement from the live check.' } });
  check('controller announcement publishes directly', ann.status === 201 && ann.body.display_sender?.id === C.id);
  check('controller deletes a published message', (await call('DELETE', `/groups/${gid}/messages/${ann.body.id}`, { token: C.token })).status === 204);

  // --- Feed --------------------------------------------------------------
  const post = await call('POST', '/posts', { token: M.token, body: { content: `Live check post ${run}` } });
  check('feed post (author shown)', post.status === 201 && post.body.author?.id === M.id);
  check('comment', (await call('POST', `/posts/${post.body.id}/comments`, { token: C.token, body: { content: 'Comment from the live check.' } })).status === 201);
  check('like', (await call('POST', `/posts/${post.body.id}/reactions`, { token: C.token, body: { type: 'like' } })).body.reaction_count === 1);
  const conv = await call('POST', `/posts/${post.body.id}/group`, { token: M.token });
  check('post -> group (author becomes controller)', conv.status === 201 && conv.body.my_role === 'controller');

  // --- Profile and media -------------------------------------------------
  const prof = await call('PUT', '/users/me/profile', { token: M.token, body: { headline: 'Live check headline', skills: ['Testing'] } });
  check('profile update', prof.status === 200 && prof.body.user.headline === 'Live check headline');
  check('experience', (await call('POST', '/users/me/experiences', { token: M.token, body: { title: 'Tester', company: 'Live', start_date: '2025-01-01', is_current: true } })).status === 201);
  check('education', (await call('POST', '/users/me/educations', { token: M.token, body: { school: 'Live School', start_year: 2020, end_year: 2024 } })).status === 201);
  const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(64, 7)]);
  const form = new FormData();
  form.append('file', new Blob([png], { type: 'image/png' }), 'a.png');
  const up = await call('POST', '/users/me/avatar', { token: M.token, raw: form });
  const avatarOk = check('avatar upload', up.status === 201 && /\/media\//.test(up.body.url || ''), JSON.stringify(up.body));
  if (avatarOk) {
    const media = await fetch(up.body.url);
    check('avatar served publicly as image/png', media.status === 200 && media.headers.get('content-type') === 'image/png');
  }
  const other = await call('GET', `/users/${M.id}/profile`, { token: O.token });
  check('public profile hides email', other.status === 200 && !('email' in other.body.user));

  // --- Sessions and security ---------------------------------------------
  const rt = await call('POST', '/auth/refresh-tokens', { token: M.token });
  const ex = await call('POST', '/auth/refresh', { body: { refresh_token: rt.body.refresh_token } });
  check('refresh token rotates', ex.status === 200 && ex.body.refresh_token && ex.body.refresh_token !== rt.body.refresh_token);
  const cp = await call('POST', '/auth/change-password', { token: M.token, body: { current_password: M.password, new_password: 'live-check-pw-2' } });
  check('change password returns a fresh token', cp.status === 200 && cp.body.token);
  check('old token stops working after the change', (await call('GET', '/me', { token: M.token })).status === 401);
  M.token = cp.body.token;
  M.password = 'live-check-pw-2';
  const reset = await call('POST', '/auth/password-reset', { body: { email: M.email } });
  check('password reset request (202, or 503 when email is off)', [202, 503].includes(reset.status), String(reset.status));
  check('logout-all ends the session', (await call('POST', '/auth/logout-all', { token: O.token })).status === 204 && (await call('GET', '/me', { token: O.token })).status === 401);

  // --- Controller hand-over (D4) -----------------------------------------
  check('controller leaves; earliest member takes over', (await call('POST', `/groups/${gid}/leave`, { token: C.token })).status === 204);
  const g2 = await call('GET', `/groups/${gid}`, { token: M.token });
  check('new controller', g2.body.my_role === 'controller' && g2.body.controller_id === M.id);

  // --- CORS for the web app ----------------------------------------------
  const pre = await fetch(BASE + '/auth/login', {
    method: 'OPTIONS',
    headers: { Origin: 'http://127.0.0.1:52001', 'Access-Control-Request-Method': 'POST' },
  });
  check('CORS allows the web app origin', pre.headers.get('access-control-allow-origin') === 'http://127.0.0.1:52001');
}

async function cleanup() {
  for (const u of created) {
    // logout-all voided O's token; sign in again only where needed.
    let token = u.token;
    if ((await call('GET', '/me', { token })).status === 401) {
      const again = await call('POST', '/auth/login', { body: { email: u.email, password: u.password } });
      if (again.status === 429) {
        check(`cleanup: delete ${u.name}`, false, `login rate limit reached; delete ${u.email} later`);
        continue;
      }
      token = again.body.token;
    }
    const del = await call('DELETE', '/users/me', { token, body: { password: u.password } });
    check(`cleanup: delete ${u.name}`, del.status === 204, String(del.status));
  }
}

try {
  await main();
} catch (err) {
  check('unexpected error', false, err instanceof Error ? err.message : String(err));
} finally {
  await cleanup().catch((err) => check('cleanup', false, String(err)));
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  process.exitCode = failed.length ? 1 : 0;
}
