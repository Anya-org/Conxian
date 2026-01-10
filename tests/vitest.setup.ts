import { beforeEach } from 'vitest';
import { setup } from './setup-test-env';

beforeEach(async () => {
    const { simnet } = await setup();
    globalThis.simnet = simnet;
});
