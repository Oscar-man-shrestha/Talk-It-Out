import crypto from 'node:crypto';
import { Request, Response, Router } from 'express';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { Config } from '../config';
import { unauthorized } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { RealtimeHub } from '../realtime';

/**
 * Live updates over Server-Sent Events (API.md 41).
 *
 * Browsers' EventSource cannot send an Authorization header, and putting
 * the access token in a URL would leak it into logs. So:
 *   1. POST /events/ticket (Bearer) -> { ticket, expires_in: 60 }
 *   2. GET  /events?ticket=...       -> text/event-stream
 * Tickets are signed with a key derived from JWT_SECRET (never valid as an
 * access token, and access tokens are never valid as tickets), expire in
 * 60 s, and carry the user's token_version, so a stream cannot outlive
 * "sign out everywhere".
 */

export const TICKET_TTL_SECONDS = 60;

function ticketKey(jwtSecret: string): Buffer {
  return crypto.createHmac('sha256', jwtSecret).update('talkitout:sse-ticket:v1').digest();
}

export function createEventsRouter(
  pool: Pool,
  requireAuth: RequireAuth,
  appConfig: Config,
  hub: RealtimeHub,
): Router {
  const router = Router();
  const key = ticketKey(appConfig.jwtSecret);

  router.post('/ticket', requireAuth, async (req, res) => {
    const { rows } = await pool.query<{ token_version: number }>(
      'SELECT token_version FROM users WHERE id = $1',
      [req.user!.id],
    );
    const ticket = jwt.sign({ tv: rows[0]?.token_version ?? 0 }, key, {
      subject: req.user!.id,
      audience: 'sse',
      expiresIn: TICKET_TTL_SECONDS,
      algorithm: 'HS256',
    });
    res.json({ ticket, expires_in: TICKET_TTL_SECONDS });
  });

  router.get('/', async (req: Request, res: Response) => {
    const raw = typeof req.query.ticket === 'string' ? req.query.ticket : '';
    let userId: string;
    let tv: number;
    try {
      const payload = jwt.verify(raw, key, { algorithms: ['HS256'], audience: 'sse' });
      if (typeof payload === 'string' || typeof payload.sub !== 'string') throw new Error();
      userId = payload.sub;
      tv = typeof payload.tv === 'number' ? payload.tv : 0;
    } catch {
      throw unauthorized('Live updates need a fresh ticket.');
    }
    const { rows } = await pool.query<{ token_version: number }>(
      'SELECT token_version FROM users WHERE id = $1',
      [userId],
    );
    if (!rows[0] || rows[0].token_version !== tv) throw unauthorized();

    res.status(200).set({
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      // Stop nginx and similar proxies from buffering the stream.
      'X-Accel-Buffering': 'no',
    });
    res.flushHeaders();
    // Reconnect hint for EventSource, then a ready event.
    res.write('retry: 3000\n');
    res.write(`event: ready\ndata: ${JSON.stringify({ type: 'ready' })}\n\n`);

    const remove = hub.add(userId, res);
    req.on('close', remove);
  });

  return router;
}
