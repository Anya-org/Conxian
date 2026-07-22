import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const error = (code: number) => Cl.error(Cl.uint(code));

describe('Revenue distributor initializer access control', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  const readAdmin = () => simnet.callReadOnlyFn(
    'revenue-distributor',
    'get-admin',
    [],
    deployer,
  ).result;

  it('rejects unauthorized initialization and prevents initializer reuse after handoff', () => {
    expect(readAdmin()).toEqual(Cl.principal(deployer));
    expect(simnet.callPublicFn(
      'revenue-distributor',
      'initialize',
      [Cl.principal(wallet2)],
      wallet1,
    ).result).toEqual(error(1000));
    expect(readAdmin()).toEqual(Cl.principal(deployer));

    expect(simnet.callPublicFn(
      'revenue-distributor',
      'initialize',
      [Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(readAdmin()).toEqual(Cl.principal(wallet1));

    // Neither the new admin nor the original deployer can reuse initialize;
    // post-init handoffs must use the guarded set-admin endpoint.
    expect(simnet.callPublicFn(
      'revenue-distributor',
      'initialize',
      [Cl.principal(wallet2)],
      wallet1,
    ).result).toEqual(error(1000));
    expect(simnet.callPublicFn(
      'revenue-distributor',
      'initialize',
      [Cl.principal(wallet2)],
      deployer,
    ).result).toEqual(error(1000));

    expect(simnet.callPublicFn(
      'revenue-distributor',
      'set-admin',
      [Cl.principal(deployer)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(readAdmin()).toEqual(Cl.principal(deployer));
  });
});
