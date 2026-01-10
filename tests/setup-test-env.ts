import { initSimnet } from '@stacks/clarinet-sdk';

export async function setup() {
    const manifestPath = process.env.CLARINET_MANIFEST_PATH!;
    const simnet = await initSimnet(manifestPath);
    return { simnet };
}
