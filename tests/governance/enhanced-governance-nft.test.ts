import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

const CONTRACT_NAME = "enhanced-governance-nft";

describe("Enhanced Governance NFT (Seats)", () => {
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

  it("allows admin to mint a seat", () => {
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      "mint-seat",
      [
        Cl.principal(wallet1),
        Cl.uint(1), // council-id
        Cl.uint(100), // voting-power
        Cl.stringAscii("STAFF")
      ],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.uint(1)));
  });
});
