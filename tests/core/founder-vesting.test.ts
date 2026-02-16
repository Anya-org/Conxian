import { describe, expect, it, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

const CONTRACT_NAME = 'founder-vesting';

describe('Founder Vesting Contract', () => {
  let simnet: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('allows the contract owner to initialize the contract', () => {
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      'initialize',
      [Cl.principal(deployer)],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('allows the owner to add a vesting schedule', () => {
    simnet.callPublicFn(CONTRACT_NAME, 'initialize', [Cl.principal(deployer)], deployer);

    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      'add-vesting-schedule',
      [
        Cl.principal(wallet1),
        Cl.uint(1000000),
        Cl.uint(1700000000),
        Cl.uint(1700001000),
      ],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
