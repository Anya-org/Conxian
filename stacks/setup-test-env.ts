// stacks/setup-test-env.ts
import { initSimnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';
import { beforeAll } from 'vitest';

const manifestPath = process.env.CLARINET_MANIFEST_PATH
  ? resolve(process.cwd(), process.env.CLARINET_MANIFEST_PATH)
  : resolve(__dirname, '../Clarinet.toml');

beforeAll(async () => {
  const simnet = await initSimnet(manifestPath);
  globalThis.simnet = simnet;
});
