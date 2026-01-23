import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Conxian Operations Engine", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  // Helper to mint the Ops Council Seat (u5) to the Operations Engine Contract
  // The contract needs to hold the seat to vote.
  const mintOpsSeat = () => {
    // Operations Engine Principal
    const opsEngine = Cl.contractPrincipal(
      deployer,
      "conxian-operations-engine"
    );

    // Mint Seat u5 (Ops) to the contract
    const mint = simnet.callPublicFn(
      "enhanced-governance-nft",
      "mint-seat",
      [opsEngine, Cl.uint(5), Cl.uint(100), Cl.stringAscii("autonomous-agent")],
      deployer
    );
    expect(mint.result).toBeOk(Cl.uint(1));
  };

  it("allows the operator controller to execute operational adjustments", () => {
    const params = Cl.bufferFromHex("00"); // Dummy params

    const exec = simnet.callPublicFn(
      "conxian-operations-engine",
      "execute-operational-adjustment",
      [params],
      deployer // Default controller is deployer
    );
    expect(exec.result).toBeOk(Cl.bool(true));
  });

  it("prevents unauthorized users from executing adjustments", () => {
    const params = Cl.bufferFromHex("00");
    const exec = simnet.callPublicFn(
      "conxian-operations-engine",
      "execute-operational-adjustment",
      [params],
      wallet1
    );
    expect(exec.result).toBeErr(Cl.uint(6000)); // ERR_UNAUTHORIZED
  });

  it("allows the contract to cast a council vote if it holds a seat", () => {
    // 1. Submit a proposal (requires a seat, so mint one for deployer first)
    simnet.callPublicFn(
      "enhanced-governance-nft",
      "mint-seat",
      [
        Cl.standardPrincipal(deployer),
        Cl.uint(5),
        Cl.uint(100),
        Cl.stringAscii("human"),
      ],
      deployer
    );

    simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(5),
        Cl.uint(10),
        Cl.uint(100),
      ],
      deployer
    );

    // 2. Mint Seat for Operations Engine
    mintOpsSeat();

    // 3. Fast forward
    for (let i = 0; i < 10; i++) simnet.mineEmptyBlock();

    // 4. Controller triggers the vote
    const vote = simnet.callPublicFn(
      "conxian-operations-engine",
      "cast-council-vote",
      [Cl.uint(1), Cl.bool(true)],
      deployer
    );
    expect(vote.result).toBeOk(Cl.bool(true));

    // Verify vote counted
    const proposal = simnet.callReadOnlyFn(
      "proposal-registry",
      "get-proposal",
      [Cl.uint(1)],
      deployer
    );
    const props = (proposal.result as any).value.data;
    // Deployer hasn't voted, only Engine. Engine power = 100.
    expect(props["for-votes"]).toBeUint(100);
  });

  it("fails to vote if contract has no seat", () => {
    // 1. Submit a proposal
    simnet.callPublicFn(
      "enhanced-governance-nft",
      "mint-seat",
      [
        Cl.standardPrincipal(deployer),
        Cl.uint(5),
        Cl.uint(100),
        Cl.stringAscii("human"),
      ],
      deployer
    );
    simnet.callPublicFn(
      "proposal-engine",
      "submit-proposal",
      [
        Cl.contractPrincipal(deployer, "mock-proposal"),
        Cl.uint(5),
        Cl.uint(10),
        Cl.uint(100),
      ],
      deployer
    );

    // 2. Fast forward
    for (let i = 0; i < 10; i++) simnet.mineEmptyBlock();

    // 3. Try to vote (No seat minted for engine)
    const vote = simnet.callPublicFn(
      "conxian-operations-engine",
      "cast-council-vote",
      [Cl.uint(1), Cl.bool(true)],
      deployer
    );
    expect(vote.result).toBeErr(Cl.uint(6000));
  });

  it("allows updating the controller", () => {
    const update = simnet.callPublicFn(
      "conxian-operations-engine",
      "set-operator-controller",
      [Cl.standardPrincipal(wallet1)],
      deployer
    );
    expect(update.result).toBeOk(Cl.bool(true));
  });
});
