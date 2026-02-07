import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Proposal Engine - Core Functionality', () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(async () => {
    
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  // Helper to mint a seat for wallet1 on Council 1
  const mintSeat = () => {
    simnet.callPublicFn(
      "enhanced-governance-nft",
      "mint-seat",
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1),
        Cl.uint(100),
        Cl.stringAscii("human"),
      ],
      deployer
    );
  };

  it("requires a seat to submit a proposal", () => {
    // Try without seat
    const failProp = simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"), // using mock
        Cl.uint(1), // Council 1
        Cl.uint(10),
        Cl.uint(100),
      ],
      wallet1
    );
    expect(failProp.result).toEqual(Cl.error(Cl.uint(1000))); // ERR_UNAUTHORIZED (no seat) or panic unwrapping 0

    // Mint Seat
    mintSeat();

    // Retry with seat
    const successProp = simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(1),
        Cl.uint(10),
        Cl.uint(100),
      ],
      wallet1
    );
    expect(successProp.result).toEqual(Cl.ok(Cl.uint(1)));
  });

  it("allows a seat holder to vote on a proposal", () => {
    mintSeat();

    // Create Proposal
    simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(1),
        Cl.uint(10),
        Cl.uint(100),
      ],
      wallet1
    );

    // Fast forward to start block (10)
    for (let i = 0; i < 10; i++) simnet.mineEmptyBlock();

    const vote = simnet.callPublicFn(
      "proposal-engine",
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      wallet1
    );
    expect(vote.result).toEqual(Cl.ok(Cl.bool(true)));

    // Check registry for votes
    const proposal = simnet.callReadOnlyFn(
      "proposal-registry",
      "get-proposal",
      [Cl.uint(1)],
      deployer
    );
    const props = (proposal.result as any).value.data;
    expect(props["for-votes"]).toEqual(Cl.uint(100)); // Equal to seat power
  });

  it("prevents voting before start block", () => {
    mintSeat();

    // Create Proposal starting at block 100
    simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(1),
        Cl.uint(100),
        Cl.uint(200),
      ],
      wallet1
    );

    // Try voting immediately (block < 100)
    const vote = simnet.callPublicFn(
      "proposal-engine",
      "vote",
      [Cl.uint(1), Cl.bool(true)],
      wallet1
    );
    // Expect ERR_NOT_FOUND (u1001) or whatever check fails first
    // In code: (asserts! (>= block-height (get start-block proposal)) ERR_NOT_FOUND)
    expect(vote.result).toEqual(Cl.error(Cl.uint(1001)));
  });
});