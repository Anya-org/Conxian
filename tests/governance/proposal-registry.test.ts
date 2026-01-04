import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Proposal Registry', () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get("wallet_1")!;
  });

  it("allows adding a proposal with council routing", () => {
    const add = simnet.callPublicFn(
      "proposal-registry",
      "add-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"), // Placeholder contract
        Cl.uint(1), // Council ID
        Cl.uint(10), // Start Block
        Cl.uint(100), // End Block
      ],
      deployer
    );

    expect(add.result).toBeOk(Cl.uint(1));

    const proposal = simnet.callReadOnlyFn(
      "proposal-registry",
      "get-proposal",
      [Cl.uint(1)],
      deployer
    );

    expect(proposal.result).toBeSome(
      Cl.tuple({
        proposer: Cl.standardPrincipal(deployer),
        "proposal-contract": Cl.contractPrincipal(deployer, "mock-proposal"),
        "council-id": Cl.uint(1),
        "start-block": Cl.uint(10),
        "end-block": Cl.uint(100),
        "for-votes": Cl.uint(0),
        "against-votes": Cl.uint(0),
        executed: Cl.bool(false),
        canceled: Cl.bool(false),
      })
    );
  });

  it("records votes and prevents double voting", () => {
    // Setup Proposal
    simnet.callPublicFn(
      "proposal-registry",
      "add-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(1),
        Cl.uint(10),
        Cl.uint(100),
      ],
      deployer
    );

    // Vote 1 (Support)
    const vote1 = simnet.callPublicFn(
      "proposal-registry",
      "vote-proposal",
      [
        Cl.uint(1),
        Cl.bool(true),
        Cl.uint(50), // Weight
      ],
      wallet1
    );
    expect(vote1.result).toBeOk(Cl.bool(true));

    // Check stats
    const proposalAfterVote = simnet.callReadOnlyFn(
      "proposal-registry",
      "get-proposal",
      [Cl.uint(1)],
      deployer
    );
    const props = (proposalAfterVote.result as any).value.data;
    expect(props["for-votes"]).toBeUint(50);
    expect(props["against-votes"]).toBeUint(0);

    // Verify Receipt
    const hasVoted = simnet.callReadOnlyFn(
      "proposal-registry",
      "has-voted",
      [Cl.uint(1), Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(hasVoted.result).toBeBool(true);

    // Attempt Double Vote
    const vote2 = simnet.callPublicFn(
      "proposal-registry",
      "vote-proposal",
      [Cl.uint(1), Cl.bool(false), Cl.uint(50)],
      wallet1
    );
    expect(vote2.result).toBeErr(Cl.uint(4001)); // ERR_ALREADY_VOTED
  });

  it("allows setting executed status", () => {
    // Setup Proposal
    simnet.callPublicFn(
      "proposal-registry",
      "add-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(1),
        Cl.uint(10),
        Cl.uint(100),
      ],
      deployer
    );

    const exec = simnet.callPublicFn(
      "proposal-registry",
      "set-executed",
      [Cl.uint(1)],
      deployer
    );
    expect(exec.result).toBeOk(Cl.bool(true));

    const proposal = simnet.callReadOnlyFn(
      "proposal-registry",
      "get-proposal",
      [Cl.uint(1)],
      deployer
    );
    const props = (proposal.result as any).value.data;
    expect(props.executed).toBeBool(true);
  });
});
