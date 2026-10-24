/**
 * Graceful shutdown: on SIGINT/SIGTERM stop accepting new connections, stop
 * the background workers, drain in-flight requests, close the pg pool, and
 * exit within a hard deadline so orchestrators never have to SIGKILL.
 */
import type { Server } from 'node:http';

export interface ShutdownDeps {
  server: Pick<Server, 'close' | 'closeIdleConnections'>;
  pools: Array<{ end: () => Promise<unknown> }>;
  stop: Array<() => void>;
  exit?: (code: number) => void;
  timeoutMs?: number;
  signals?: NodeJS.Signals[];
}

export function setupGracefulShutdown(deps: ShutdownDeps): () => void {
  const exit = deps.exit ?? ((code: number) => process.exit(code));
  const timeoutMs = deps.timeoutMs ?? 10_000;
  let shuttingDown = false;

  const shutdown = (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`[shutdown] ${signal} received; shutting down gracefully`);
    // Hard deadline: whatever is still pending, we exit.
    const force = setTimeout(() => {
      console.error('[shutdown] deadline reached; forcing exit');
      exit(1);
    }, timeoutMs);
    force.unref?.();

    for (const stop of deps.stop) stop();
    deps.server.closeIdleConnections?.();
    deps.server.close(() => {
      Promise.all(deps.pools.map((pool) => pool.end()))
        .then(() => {
          clearTimeout(force);
          console.log('[shutdown] complete');
          exit(0);
        })
        .catch(() => {
          clearTimeout(force);
          exit(1);
        });
    });
  };

  const signals = deps.signals ?? (['SIGINT', 'SIGTERM'] as NodeJS.Signals[]);
  const listeners = signals.map((signal) => {
    const listener = () => shutdown(signal);
    process.on(signal, listener);
    return { signal, listener };
  });

  return () => {
    for (const { signal, listener } of listeners) {
      process.removeListener(signal, listener);
    }
  };
}
