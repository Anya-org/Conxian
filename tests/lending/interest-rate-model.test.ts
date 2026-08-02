import { describe, it, expect, beforeEach } from 'vitest';
import { simnet, accounts } from '../setup-test-env';
import { Cl, Clarinet } from '@stacks/transactions';

const ASSET = () => accounts.deployer.address;

describe('interest-rate-model', () => {
  beforeEach(() => {
    // Initialize contract with deployer
    simnet.callPublicFn(
      'interest-rate-model',
      'initialize',
      [Cl.principal(accounts.deployer.address)],
      accounts.deployer.address
    );
  });

  describe('get-borrow-rate', () => {
    it('should return 0 at 0% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(ASSET()), Cl.uint(0)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok u0)');
    });

    it('should calculate rate below kink (50% utilization)', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(ASSET()), Cl.uint(5000)],
        accounts.deployer.address
      );
      // Default: base=0, slope1=400, at 50% (5000 bps): rate = 0 + (5000 * 400 / 10000) = 200
      expect(Cl.prettyPrint(result.result)).toBe('(ok u200)');
    });

    it('should calculate rate at kink (80% utilization)', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(ASSET()), Cl.uint(8000)],
        accounts.deployer.address
      );
      // Default: at 80% kink: rate = 0 + (8000 * 400 / 10000) = 320
      expect(Cl.prettyPrint(result.result)).toBe('(ok u320)');
    });

    it('should apply jump rate above kink (100% utilization)', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(ASSET()), Cl.uint(10000)],
        accounts.deployer.address
      );
      // At 100%: kinkRate=320 + excess(2000)*slope2(8000)/10000 = 320 + 1600 = 1920
      expect(Cl.prettyPrint(result.result)).toBe('(ok u1920)');
    });
  });

  describe('get-supply-rate', () => {
    it('should return 0 at 0% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-supply-rate',
        [Cl.principal(ASSET()), Cl.uint(0)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok u0)');
    });

    it('should calculate supply rate at 50% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-supply-rate',
        [Cl.principal(ASSET()), Cl.uint(5000)],
        accounts.deployer.address
      );
      // borrowRate=200, utilization=5000, reserveFactor=1000(10%)
      // supplyRate = 200 * 5000 * 9000 / 100000000 = 90
      expect(Cl.prettyPrint(result.result)).toBe('(ok u90)');
    });
  });

  describe('get-utilization-rate', () => {
    it('should calculate 50% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-utilization-rate',
        [Cl.uint(1000000), Cl.uint(500000)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok u5000)');
    });

    it('should return 0 when deposits are 0', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-utilization-rate',
        [Cl.uint(0), Cl.uint(0)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok u0)');
    });
  });

  describe('calculate-interest', () => {
    it('should calculate annual interest correctly', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'calculate-interest',
        [Cl.uint(1000000), Cl.uint(1000), Cl.uint(31536000)],
        accounts.deployer.address
      );
      // 1000000 tokens * 1000 bps * 1 year / (10000 bps * 31536000 seconds) * 31536000 = 100000
      expect(Cl.prettyPrint(result.result)).toBe('u100000');
    });

    it('should calculate half-year interest', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'calculate-interest',
        [Cl.uint(1000000), Cl.uint(1000), Cl.uint(15768000)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('u50000');
    });
  });

  describe('admin functions', () => {
    it('should set custom asset parameters', () => {
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'set-asset-params',
        [
          Cl.principal(ASSET()),
          Cl.uint(100),   // base-rate
          Cl.uint(500),   // slope1
          Cl.uint(8000),  // slope2
          Cl.uint(7500),  // kink
          Cl.uint(1000)   // reserve-factor
        ],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok true)');
    });

    it('should reject unauthorized admin access', () => {
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'set-asset-params',
        [
          Cl.principal(ASSET()),
          Cl.uint(100),
          Cl.uint(500),
          Cl.uint(8000),
          Cl.uint(7500),
          Cl.uint(1000)
        ],
        accounts.wallet_1.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(err u1001)');
    });

    it('should configure STX market', () => {
      const stxAsset = accounts.wallet_1.address;
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'configure-stx-market',
        [Cl.principal(stxAsset)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok true)');
    });

    it('should configure sBTC market', () => {
      const sbtcAsset = accounts.wallet_2.address;
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'configure-sbtc-market',
        [Cl.principal(sbtcAsset)],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toBe('(ok true)');
    });
  });

  describe('get-protocol-status', () => {
    it('should return protocol status', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-protocol-status',
        [],
        accounts.deployer.address
      );
      expect(Cl.prettyPrint(result.result)).toContain('model-version');
      expect(Cl.prettyPrint(result.result)).toContain('admin');
    });
  });
});
