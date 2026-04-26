import { describe, expect, it, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CONTRACT_NAME = 'oracle-aggregator';
const ASSET = Cl.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cxd-token');

describe('Oracle Aggregator Security Hardening', () => {
  let accounts: any;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  beforeEach(() => {
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;

    // Reset/Initialize
    simnet.callPublicFn(CONTRACT_NAME, 'set-source-authorized', [Cl.principal(wallet1), Cl.bool(true)], deployer);
    simnet.callPublicFn(CONTRACT_NAME, 'set-source-authorized', [Cl.principal(wallet2), Cl.bool(true)], deployer);
  });

  it('should reject prices from unauthorized sources', () => {
    const wallet3 = accounts.get('wallet_3')!;
    const res = simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100000000)], wallet3);
    expect(res.result).toEqual(Cl.error(Cl.uint(1000))); // ERR_UNAUTHORIZED
  });

  it('should require minimum sources (quorum) for get-price', () => {
    // Submit one price
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100000000)], wallet1);

    // get-price should fail quorum (needs 2)
    const res = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], deployer);
    expect(res.result).toEqual(Cl.error(Cl.uint(1007))); // ERR_INSUFFICIENT_SOURCES
  });

  it('should accept price when quorum is met', () => {
    // Submit prices from both authorized sources
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100000000)], wallet1);
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(110000000)], wallet2);

    // get-price should succeed: (100 + 110) / 2 = 105
    const res = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.uint(105000000)));
  });

  it('should reject outlier prices (high deviation)', () => {
    // Wallet 1 reports 100
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100000000)], wallet1);

    // Wallet 2 reports 150 (50% deviation, max is 10%)
    const res = simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(150000000)], wallet2);
    expect(res.result).toEqual(Cl.error(Cl.uint(1006))); // ERR_DEVIATION_TOO_HIGH
  });

  it('should fail closed on stale prices', () => {
    // Submit fresh prices
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100000000)], wallet1);
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100000000)], wallet2);

    // Advance time beyond MAX_PRICE_AGE (144)
    simnet.mineEmptyBlocks(150);

    const res = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], deployer);
    expect(res.result).toEqual(Cl.error(Cl.uint(1002))); // ERR_STALE_PRICE
  });
});
