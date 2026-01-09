import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/setup-test-env.ts"],
    env: {
      CLARINET_MANIFEST_PATH: "Clarinet.toml",
      CLARINET_ACCOUNTS_PATH: "settings/Devnet.toml",
    },
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false, // Critical for Clarinet SDK single-threaded execution
    poolOptions: {
      threads: {
        singleThread: true,
      },
    },
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      include: ["contracts/**/*.clar"],
    },
  },
});
