import crypto from 'node:crypto';
import type { Response } from 'express';
import { Client, Pool } from 'pg';

/**
 * Live updates (API.md 41).
 *
 * Database triggers (migration 011) NOTIFY "tio_events" with id-only
 * payloads. This hub LISTENs on one dedicated connection (opened only
 * while at least one client is connected), decides who may receive each
 * signal, and writes Server-Sent Events to those clients' open streams.
 *
 * Privacy: events carry ids and a type only. Chat and reaction events go
 * to group members; review events only to that group's controller; "mine"
 * events only to the draft's author; notification events only to the
 * recipient. Nothing about the sender of an anonymous message is ever
 * forwarded. Clients refetch through the normal endpoints, which enforce
 * every rule, so the live channel cannot leak anything those endpoints
 * would not.
 *
 * Multi-instance: every API instance runs its own hub and LISTENs on the
 * same channel, so any instance can serve any client (no sticky sessions,
 * no Redis).
 */

export type LiveEvent =
  | { type: 'chat'; group_id: string }
  | { type: 'reaction'; group_id: string; message_id: string }
  | { type: 'review'; group_id: string }
  | { type: 'mine'; group_id: string }
  | { type: 'members'; group_id: string }
  | { type: 'groups' }
  | { type: 'notifications' }
  | { type: 'feed'; post_id: string };

interface Signal {
  t: 'chat' | 'reaction' | 'review' | 'notif' | 'members' | 'feed' | 'session';
  g?: string;
  u?: string;
  m?: string;
  a?: string;
  p?: string;
}

interface Connection {
  id: string;
  userId: string;
  res: Response;
}

export const MAX_STREAMS_PER_USER = 5;
const HEARTBEAT_MS = 25_000;
const IDLE_STOP_MS = 30_000;

export class RealtimeHub {
  private readonly byUser = new Map<string, Map<string, Connection>>();
  private listener: Client | null = null;
  private connecting: Promise<void> | null = null;
  private heartbeat: NodeJS.Timeout | null = null;
  private idleTimer: NodeJS.Timeout | null = null;
  private reconnectDelay = 1000;
  private closed = false;

  constructor(private readonly pool: Pool) {}

  /** Number of open streams (for tests and health checks). */
  get size(): number {
    let n = 0;
    for (const conns of this.byUser.values()) n += conns.size;
    return n;
  }

  /** True once the LISTEN connection is up. */
  get listening(): boolean {
    return this.listener !== null;
  }

  /** Waits for the LISTEN connection (tests use this before acting). */
  async ready(): Promise<void> {
    await this.ensureListening();
  }

  /** Registers an open SSE response. Returns a function that removes it. */
  add(userId: string, res: Response): () => void {
    if (this.closed) {
      res.end();
      return () => {};
    }
    const conn: Connection = { id: crypto.randomUUID(), userId, res };
    let conns = this.byUser.get(userId);
    if (!conns) {
      conns = new Map();
      this.byUser.set(userId, conns);
    }
    // Cap streams per user: close the oldest beyond the limit.
    while (conns.size >= MAX_STREAMS_PER_USER) {
      const [oldestId, oldest] = conns.entries().next().value as [string, Connection];
      conns.delete(oldestId);
      oldest.res.end();
    }
    conns.set(conn.id, conn);
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }
    this.startHeartbeat();
    void this.ensureListening();
    return () => this.remove(conn);
  }

  private remove(conn: Connection): void {
    const conns = this.byUser.get(conn.userId);
    if (!conns?.delete(conn.id)) return;
    if (conns.size === 0) this.byUser.delete(conn.userId);
    if (this.size === 0) this.scheduleIdleStop();
  }

  private scheduleIdleStop(): void {
    if (this.idleTimer) return;
    this.idleTimer = setTimeout(() => {
      this.idleTimer = null;
      if (this.size === 0) void this.stopListening();
    }, IDLE_STOP_MS);
    this.idleTimer.unref?.();
  }

  private startHeartbeat(): void {
    if (this.heartbeat) return;
    this.heartbeat = setInterval(() => {
      if (this.size === 0) return;
      for (const conns of this.byUser.values()) {
        for (const conn of conns.values()) conn.res.write(': ping\n\n');
      }
    }, HEARTBEAT_MS);
    this.heartbeat.unref?.();
  }

  private async ensureListening(): Promise<void> {
    if (this.listener || this.closed) return;
    if (this.connecting) return this.connecting;
    this.connecting = (async () => {
      const client = new Client(this.pool.options);
      try {
        await client.connect();
        await client.query('LISTEN tio_events');
      } catch (err) {
        await client.end().catch(() => {});
        this.scheduleReconnect(err);
        return;
      }
      client.on('notification', (msg) => {
        if (msg.channel === 'tio_events' && msg.payload) void this.dispatch(msg.payload);
      });
      client.on('error', (err) => {
        if (this.listener === client) this.listener = null;
        client.end().catch(() => {});
        this.scheduleReconnect(err);
      });
      this.listener = client;
      this.reconnectDelay = 1000;
    })().finally(() => {
      this.connecting = null;
    });
    return this.connecting;
  }

  private scheduleReconnect(err: unknown): void {
    if (this.closed || this.size === 0) return;
    console.error(
      '[realtime] listener connection lost; retrying:',
      err instanceof Error ? err.name : 'error',
    );
    const delay = this.reconnectDelay;
    this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30_000);
    // Tell clients to refetch: events may have been missed meanwhile.
    this.broadcastResync();
    setTimeout(() => void this.ensureListening(), delay).unref?.();
  }

  private broadcastResync(): void {
    for (const conns of this.byUser.values()) {
      for (const conn of conns.values()) write(conn.res, 'resync', {});
    }
  }

  private async stopListening(): Promise<void> {
    const client = this.listener;
    this.listener = null;
    if (this.heartbeat) {
      clearInterval(this.heartbeat);
      this.heartbeat = null;
    }
    if (client) await client.end().catch(() => {});
  }

  /** Ends every stream and the listener (graceful shutdown, tests). */
  async close(): Promise<void> {
    this.closed = true;
    if (this.idleTimer) clearTimeout(this.idleTimer);
    for (const conns of this.byUser.values()) {
      for (const conn of conns.values()) conn.res.end();
    }
    this.byUser.clear();
    await this.stopListening();
  }

  private send(userId: string, event: LiveEvent): void {
    const conns = this.byUser.get(userId);
    if (!conns) return;
    for (const conn of conns.values()) write(conn.res, event.type, event);
  }

  private connected(userIds: string[]): string[] {
    return userIds.filter((id) => this.byUser.has(id));
  }

  /** Group members who currently have a stream open, with their roles. */
  private async connectedMembers(groupId: string): Promise<{ user_id: string; role: string }[]> {
    if (this.byUser.size === 0) return [];
    const { rows } = await this.pool.query<{ user_id: string; role: string }>(
      'SELECT user_id, role FROM group_members WHERE group_id = $1 AND user_id = ANY($2::uuid[])',
      [groupId, [...this.byUser.keys()]],
    );
    return rows;
  }

  private async dispatch(raw: string): Promise<void> {
    let signal: Signal;
    try {
      signal = JSON.parse(raw) as Signal;
    } catch {
      return;
    }
    if (this.byUser.size === 0) return;
    try {
      switch (signal.t) {
        case 'chat':
          if (!signal.g) return;
          for (const m of await this.connectedMembers(signal.g)) {
            this.send(m.user_id, { type: 'chat', group_id: signal.g });
          }
          return;
        case 'reaction':
          if (!signal.g || !signal.m) return;
          for (const m of await this.connectedMembers(signal.g)) {
            this.send(m.user_id, { type: 'reaction', group_id: signal.g, message_id: signal.m });
          }
          return;
        case 'review': {
          if (!signal.g) return;
          const members = await this.connectedMembers(signal.g);
          for (const m of members) {
            if (m.role === 'controller') {
              this.send(m.user_id, { type: 'review', group_id: signal.g });
              // The groups list shows the controller's pending count.
              this.send(m.user_id, { type: 'groups' });
            }
          }
          // Only the author learns their own draft changed; still a member.
          if (signal.a && members.some((m) => m.user_id === signal.a)) {
            this.send(signal.a, { type: 'mine', group_id: signal.g });
          }
          return;
        }
        case 'notif':
          if (signal.u) this.send(signal.u, { type: 'notifications' });
          return;
        case 'members':
          if (!signal.g) return;
          // The affected user (added, removed, or promoted) refreshes their
          // groups list even if they are no longer a member.
          if (signal.u) this.send(signal.u, { type: 'groups' });
          for (const m of await this.connectedMembers(signal.g)) {
            this.send(m.user_id, { type: 'members', group_id: signal.g });
            if (m.user_id !== signal.u) this.send(m.user_id, { type: 'groups' });
          }
          return;
        case 'feed':
          if (!signal.p) return;
          for (const userId of this.connected([...this.byUser.keys()])) {
            this.send(userId, { type: 'feed', post_id: signal.p });
          }
          return;
        case 'session': {
          // Every session ended: close this user's streams. The client's
          // next request gets 401 and signs out as usual.
          const conns = signal.u ? this.byUser.get(signal.u) : undefined;
          if (!conns) return;
          this.byUser.delete(signal.u!);
          for (const conn of conns.values()) conn.res.end();
          if (this.size === 0) this.scheduleIdleStop();
          return;
        }
      }
    } catch (err) {
      console.error('[realtime] dispatch failed:', err instanceof Error ? err.name : 'error');
    }
  }
}

function write(res: Response, event: string, data: unknown): void {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}
