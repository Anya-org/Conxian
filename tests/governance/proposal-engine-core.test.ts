import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Proposal Engine - Core Functionality', () => {
  let simnet: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;

    // Grant ROLE_ADMIN (u1) to deployer in conxian-access
    simnet.callPublicFn(
      "conxian-access",
      "grant-role",
      [
        Cl.principal(deployer),
        Cl.uint(1),
        Cl.buffer(Buffer.alloc(32)),
        Cl.buffer(Buffer.alloc(64)),
        Cl.buffer(Buffer.alloc(33))
      ],
      deployer
    );
  });

  const mintSeat = () => {
    return simnet.callPublicFn(
      "enhanced-governance-nft",
      "mint-seat",
      [
        Cl.principal(wallet1),
        Cl.uint(1),
        Cl.uint(100),
        Cl.stringAscii("human"),
      ],
      deployer
    );
  };

  it("requires a seat to submit a proposal", () => {
    const failProp = simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.principal(deployer + ".mock-proposal"),
        Cl.uint(1), // Council 1
        Cl.uint(10),
        Cl.uint(100),
      ],
      wallet1
    );
    expect(failProp.result).toEqual(Cl.error(Cl.uint(1000)));

    mintSeat();

    const successProp = simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.principal(deployer + ".mock-proposal"),
        Cl.uint(1),
        Cl.uint(10),
        Cl.uint(100),
      ],
      wallet1
    );
    expect(successProp.result).toEqual(Cl.ok(Cl.uint(1)));
  });
});
