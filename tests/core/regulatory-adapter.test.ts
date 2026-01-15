import { describe, expect, it, beforeEach, vi } from 'vitest';
import { Simnet, contract, Tx } from '@stacks/clarinet-sdk';

const regulatoryAdapter = 'regulatory-adapter';

describe('regulatory-adapter', () => {
  let simnet: Simnet;
  let deployer: string;
  let user1: string;

  beforeEach(async () => {
    simnet = await Simnet.launch();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    user1 = accounts.get('wallet_1')!;

    simnet.deployContract(regulatoryAdapter, {
      path: 'contracts/core/regulatory-adapter.clar',
      principal: deployer,
    });
  });

  it('should allow the owner to add a user to the whitelist', () => {
    const { result } = simnet.callPublicFn(
      regulatoryAdapter,
      'add-to-whitelist',
      [`'${user1}`, '"USA"'],
      deployer
    );
    expect(result).toBeOk(Tx.encodeResponse(true)));
  });

  it('should allow the owner to add a user to the blacklist', () => {
    const { result } = simnet.callPublicFn(
      regulatoryAdapter,
      'add-to-blacklist',
      [`'${user1}`],
      deployer
    );
    expect(result).toBeOk(Tx.encodeResponse(true)));
  });

  it('should allow the owner to remove a user from the blacklist', () => {
    simnet.callPublicFn(
        regulatoryAdapter,
        'add-to-blacklist',
        [`'${user1}`],
        deployer
      );
    const { result } = simnet.callPublicFn(
      regulatoryAdapter,
      'remove-from-blacklist',
      [`'${user1}`],
      deployer
    );
    expect(result).toBeOk(Tx.encodeResponse(true)));
  });

  it('should return true for a whitelisted user', () => {
    simnet.callPublicFn(
        regulatoryAdapter,
        'add-to-whitelist',
        [`'${user1}`, '"USA"'],
        deployer
      );
    const { result } = simnet.callReadOnlyFn(
      regulatoryAdapter,
      'check-clean-hands-compliance',
      [`'${user1}`],
      deployer
    );
    expect(result).toBeOk(Tx.encodeResponse(true)));
  });

  it('should return false for a blacklisted user', () => {
    simnet.callPublicFn(
        regulatoryAdapter,
        'add-to-blacklist',
        [`'${user1}`],
        deployer
      );
    const { result } = simnet.callReadOnlyFn(
      regulatoryAdapter,
      'check-clean-hands-compliance',
      [`'${user1}`],
      deployer
    );
    expect(result).toBeOk(Tx.encodeResponse(false)));
  });

  it('should return false for a user not on any list', () => {
    const { result } = simnet.callReadOnlyFn(
      regulatoryAdapter,
      'check-clean-hands-compliance',
      [`'${user1}`],
      deployer
    );
    expect(result).toBeOk(Tx.encodeResponse(false)));
  });

  it('should not allow a non-owner to add a user to the whitelist', () => {
    const { result } = simnet.callPublicFn(
      regulatoryAdapter,
      'add-to-whitelist',
      [`'${user1}`, '"USA"'],
      user1
    );
    expect(result).toBeErr(Tx.encodeResponse(6000)));
  });

  it('should not allow a non-owner to add a user to the blacklist', () => {
    const { result } = simnet.callPublicFn(
      regulatoryAdapter,
      'add-to-blacklist',
      [`'${user1}`],
      user1
    );
    expect(result).toBeErr(Tx.encodeResponse(6000)));
  });

    it('should not allow a non-owner to remove a user from the blacklist', () => {
        const { result } = simnet.callPublicFn(
          regulatoryAdapter,
          'remove-from-blacklist',
          [`'${user1}`],
          user1
        );
        expect(result).toBeErr(Tx.encodeResponse(6000)));
      });

  vi.bench('add-to-whitelist', () => {
    simnet.callPublicFn(
      regulatoryAdapter,
      'add-to-whitelist',
      [`'${user1}`, '"USA"'],
      deployer
    );
  });
});
