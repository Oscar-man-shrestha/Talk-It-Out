import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Every file shares one test database; parallel files would truncate
    // each other's fixtures mid-test.
    fileParallelism: false,
    testTimeout: 20000,
    hookTimeout: 30000,
  },
});
