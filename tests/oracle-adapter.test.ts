
import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const CONTRACT_NAME = 'federated-oracle-adapter';
const ASSET = Cl.principal('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.asset-token');

describe('Federated Oracle Adapter Tests', () => {
  it('should initialize correctly and reject unauthorized price submission', () => {
    const accounts = simnet.getAccounts();
    const WALLET_1 = accounts.get('wallet_1')!;
    const result = simnet.callPublicFn(
      CONTRACT_NAME,
      'submit-price',
      [ASSET, Cl.uint(1000)],
      WALLET_1
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(6000))); // ERR_UNAUTHORIZED
  });

  it('should allow admin to add oracle sources and set required sources', () => {
    const accounts = simnet.getAccounts();
    const ADMIN = accounts.get('deployer')!;
    const WALLET_1 = accounts.get('wallet_1')!;
    const WALLET_2 = accounts.get('wallet_2')!;
    const WALLET_3 = accounts.get('wallet_3')!;

    // Add 3 oracle sources
    simnet.callPublicFn(CONTRACT_NAME, 'add-oracle-source', [Cl.principal(WALLET_1), Cl.uint(1)], ADMIN);
    simnet.callPublicFn(CONTRACT_NAME, 'add-oracle-source', [Cl.principal(WALLET_2), Cl.uint(2)], ADMIN);
    const addResult = simnet.callPublicFn(CONTRACT_NAME, 'add-oracle-source', [Cl.principal(WALLET_3), Cl.uint(1)], ADMIN);
    expect(addResult.result).toEqual(Cl.ok(Cl.bool(true)));

    // Set required sources to 3
    const result = simnet.callPublicFn(CONTRACT_NAME, 'set-required-sources', [Cl.uint(3)], ADMIN);
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should calculate weighted average correctly after enough sources report', () => {
    const accounts = simnet.getAccounts();
    const ADMIN = accounts.get('deployer')!;
    const WALLET_1 = accounts.get('wallet_1')!;
    const WALLET_2 = accounts.get('wallet_2')!;
    const WALLET_3 = accounts.get('wallet_3')!;

    // Oracle 1 reports 100
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(100)], WALLET_1);

    // Check price - should be NOT_FOUND because only 1 source reported (need 3)
    let priceResult = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], ADMIN);
    expect(priceResult.result).toEqual(Cl.error(Cl.uint(6002))); // ERR_NOT_FOUND

    // Oracle 2 reports 200
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(200)], WALLET_2);

    // Oracle 3 reports 150
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(150)], WALLET_3);

    // Weighted average: (100*1 + 200*2 + 150*1) / (1 + 2 + 1) = (100 + 400 + 150) / 4 = 650 / 4 = 162.5 -> 162
    priceResult = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], ADMIN);
    expect(priceResult.result).toEqual(Cl.ok(Cl.uint(162)));
  });

  it('should handle stale prices correctly', () => {
    const accounts = simnet.getAccounts();
    const ADMIN = accounts.get('deployer')!;

    // Current burn-block-height in simnet is incremented as we mine
    // Fast forward blocks (MAX_PRICE_AGE is 100)
    simnet.mineEmptyBlocks(101);

    const priceResult = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], ADMIN);
    expect(priceResult.result).toEqual(Cl.error(Cl.uint(6001))); // ERR_STALE_PRICE
  });

  it('should exclude inactive sources from calculation', () => {
    const accounts = simnet.getAccounts();
    const ADMIN = accounts.get('deployer')!;
    const WALLET_1 = accounts.get('wallet_1')!;
    const WALLET_2 = accounts.get('wallet_2')!;
    const WALLET_3 = accounts.get('wallet_3')!;

    // Remove WALLET_3
    simnet.callPublicFn(CONTRACT_NAME, 'remove-oracle-source', [Cl.principal(WALLET_3)], ADMIN);

    // Submit fresh prices for WALLET_1 and WALLET_2
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(1000)], WALLET_1);
    simnet.callPublicFn(CONTRACT_NAME, 'submit-price', [ASSET, Cl.uint(2000)], WALLET_2);

    // Now only WALLET_1 and WALLET_2 are active. Required is 3.
    // Recalculate will return (ok false), so get-price should return STALE (old value) or NOT_FOUND if we had a way to clear it.
    // In our implementation, it keeps the old value in price-data but it's stale.
    const priceResult = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-price', [ASSET], ADMIN);
    expect(priceResult.result).toEqual(Cl.error(Cl.uint(6001))); // ERR_STALE_PRICE
  });
});
