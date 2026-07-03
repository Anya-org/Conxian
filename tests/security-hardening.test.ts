import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Security Hardening Verification', () => {
  let simnet: any;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    deployer = simnet.deployer;
    const accounts = simnet.getAccounts();
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('should fail-closed when circuit breaker is triggered', () => {
    simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-contract-pause',
      [Cl.contractPrincipal(deployer, 'lending-manager')],
      deployer
    );

    const { result } = simnet.callPublicFn(
      'lending-manager',
      'deposit',
      [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(1000)],
      deployer
    );

    expect(result).toEqual(Cl.error(Cl.uint(1001)));
  });

  it('oracle should fail-closed when price is stale', () => {
    const asset = Cl.contractPrincipal(deployer, 'cxd-token');

    // 1. Authorize sources
    simnet.callPublicFn('oracle-aggregator', 'set-source-authorized', [Cl.standardPrincipal(wallet1), Cl.bool(true)], deployer);
    simnet.callPublicFn('oracle-aggregator', 'set-source-authorized', [Cl.standardPrincipal(wallet2), Cl.bool(true)], deployer);

    // 2. Submit prices
    simnet.callPublicFn('oracle-aggregator', 'submit-price', [asset, Cl.uint(100000000)], wallet1);
    simnet.callPublicFn('oracle-aggregator', 'submit-price', [asset, Cl.uint(100000000)], wallet2);

    // 3. Advance blocks
    simnet.mineEmptyBlocks(200);

    // 4. Check price - should be ERR_STALE_PRICE (1002)
    const { result } = simnet.callReadOnlyFn(
      'oracle-aggregator',
      'get-price',
      [asset],
      deployer
    );

    expect(result.type).toBe('err');
  });
});
