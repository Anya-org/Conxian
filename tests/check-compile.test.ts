import { describe, it, expect } from 'vitest';
import { simnet } from './setup-test-env';

describe('System Compilation and Initialization', () => {
  it('should initialize simnet and verify key contracts', async () => {
    expect(simnet).toBeDefined();

    const regulatorySource = simnet.getContractSource('regulatory-adapter');
    expect(regulatorySource).toBeDefined();

    const bondFactorySource = simnet.getContractSource('bond-factory');
    expect(bondFactorySource).toBeDefined();

    console.log('✅ Basic contract existence verified');
  });
});
