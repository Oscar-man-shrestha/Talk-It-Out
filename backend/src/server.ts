import { config, stubWorkerShouldRun } from './config';
import { createPool } from './db';
import { buildApp } from './app';
import { startStubWorkerLoop } from './worker/stubWorker';
import { startFeedWorkerLoop } from './feed-analysis/worker';
import { createFeedProvider } from './feed-analysis/provider';

async function main() {
  const pool = createPool(config.databaseUrl);
  const app = buildApp(pool, config);
  const server = app.listen(config.port, () => {
    console.log(`Talk It Out API listening on http://localhost:${config.port} (/ and /api/v1)`);
  });

  let stopWorker: (() => void) | undefined;
  if (stubWorkerShouldRun(config)) {
    stopWorker = startStubWorkerLoop(pool);
    console.log('Stub rewrite worker running in-process (NOT the real NLP pipeline).');
  } else if (config.runStubWorker && config.pipelineMode === 'external') {
    // The external Python worker owns the jobs; the stub must not compete.
    console.log(
      'PIPELINE_MODE=external: stub rewrite worker suppressed; the external worker claims at /internal/pipeline/*.',
    );
  }

  let stopFeedWorker: (() => void) | undefined;
  if (config.runFeedWorker) {
    const provider = createFeedProvider(config.feedProvider);
    stopFeedWorker = startFeedWorkerLoop(pool, provider);
    console.log(`Feed analysis worker running in-process (provider: ${config.feedProvider}).`);
  }

  const shutdown = async () => {
    stopWorker?.();
    stopFeedWorker?.();
    server.close();
    await pool.end();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('Failed to start server:', err instanceof Error ? err.message : err);
  process.exit(1);
});
