import { describe, it, expect, beforeEach } from 'vitest';
import { simnet } from '../setup-test-env';
import { Cl } from '@stacks/transactions';

describe('interest-rate-model', () => {
  let deployer: string;
  let wallet1: string;
  let asset: string;

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    asset = accounts.get('wallet_2')!;

    // Initialize contract with deployer
    simnet.callPublicFn(
      'interest-rate-model',
      'initialize',
      [Cl.principal(deployer)],
      deployer
    );
  });

  describe('get-borrow-rate', () => {
    it('should return 0 at 0% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(asset), Cl.uint(0)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.uint(0)));
    });

    it('should calculate rate below kink (50% utilization)', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(asset), Cl.uint(5000)],
        deployer
      );
      // Default: base=0, slope1=400, at 50% (5000 bps): rate = 0 + (5000 * 400 / 10000) = 200
      expect(result.result).toEqual(Cl.ok(Cl.uint(200)));
    });

    it('should calculate rate at kink (80% utilization)', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(asset), Cl.uint(8000)],
        deployer
      );
      // Default: at 80% kink: rate = 0 + (8000 * 400 / 10000) = 320
      expect(result.result).toEqual(Cl.ok(Cl.uint(320)));
    });

    it('should apply jump rate above kink (100% utilization)', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-borrow-rate',
        [Cl.principal(asset), Cl.uint(10000)],
        deployer
      );
      // At 100%: kinkRate=320 + excess(2000)*slope2(8000)/10000 = 320 + 1600 = 1920
      expect(result.result).toEqual(Cl.ok(Cl.uint(1920)));
    });
  });

  describe('get-supply-rate', () => {
    it('should return 0 at 0% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-supply-rate',
        [Cl.principal(asset), Cl.uint(0)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.uint(0)));
    });

    it('should calculate supply rate at 50% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-supply-rate',
        [Cl.principal(asset), Cl.uint(5000)],
        deployer
      );
      // borrowRate=200, utilization=5000, reserveFactor=1000(10%)
      // supplyRate = 200 * 5000 * 9000 / 100000000 = 90
      expect(result.result).toEqual(Cl.ok(Cl.uint(90)));
    });
  });

  describe('get-utilization-rate', () => {
    it('should calculate 50% utilization', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-utilization-rate',
        [Cl.uint(1000000), Cl.uint(500000)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.uint(5000)));
    });

    it('should return 0 when deposits are 0', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-utilization-rate',
        [Cl.uint(0), Cl.uint(0)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.uint(0)));
    });
  });

  describe('calculate-interest', () => {
    it('should calculate annual interest correctly', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'calculate-interest',
        [Cl.uint(1000000), Cl.uint(1000), Cl.uint(31536000)],
        deployer
      );
      // 1000000 tokens * 1000 bps * 1 year / (10000 bps * 31536000 seconds) * 31536000 = 100000
      expect(result.result).toEqual(Cl.uint(100000));
    });

    it('should calculate half-year interest', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'calculate-interest',
        [Cl.uint(1000000), Cl.uint(1000), Cl.uint(15768000)],
        deployer
      );
      expect(result.result).toEqual(Cl.uint(50000));
    });
  });

  describe('admin functions', () => {
    it('should set custom asset parameters', () => {
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'set-asset-params',
        [
          Cl.principal(asset),
          Cl.uint(100),   // base-rate
          Cl.uint(500),   // slope1
          Cl.uint(8000),  // slope2
          Cl.uint(7500),  // kink
          Cl.uint(1000)   // reserve-factor
        ],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });

    it('should reject unauthorized admin access', () => {
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'set-asset-params',
        [
          Cl.principal(asset),
          Cl.uint(100),
          Cl.uint(500),
          Cl.uint(8000),
          Cl.uint(7500),
          Cl.uint(1000)
        ],
        wallet1
      );
      expect(result.result).toEqual(Cl.error(Cl.uint(1001)));
    });

    it('should configure STX market', () => {
      const stxAsset = simnet.getAccounts().get('wallet_3')!;
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'configure-stx-market',
        [Cl.principal(stxAsset)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });

    it('should configure sBTC market', () => {
      const sbtcAsset = simnet.getAccounts().get('wallet_3')!;
      const result = simnet.callPublicFn(
        'interest-rate-model',
        'configure-sbtc-market',
        [Cl.principal(sbtcAsset)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });
  });

  describe('get-protocol-status', () => {
    it('should return protocol status', () => {
      const result = simnet.callReadOnlyFn(
        'interest-rate-model',
        'get-protocol-status',
        [],
        deployer
      );
      expect(result.result).toBeDefined();
    });
  });
});
