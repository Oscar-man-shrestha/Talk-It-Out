import { config, stubWorkerShouldRun } from './config';
import { createPool } from './db';
import { buildApp } from './app';
import { setupGracefulShutdown } from './shutdown';
import { startStubWorkerLoop } from './worker/stubWorker';
import { startFeedWorkerLoop } from './feed-analysis/worker';
import { createFeedProvider } from './feed-analysis/provider';

async function main() {
  const pool = createPool(config.databaseUrl, {
    max: config.pgPoolMax,
    idleTimeoutMillis: config.pgIdleTimeoutMillis,
    statementTimeoutMillis: config.pgStatementTimeoutMillis,
    connectionTimeoutMillis: config.pgConnectionTimeoutMillis,
  });
  const app = buildApp(pool, config);
  const server = app.listen(config.port, () => {
    console.log(`Talk It Out API listening on http://localhost:${config.port} (/ and /api/v1)`);
  });

  const stop: Array<() => void> = [];
  if (stubWorkerShouldRun(config)) {
    stop.push(startStubWorkerLoop(pool));
    console.log('Stub rewrite worker running in-process (NOT the real NLP pipeline).');
  } else if (config.runStubWorker && config.pipelineMode === 'external') {
    // The external Python worker owns the jobs; the stub must not compete.
    console.log(
      'PIPELINE_MODE=external: stub rewrite worker suppressed; the external worker claims at /internal/pipeline/*.',
    );
  }

  if (config.runFeedWorker) {
    const provider = createFeedProvider(config.feedProvider);
    stop.push(startFeedWorkerLoop(pool, provider));
    console.log(`Feed analysis worker running in-process (provider: ${config.feedProvider}).`);
  }

  // Open live-update streams would keep server.close() waiting forever.
  const realtime = app.locals.realtime as { close: () => Promise<void> } | undefined;
  if (realtime) stop.push(() => void realtime.close());

  setupGracefulShutdown({ server, pools: [pool], stop });
}

main().catch((err) => {
  console.error('Failed to start server:', err instanceof Error ? err.message : err);
  process.exit(1);
});
