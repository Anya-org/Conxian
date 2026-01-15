import { initSimnet } from '@stacks/clarinet-sdk';

async function setup() {
    const simnet = await initSimnet();
    globalThis.simnet = simnet;
}

setup();
