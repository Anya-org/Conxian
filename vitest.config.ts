import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/setup-test-env.ts"],
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false,
    exclude: ["contracts/drafts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      include: ["contracts/**/*.clar"],
    },
  },
  poolOptions: {
    threads: {
      singleThread: true,
    },
  },
});
