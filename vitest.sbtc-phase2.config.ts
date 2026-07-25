import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    fileParallelism: false,
    include: ["tests/sbtc-phase2-evidence.test.ts"],
    testTimeout: 30_000,
  },
});
