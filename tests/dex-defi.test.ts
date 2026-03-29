import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('DEX and DeFi Core Existence', () => {
  let simnet: any;

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it('should have primary DEX and Core contracts deployed', () => {
    expect(simnet.getContractSource('concentrated-liquidity-pool')).toBeDefined();
    expect(simnet.getContractSource('swap-router')).toBeDefined();
    expect(simnet.getContractSource('dex-factory')).toBeDefined();
    expect(simnet.getContractSource('bme-engine')).toBeDefined();
    expect(simnet.getContractSource('enhanced-circuit-breaker')).toBeDefined();
    expect(simnet.getContractSource('agent-risk')).toBeDefined();
    expect(simnet.getContractSource('fiscal-orchestrator')).toBeDefined();
  });
});
