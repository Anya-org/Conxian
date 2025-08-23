import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.ts', 'sdk-tests/**/*.spec.ts'],
  exclude: ['tests/helpers/**'],
    testTimeout: 120000,
    hookTimeout: 90000,
    globals: true,
    setupFiles: ['./global-vitest.setup.ts'],
  },
});