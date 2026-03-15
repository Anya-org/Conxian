// Environment configuration for integration tests
// Set to true to skip heavy enterprise integration tests until those contracts are deployed
export const HEAVY_DISABLED = process.env.HEAVY_TESTS === 'enabled' ? false : true;
