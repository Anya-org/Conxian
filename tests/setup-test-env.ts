import { initSimnet } from '@stacks/clarinet-sdk';
import { beforeAll } from 'vitest';

beforeAll(async () => {
    const simnet = await initSimnet();
    globalThis.simnet = simnet;
});
