import { initSimnet, Simnet } from '@stacks/clarinet-sdk';

const manifestPath = process.env.CLARINET_MANIFEST_PATH!;


const simnet = await initSimnet(manifestPath);

declare global {
  var simnet: Simnet;
}

globalThis.simnet = simnet;
