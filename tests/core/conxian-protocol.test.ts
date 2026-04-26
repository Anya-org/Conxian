import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';
const CONTRACT_NAME = 'conxian-protocol';

describe('Conxian Protocol Core Tests', () => {
    let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    // Standard names in @stacks/clarinet-sdk are wallet_1, wallet_2 etc.
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('should have a valid deployer', () => {
    expect(deployer).toBeDefined();
    expect(wallet1).toBeDefined();
    expect(wallet2).toBeDefined();
  });

  it('ensures the protocol owner is the deployer upon initialization', () => {
    const owner = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-admin',
      [],
      deployer
    );
    expect(owner.result).toEqual(Cl.principal(deployer));
  });

  it('allows the owner to transfer ownership', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'set-owner',
        [Cl.principal(wallet1)],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const newOwner = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-admin',
      [],
      deployer
    );
    expect(newOwner.result).toEqual(Cl.principal(wallet1));

    // Reset owner for next tests if they use deployer as owner
    simnet.callPublicFn(CONTRACT_NAME, 'set-owner', [Cl.principal(deployer)], wallet1);
  });

  it('prevents non-owners from transferring ownership', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'set-owner',
        [Cl.principal(wallet2)],
        wallet2 // wallet2 is not owner
      )
    expect(result).toEqual(Cl.error(Cl.uint(1000))); // ERR_UNAUTHORIZED
  });

  it('allows the owner to pause and unpause the protocol', () => {
    let { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'set-paused',
        [Cl.bool(true)],
        deployer
      )
    // If it fails with 1000, it means deployer is not owner anymore.
    // Let's check who the owner is.
    const currentOwner = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-protocol-admin', [], deployer).result;
    console.log("Current owner:", Cl.prettyPrint(currentOwner));

    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    let isPaused = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'is-paused',
      [],
      deployer
    );
    expect(isPaused.result).toEqual(Cl.bool(true));

    result = simnet.callPublicFn(
        CONTRACT_NAME,
        'set-paused',
        [Cl.bool(false)],
        deployer
      ).result
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('allows the owner to register a module', () => {
    const { result } = simnet.callPublicFn(
        CONTRACT_NAME,
        'register-module',
        [Cl.stringAscii("test-module"), Cl.principal(wallet1)],
        deployer
      )
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
