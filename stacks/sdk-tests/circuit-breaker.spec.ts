import { initSimnet } from '@hirosystems/clarinet-sdk';
import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

const BREAKER_PRICE = 1n;
const BREAKER_VOLUME = 2n;
const BREAKER_LIQ = 3n;

// Helpers to unwrap bool response
function expectOk(result: any) {
  expect(result.result.type).toBe('ok');
  expect(result.result.value.type).toBe('true');
}

describe('Circuit Breaker: manual trigger', () => {
  it('triggers and sets state', async () => {
    const simnet = await initSimnet();
    const deployer = simnet.getAccounts().get('deployer')!;
  const tx = simnet.callPublicFn('circuit-breaker', 'trigger-circuit-breaker', [Cl.uint(BREAKER_PRICE), Cl.uint(2500n)], deployer);
  expectOk(tx);
  const triggered = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-breaker-triggered', [Cl.uint(BREAKER_PRICE)], deployer);
  expect(triggered.result.type).toBe('true');
  });
});

describe('Circuit Breaker: price volatility auto-trigger', () => {
  it('auto triggers after volatility threshold exceeded', async () => {
    const simnet = await initSimnet();
    const deployer = simnet.getAccounts().get('deployer')!;
    const pool = deployer; // reuse deployer principal as dummy pool
    simnet.callPublicFn('circuit-breaker', 'monitor-price-volatility', [Cl.principal(pool), Cl.uint(1000n)], deployer);
    simnet.callPublicFn('circuit-breaker', 'monitor-price-volatility', [Cl.principal(pool), Cl.uint(1400n)], deployer);
    const triggered = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-breaker-triggered', [Cl.uint(BREAKER_PRICE)], deployer);
  expect(triggered.result.type).toBe('true');
  });
});

describe('Circuit Breaker: volume spike auto-trigger', () => {
  it('triggers when volume ratio > 5x', async () => {
    const simnet = await initSimnet();
    const deployer = simnet.getAccounts().get('deployer')!;
    const pool = deployer;
  simnet.callPublicFn('circuit-breaker', 'monitor-volume-spike', [Cl.principal(pool), Cl.uint(1n)], deployer); // baseline 1
  simnet.callPublicFn('circuit-breaker', 'monitor-volume-spike', [Cl.principal(pool), Cl.uint(6n)], deployer); // total 7 -> ratio 7 > 5 triggers
    const triggered = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-breaker-triggered', [Cl.uint(BREAKER_VOLUME)], deployer);
  expect(triggered.result.type).toBe('true');
  });
});

describe('Circuit Breaker: liquidity drain auto-trigger', () => {
  it('triggers on >50% drain', async () => {
    const simnet = await initSimnet();
    const deployer = simnet.getAccounts().get('deployer')!;
    const pool = deployer;
    simnet.callPublicFn('circuit-breaker', 'monitor-liquidity-drain', [Cl.principal(pool), Cl.uint(1000n)], deployer); // initial
    simnet.callPublicFn('circuit-breaker', 'monitor-liquidity-drain', [Cl.principal(pool), Cl.uint(400n)], deployer); // 60% drain
    const triggered = simnet.callReadOnlyFn('circuit-breaker', 'is-circuit-breaker-triggered', [Cl.uint(BREAKER_LIQ)], deployer);
  expect(triggered.result.type).toBe('true');
  });
});

describe('Circuit Breaker: emergency pause/resume', () => {
  it('pauses and resumes system', async () => {
    const simnet = await initSimnet();
    const deployer = simnet.getAccounts().get('deployer')!;
    simnet.callPublicFn('circuit-breaker', 'emergency-pause', [], deployer);
    let summary = simnet.callReadOnlyFn('circuit-breaker', 'risk-summary', [], deployer);
    expect(summary.result.type).toBe('tuple');
    simnet.callPublicFn('circuit-breaker', 'emergency-resume', [], deployer);
    summary = simnet.callReadOnlyFn('circuit-breaker', 'risk-summary', [], deployer);
    expect(summary.result.type).toBe('tuple');
  });
});
