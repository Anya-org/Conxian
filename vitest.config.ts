import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/vitest.setup.ts"],
    env: {
        CLARINET_MANIFEST_PATH: "./Clarinet.toml"
    }
  },
});
