import { initSimnet, Simnet } from '@stacks/clarinet-sdk';
import { beforeEach } from 'vitest';

const manifestPath = process.env.CLARINET_MANIFEST_PATH!;

const simnet = await initSimnet(manifestPath);

beforeEach(async () => {
  await simnet.reload();
});

declare global {
  var simnet: Simnet;
}

globalThis.simnet = simnet;
