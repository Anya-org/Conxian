import { initSimnet, Simnet } from '@stacks/clarinet-sdk';

const manifestPath = process.env.CLARINET_MANIFEST_PATH || "./Clarinet.toml";

const simnet = await initSimnet(manifestPath);

declare global {
  var simnet: Simnet;
}

globalThis.simnet = simnet;
