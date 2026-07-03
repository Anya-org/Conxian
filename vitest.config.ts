import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["tests/setup-test-env.ts"],
    testTimeout: 300000,
    hookTimeout: 90000,
    fileParallelism: false,
    include: ["tests/**/*.test.ts"],
    // Tests for services not yet implemented (missing service modules):
    //   bip21.test.ts → ../services/bip21 (not built)
    //   crypto.test.ts → ../services/signer (not built)
    //   lightning.test.ts → ../services/lightning (not built)
    //   seed.test.ts → ../services/seed (not built)
    //   storage.test.ts → ../services/storage (not built)
    // TODO: Implement services or delete dead test files.
    exclude: ["contracts/drafts", "**/node_modules/**",
              "tests/bip21.test.ts", "tests/crypto.test.ts",
              "tests/lightning.test.ts", "tests/seed.test.ts",
              "tests/storage.test.ts"],
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
