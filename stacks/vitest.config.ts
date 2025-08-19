import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    testTimeout: 60000,
    include: ['tests/**/*.ts', 'sdk-tests/**/*.spec.ts'],
    setupFiles: ['./global-vitest.setup.ts']
  },
});