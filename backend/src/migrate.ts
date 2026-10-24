import fs from 'node:fs';
import path from 'node:path';
import { Pool } from 'pg';
import { withTransaction } from './db';

export function migrationsDir(): string {
  // src/migrate.ts and dist/migrate.js both sit one level below backend/.
  return path.resolve(__dirname, '..', 'migrations');
}

/**
 * Applies every not-yet-applied migration in filename order. Each migration
 * runs in its own transaction together with its schema_migrations row.
 * Applied migrations are never edited; you add a new numbered file instead.
 */
export async function migrate(pool: Pool): Promise<string[]> {
  await pool.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
       filename text PRIMARY KEY,
       applied_at timestamptz NOT NULL DEFAULT now()
     )`,
  );
  const files = fs
    .readdirSync(migrationsDir())
    .filter((name) => name.endsWith('.sql'))
    .sort();
  const applied = new Set(
    (await pool.query('SELECT filename FROM schema_migrations')).rows.map(
      (row) => row.filename as string,
    ),
  );
  const ran: string[] = [];
  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = fs.readFileSync(path.join(migrationsDir(), file), 'utf8');
    await withTransaction(pool, async (client) => {
      await client.query(sql);
      await client.query(
        'INSERT INTO schema_migrations (filename) VALUES ($1)',
        [file],
      );
    });
    ran.push(file);
  }
  return ran;
}
