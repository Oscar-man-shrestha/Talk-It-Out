import { Pool, PoolClient } from 'pg';

export function createPool(connectionString: string): Pool {
  return new Pool({ connectionString, max: 10 });
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
