import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Conxian Chaos Engineering Suite', () => {
  let deployer: string;

  beforeEach(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  function unwrap(val: any): any {
    if (val && typeof val === 'object') {
      if ('value' in val) return unwrap(val.value);
      if ('data' in val) return val.data;
    }
    return val;
  }

  describe('Phase 1: Deterministic Logic & State Integrity', () => {
    it('Target 1 (Anti-LVR): DEX volatility fee updates via Heartbeat', () => {
      const heartbeat = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], deployer);
      expect(heartbeat.result).toStrictEqual(Cl.ok(Cl.bool(true)));
    });

    it('Target 2 (Fiscal Dam): Agent-Risk provides cybernetic telemetry', () => {
      const intelRes = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
      const intel = unwrap(intelRes.result);
      expect(intel['financial-gcr']).toBeDefined();
      expect(intel['operational-fee']).toBeDefined();
      expect(intel['risk-score']).toBeDefined();
    });
  });

  describe('Phase 2: Property-Based Logic', () => {
    it('Resilience: GCR Crisis (u100) triggers High Risk Score (900)', () => {
       simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(100)], deployer);
       const intelRes = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
       const intel = unwrap(intelRes.result);
       expect(unwrap(intel['risk-score'])).toBe(900n);
    });

    it('Resilience: GCR Abundance (u150) triggers Healthy Risk Score (100)', () => {
       simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(150)], deployer);
       const intelRes = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
       const intel = unwrap(intelRes.result);
       expect(unwrap(intel['risk-score'])).toBe(100n);
    });
  });
});
