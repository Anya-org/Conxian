import { defineConfig } from 'vitest/config';

// DEPRECATED: This stacks/vitest.config.ts is not used by CI/tests.
// Use the root-level vitest.config.ts instead to avoid configuration drift.
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