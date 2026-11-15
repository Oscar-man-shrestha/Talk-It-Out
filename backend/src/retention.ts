import { Pool } from 'pg';

/** How long feed signals (opens, saves, "Not interested") are kept. */
export const FEED_EVENT_RETENTION_DAYS = 180;

/**
 * Deletes feed signals older than the retention period (the promise in
 * docs/STARTUP_PLAN.md section 4). Returns how many rows were removed.
 */
export async function pruneFeedEvents(pool: Pool, days = FEED_EVENT_RETENTION_DAYS): Promise<number> {
  const result = await pool.query(
    'DELETE FROM feed_events WHERE created_at < now() - make_interval(days => $1)',
    [days],
  );
  return result.rowCount ?? 0;
}

/** Runs the prune at start-up and then every few hours. Returns a stop function. */
export function startRetentionLoop(pool: Pool, everyMs = 6 * 3600 * 1000): () => void {
  const run = () => {
    pruneFeedEvents(pool).catch((err) => {
      console.error('[retention] prune failed:', err instanceof Error ? err.message : err);
    });
  };
  run();
  const timer = setInterval(run, everyMs);
  timer.unref();
  return () => clearInterval(timer);
}
