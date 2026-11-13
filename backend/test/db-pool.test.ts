import { describe, expect, it } from 'vitest';
import { createPool } from '../src/db';
import { config } from './helpers';

describe('database pool', () => {
  it('survives an idle client dying (database restart) instead of crashing', async () => {
    const pool = createPool(config.testDatabaseUrl);
    try {
      expect(pool.listenerCount('error')).toBeGreaterThan(0);
      // node-postgres re-emits idle-client errors on the pool; with no
      // listener this would throw and take the process down.
      expect(() => pool.emit('error', new Error('Connection terminated unexpectedly'))).not.toThrow();
      const { rows } = await pool.query('SELECT 1 AS ok');
      expect(rows[0].ok).toBe(1);
    } finally {
      await pool.end();
    }
  });
});
