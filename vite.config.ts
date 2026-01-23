import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import { nodePolyfills } from 'vite-plugin-node-polyfills';
import wasm from "vite-plugin-wasm";
import topLevelAwait from "vite-plugin-top-level-await";

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, '.', '');
    const isVitest = process.env.VITEST === 'true';
    return {
      server: {
        port: 3000,
        host: "0.0.0.0",
      },
      plugins: [
        wasm(),
        topLevelAwait(),
        react(),
        ...(!isVitest
          ? [
              nodePolyfills({
                include: ["buffer", "stream", "util", "crypto", "string_decoder"],
                globals: {
                  Buffer: true,
                  global: true,
                  process: true,
                },
              }),
            ]
          : []),
      ],
      test: {
        globals: true,
        environment: "node", // Changed from jsdom to node for crypto/buffer support
        setupFiles: "./tests/setup.ts",
        server: {
          deps: {
            inline: [
              "generator-function",
              "is-generator-function",
              "bip32",
              "ecpair",
              "tiny-secp256k1",
            ],
          },
        },
        pool: "forks", // More stable for native modules
      },
      define: {
        "process.env.API_KEY": JSON.stringify(env.GEMINI_API_KEY),
        "process.env.GEMINI_API_KEY": JSON.stringify(env.GEMINI_API_KEY),
      },
      resolve: {
        alias: {
          "@": path.resolve(__dirname, "."),
        },
      },
    };
});
