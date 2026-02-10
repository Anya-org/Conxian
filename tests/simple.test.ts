import { describe, expect, it, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Simple Test', () => {
  let simnet: any;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    deployer = simnet.deployer;
  });

  it('should load conxian-access', () => {
    const owner = simnet.callReadOnlyFn('conxian-access', 'get-contract-owner', [], deployer);
    expect(owner.result).toBeDefined();
  });

  it('should load dimensional-core', () => {
    const state = simnet.callReadOnlyFn('dimensional-core', 'calculate-tvl', [], deployer);
    expect(state.result).toBeDefined();
  });

  it('should load agent-risk', () => {
    const gcr = simnet.callReadOnlyFn('agent-risk', 'get-gcr', [], deployer);
    expect(gcr.result).toBeDefined();
  });

  it('should load agent-treasury', () => {
    const threshold = simnet.callReadOnlyFn('agent-treasury', 'apply-fiscal-dam', [], deployer);
    // apply-fiscal-dam is public, but let's check if it exists
    expect(threshold.result).toBeDefined();
  });

  it('should load ops-engine', () => {
    const lastAction = simnet.callReadOnlyFn('ops-engine', 'get-last-action', [], deployer);
    expect(lastAction.result).toBeDefined();
  });
});
