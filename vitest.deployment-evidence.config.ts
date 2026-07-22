import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    fileParallelism: false,
    include: [
      "tests/deployment-evidence.test.ts",
      "tests/deploy-testnet-script.test.ts",
      "tests/deployment-workflows.test.ts",
    ],
    testTimeout: 120_000,
    hookTimeout: 30_000,
  },
});
