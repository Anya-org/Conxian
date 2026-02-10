import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/setup-test-env.ts"],
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false,
    include: ["tests/**/*.test.ts", "tests/**/*.spec.ts"],
    exclude: ["contracts/drafts", "**/node_modules/**"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      include: ["tests/**/*.test.ts", "tests/**/*.spec.ts"],
    },
  },
  poolOptions: {
    threads: {
      singleThread: true,
    },
  },
});
