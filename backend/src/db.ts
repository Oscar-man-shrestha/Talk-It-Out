import { Pool, PoolClient } from 'pg';

export interface PoolOptions {
  max?: number;
  idleTimeoutMillis?: number;
  statementTimeoutMillis?: number;
  connectionTimeoutMillis?: number;
}

export function createPool(connectionString: string, options: PoolOptions = {}): Pool {
  const pool = new Pool({
    connectionString,
    max: options.max ?? 10,
    idleTimeoutMillis: options.idleTimeoutMillis ?? 30000,
    connectionTimeoutMillis: options.connectionTimeoutMillis ?? 5000,
    // Per-connection guard against runaway statements.
    statement_timeout: options.statementTimeoutMillis ?? 15000,
  });
  // An idle client can die when the database restarts or drops the
  // connection. Without a listener, node-postgres re-emits that as an
  // unhandled 'error' event and the whole API process crashes. The pool
  // already discards the broken client; new queries get a fresh one.
  pool.on('error', (err) => {
    console.error('[db] idle client error; the pool will reconnect:', err.message);
  });
  return pool;
}

/** Runs fn inside a transaction, rolling back on any error. */
export async function withTransaction<T>(
  pool: Pool,
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // Connection already broken; the original error matters more.
    }
    throw err;
  } finally {
    client.release();
  }
}

/** Postgres unique-violation constraint name, if err is one. */
export function uniqueConstraint(err: unknown): string | undefined {
  if (err && typeof err === 'object' && 'code' in err) {
    const pgErr = err as { code?: string; constraint?: string };
    if (pgErr.code === '23505' && pgErr.constraint) return pgErr.constraint;
  }
  return undefined;
}
