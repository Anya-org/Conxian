import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/setup-test-env.ts"],
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false,
    include: ["tests/core/conxian-protocol-batch.test.ts", "tests/sanity.test.ts", "tests/simple.test.ts", "tests/root-recovery.test.ts", "tests/cxip-012.test.ts"],
    exclude: ["contracts/drafts", "**/node_modules/**"],
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
