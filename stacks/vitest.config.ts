import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['sdk-tests/**/*.spec.ts'],
    testTimeout: 60000,
  },
});
