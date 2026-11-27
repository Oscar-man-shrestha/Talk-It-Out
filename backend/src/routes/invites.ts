/**
 * Group invite links (API.md 61). Controllers create, list and revoke
 * links; anyone signed in can preview one and join with it.
 */
import crypto from 'node:crypto';
import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { blockedEitherWay } from '../blocks';
import { Config } from '../config';
import { withTransaction } from '../db';
import { ApiError, forbidden, notFound, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { notifyMemberJoined } from '../notifyMembers';

const ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789'; // no 0/o, 1/l/i
export const MAX_ACTIVE_INVITES = 20;

export function newInviteCode(): string {
  const bytes = crypto.randomBytes(10);
  let out = '';
  for (const b of bytes) out += ALPHABET[b % ALPHABET.length];
  return out;
}

const createSchema = z.object({
  expires_in_days: z
    .union([z.literal(1), z.literal(7), z.literal(30), z.null()], {
      error: () => 'Choose 1, 7 or 30 days, or no expiry.',
    })
    .optional(),
  max_uses: z
    .number({ error: () => 'Uses must be a number.' })
    .int()
    .min(1, 'At least 1 use.')
    .max(1000, 'At most 1000 uses.')
    .nullable()
    .optional(),
});

const CODE_RE = /^[a-z2-9]{10}$/;

interface InviteRow {
  code: string;
  group_id: string;
  created_at: Date;
  expires_at: Date | null;
  max_uses: number | null;
  uses: number;
  revoked_at: Date | null;
  created_by: string | null;
}

const usable = (i: InviteRow, now = new Date()) =>
  !i.revoked_at && (!i.expires_at || i.expires_at > now) && (i.max_uses == null || i.uses < i.max_uses);

export function inviteUrl(cfg: Pick<Config, 'appWebUrl'>, code: string): string {
  return `${cfg.appWebUrl.replace(/\/+$/, '')}/#/join/${code}`;
}

function inviteJson(cfg: Pick<Config, 'appWebUrl'>, i: InviteRow) {
  return {
    code: i.code,
    url: inviteUrl(cfg, i.code),
    app_url: `talkitout://app/join/${i.code}`,
    created_at: i.created_at.toISOString(),
    expires_at: i.expires_at?.toISOString() ?? null,
    max_uses: i.max_uses,
    uses: i.uses,
  };
}

async function requireController(pool: Pool, groupId: string, userId: string) {
  const { rows } = await pool.query<{ role: string }>(
    'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
    [groupId, userId],
  );
  if (!rows[0]) throw notFound();
  if (rows[0].role !== 'controller') throw forbidden();
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** /groups/:groupId/invites (controller only). */
export function createGroupInvitesRouter(pool: Pool, cfg: Pick<Config, 'appWebUrl'>, requireAuth: RequireAuth): Router {
  const router = Router({ mergeParams: true });
  router.use(requireAuth);

  router.post('/', async (req, res) => {
    const groupId = (req.params as { groupId: string }).groupId;
    if (!UUID_RE.test(groupId)) throw notFound();
    await requireController(pool, groupId, req.user!.id);
    const body = parseWith(createSchema, req.body ?? {});
    const active = await pool.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM group_invites
       WHERE group_id = $1 AND revoked_at IS NULL
         AND (expires_at IS NULL OR expires_at > now())
         AND (max_uses IS NULL OR uses < max_uses)`,
      [groupId],
    );
    if (active.rows[0].n >= MAX_ACTIVE_INVITES) {
      throw new ApiError(409, 'too_many_invites', 'Revoke an old link before making another.');
    }
    const days = body.expires_in_days === undefined ? 7 : body.expires_in_days;
    const { rows } = await pool.query<InviteRow>(
      `INSERT INTO group_invites (code, group_id, created_by, expires_at, max_uses)
       VALUES ($1, $2, $3, CASE WHEN $4::int IS NULL THEN NULL ELSE now() + make_interval(days => $4::int) END, $5)
       RETURNING *`,
      [newInviteCode(), groupId, req.user!.id, days, body.max_uses ?? null],
    );
    res.status(201).json(inviteJson(cfg, rows[0]));
  });

  router.get('/', async (req, res) => {
    const groupId = (req.params as { groupId: string }).groupId;
    if (!UUID_RE.test(groupId)) throw notFound();
    await requireController(pool, groupId, req.user!.id);
    const { rows } = await pool.query<InviteRow>(
      'SELECT * FROM group_invites WHERE group_id = $1 AND revoked_at IS NULL ORDER BY created_at DESC',
      [groupId],
    );
    res.json({ items: rows.filter((r) => usable(r)).map((r) => inviteJson(cfg, r)) });
  });

  router.delete('/:code', async (req, res) => {
    const { groupId, code } = req.params as { groupId: string; code: string };
    if (!UUID_RE.test(groupId) || !CODE_RE.test(code)) throw notFound();
    await requireController(pool, groupId, req.user!.id);
    await pool.query(
      'UPDATE group_invites SET revoked_at = now() WHERE code = $1 AND group_id = $2 AND revoked_at IS NULL',
      [code, groupId],
    );
    res.status(204).end();
  });

  return router;
}

/** /invites/:code : preview and accept (any signed-in user). */
export function createInvitesRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  const invalid = () => new ApiError(404, 'invite_invalid', 'This invite link has expired or was turned off.');

  router.get('/:code', async (req, res) => {
    const code = String(req.params.code).toLowerCase();
    if (!CODE_RE.test(code)) throw invalid();
    const { rows } = await pool.query<InviteRow & { agenda: string; members: number; inviter: string | null; member: boolean }>(
      `SELECT i.*, g.agenda,
              (SELECT count(*)::int FROM group_members m WHERE m.group_id = g.id) AS members,
              u.name AS inviter,
              EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.id AND m.user_id = $2) AS member
       FROM group_invites i
       JOIN groups g ON g.id = i.group_id
       LEFT JOIN users u ON u.id = i.created_by
       WHERE i.code = $1`,
      [code, req.user!.id],
    );
    const i = rows[0];
    if (!i || !usable(i)) throw invalid();
    if (i.created_by && (await blockedEitherWay(pool, req.user!.id, i.created_by))) throw invalid();
    res.json({
      code: i.code,
      group: { id: i.group_id, agenda: i.agenda, member_count: i.members },
      invited_by: i.inviter,
      already_member: i.member,
      expires_at: i.expires_at?.toISOString() ?? null,
    });
  });

  router.post('/:code/accept', async (req, res) => {
    const code = String(req.params.code).toLowerCase();
    if (!CODE_RE.test(code)) throw invalid();
    const me = req.user!.id;
    const result = await withTransaction(pool, async (client) => {
      const { rows } = await client.query<InviteRow>(
        'SELECT * FROM group_invites WHERE code = $1 FOR UPDATE',
        [code],
      );
      const i = rows[0];
      if (!i) throw invalid();
      const already = await client.query(
        'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
        [i.group_id, me],
      );
      if (already.rows[0]) return { groupId: i.group_id, joined: false };
      if (!usable(i)) throw invalid();
      if (i.created_by && (await blockedEitherWay(client, me, i.created_by))) throw invalid();
      await client.query(
        `INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'contributor')`,
        [i.group_id, me],
      );
      await client.query('UPDATE group_invites SET uses = uses + 1 WHERE code = $1', [code]);
      await notifyMemberJoined(client, i.group_id, me);
      return { groupId: i.group_id, joined: true };
    });
    res.status(result.joined ? 201 : 200).json({ group_id: result.groupId, joined: result.joined });
  });

  return router;
}
