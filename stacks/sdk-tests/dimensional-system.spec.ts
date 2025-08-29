import {
  describe,
  it,
  expect,
} from 'vitest';
import { Simnet, Tx, Chain, Account, types } from '@hirosystems/clarinet-sdk';

const simnet = new Simnet();
const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const wallet1 = accounts.get('wallet_1')!;

describe('Dimensional DeFi System', () => {

  describe('dim-registry', () => {
    it('should allow deployer to register a new dimension', () => {
      const chain = simnet.getChain();
      const tx = Tx.contractCall('dim-registry', 'register-dimension', [types.uint(1), types.ascii('STX'), types.uint(100)], deployer.address);
      const receipt = chain.mine(tx);
      expect(receipt.result).toBeOk(types.bool(true));
    });

    it('should not allow non-deployer to register a new dimension', () => {
        const chain = simnet.getChain();
        const tx = Tx.contractCall('dim-registry', 'register-dimension', [types.uint(2), types.ascii('BTC'), types.uint(100)], wallet1.address);
        const receipt = chain.mine(tx);
        expect(receipt.result).toBeErr(types.uint(100)); // err-unauthorized
    });

    it('should not allow registering the same dimension twice', () => {
        const chain = simnet.getChain();
        chain.mine(Tx.contractCall('dim-registry', 'register-dimension', [types.uint(3), types.ascii('ETH'), types.uint(100)], deployer.address));
        const tx = Tx.contractCall('dim-registry', 'register-dimension', [types.uint(3), types.ascii('ETH'), types.uint(100)], deployer.address);
        const receipt = chain.mine(tx);
        expect(receipt.result).toBeErr(types.uint(103)); // err-dimension-already-registered
    });

    it('should allow deployer to update weight', () => {
        const chain = simnet.getChain();
        chain.mine(Tx.contractCall('dim-registry', 'register-dimension', [types.uint(4), types.ascii('SOL'), types.uint(100)], deployer.address));
        const tx = Tx.contractCall('dim-registry', 'update-weight', [types.uint(4), types.uint(200)], deployer.address);
        const receipt = chain.mine(tx);
        expect(receipt.result).toBeOk(types.bool(true));
    });

    it('should not allow non-deployer to update weight', () => {
        const chain = simnet.getChain();
        chain.mine(Tx.contractCall('dim-registry', 'register-dimension', [types.uint(5), types.ascii('DOT'), types.uint(100)], deployer.address));
        const tx = Tx.contractCall('dim--registry', 'update-weight', [types.uint(5), types.uint(200)], wallet1.address);
        const receipt = chain.mine(tx);
        expect(receipt.result).toBeErr(types.uint(100)); // err-unauthorized
    });

    it('should return the correct dimension by id', () => {
        const chain = simnet.getChain();
        chain.mine(Tx.contractCall('dim-registry', 'register-dimension', [types.uint(6), types.ascii('AVAX'), types.uint(150)], deployer.address));
        const dim = chain.callReadOnlyFn('dim-registry', 'get-dimension-by-id', [types.uint(6)], deployer.address);
        expect(dim.result).toStrictEqual(types.some(types.tuple({ "name": types.ascii("AVAX"), "weight": types.uint(150) })));
    });

    it('should return the correct weight', () => {
        const chain = simnet.getChain();
        chain.mine(Tx.contractCall('dim-registry', 'register-dimension', [types.uint(7), types.ascii('ADA'), types.uint(120)], deployer.address));
        const weight = chain.callReadOnlyFn('dim-registry', 'get-weight', [types.uint(7)], deployer.address);
        expect(weight.result).toBeOk(types.uint(120));
    });
  });

  describe('tokenized-bond', () => {
    it('should allow deployer to issue a new bond', () => {
        const chain = simnet.getChain();
        const issueTx = Tx.contractCall('tokenized-bond', 'issue-bond', [types.uint(1000000), types.uint(100), types.uint(10), types.uint(5)], deployer.address);
        const receipt = chain.mine(issueTx);
        expect(receipt.result).toBeOk(types.bool(true));
    });

    it('should allow users to get bond details', () => {
        const chain = simnet.getChain();
        const details = chain.callReadOnlyFn('tokenized-bond', 'get-bond-details', [], deployer.address);
        expect(details.result).toStrictEqual(types.some(types.tuple({
            "total-supply": types.uint(1000000),
            "coupon-rate": types.uint(100),
            "maturity-blocks": types.uint(10),
            "coupon-frequency": types.uint(5),
            "last-coupon-block": types.uint(0)
        })));
    });
  });
});
