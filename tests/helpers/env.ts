// Environment configuration for integration tests
export const HEAVY_DISABLED = process.env.HEAVY_TESTS === 'false' || process.env.CI === 'true';
