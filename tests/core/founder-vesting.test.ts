
import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeAll } from "vitest";
import { Simnet, initSimnet } from "@stacks/clarinet-sdk";

const ONE_TOKEN = 1000000;

describe("founder-vesting contract tests", () => {
  let simnet: Simnet;
  let accounts: Map<string, string>;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let wallet4: string;

  beforeAll(async () => {
    simnet = await initSimnet("clarinet.founder-vesting.toml");
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
    wallet3 = accounts.get("wallet_3")!;
    wallet4 = accounts.get("wallet_4")!;
  });

  it("ensures that the contract is deployed", () => {
    const deployed = simnet.getContractsInterfaces();
    expect(deployed.has("founder-vesting")).toBe(true);
  });

  it("allows the owner to add a vesting schedule and retrieves it", () => {
    const startBlock = 10;
    const endBlock = 110;
    const amount = 1000 * ONE_TOKEN;

    const addScheduleResult = simnet.callPublicFn(
      "founder-vesting",
      "add-vesting-schedule",
      [
        Cl.principal(wallet1),
        Cl.uint(amount),
        Cl.uint(startBlock),
        Cl.uint(endBlock),
      ],
      deployer
    );
    expect(addScheduleResult.result).toBeOk(Cl.bool(true));

    const schedule = simnet.callReadOnlyFn(
      "founder-vesting",
      "get-vesting-schedule",
      [Cl.principal(wallet1)],
      deployer
    );

    expect(schedule.result).toStrictEqual(Cl.some(Cl.tuple({
      "total-amount": Cl.uint(amount),
      "start-block": Cl.uint(startBlock),
      "end-block": Cl.uint(endBlock),
      "claimed-amount": Cl.uint(0)
    })));
  });

  it("prevents non-owner from adding a vesting schedule", () => {
    const addScheduleResult = simnet.callPublicFn(
      "founder-vesting",
      "add-vesting-schedule",
      [Cl.principal(wallet2), Cl.uint(1000), Cl.uint(1), Cl.uint(100)],
      wallet1 // non-owner
    );
    expect(addScheduleResult.result).toBeErr(Cl.uint(401)); // ERR_UNAUTHORIZED
  });

  it("shows claimable amount is 0 before vesting starts", () => {
    const startBlock = simnet.blockHeight + 10;
    const endBlock = startBlock + 100;
    const amount = 1000 * ONE_TOKEN;

    simnet.callPublicFn(
      "founder-vesting",
      "add-vesting-schedule",
      [
        Cl.principal(wallet2),
        Cl.uint(amount),
        Cl.uint(startBlock),
        Cl.uint(endBlock),
      ],
      deployer
    );

    const claimable = simnet.callReadOnlyFn(
      "founder-vesting",
      "get-claimable-amount",
      [Cl.principal(wallet2)],
      wallet2
    );
    expect(claimable.result).toBeOk(Cl.uint(0));
  });

  it("allows beneficiary to claim vested tokens and updates state correctly", () => {
    const beneficiary = wallet3;
    const totalAmount = 1000 * ONE_TOKEN;
    const startBlock = simnet.blockHeight + 1;
    const vestingDuration = 100;
    const endBlock = startBlock + vestingDuration;

    simnet.callPublicFn(
      "founder-vesting",
      "add-vesting-schedule",
      [
        Cl.principal(beneficiary),
        Cl.uint(totalAmount),
        Cl.uint(startBlock),
        Cl.uint(endBlock),
      ],
      deployer
    );

    const founderVestingContract = `${deployer}.founder-vesting`;
    simnet.callPublicFn(
      "mock-token",
      "transfer",
      [
        Cl.uint(totalAmount),
        Cl.principal(deployer),
        Cl.principal(founderVestingContract),
        Cl.none(),
      ],
      deployer
    );

    const halfwayBlock = startBlock + vestingDuration / 2;
    simnet.mineEmptyBlocks(halfwayBlock - simnet.blockHeight);

    const expectedClaimable = Math.floor(totalAmount / 2);
    const claimResult = simnet.callPublicFn(
      "founder-vesting",
      "claim-vested-tokens",
      [Cl.contractPrincipal(deployer, "mock-token")],
      beneficiary
    );
    expect(claimResult.result).toBeOk(Cl.uint(expectedClaimable));

    const balanceResult = simnet.callReadOnlyFn("mock-token", "get-balance", [Cl.principal(beneficiary)], beneficiary);
    expect(balanceResult.result).toStrictEqual(Cl.ok(Cl.uint(expectedClaimable)));

    const schedule = simnet.callReadOnlyFn(
      "founder-vesting",
      "get-vesting-schedule",
      [Cl.principal(beneficiary)],
      deployer
    );

    expect(schedule.result).toStrictEqual(Cl.some(Cl.tuple({
      "total-amount": Cl.uint(totalAmount),
      "start-block": Cl.uint(startBlock),
      "end-block": Cl.uint(endBlock),
      "claimed-amount": Cl.uint(expectedClaimable)
    })));
  });

  it("fails to claim when nothing is claimable yet", () => {
    const beneficiary = wallet4;
    const startBlock = simnet.blockHeight + 5;
    const endBlock = startBlock + 100;

    simnet.callPublicFn(
        "founder-vesting",
        "add-vesting-schedule",
        [Cl.principal(beneficiary), Cl.uint(1000), Cl.uint(startBlock), Cl.uint(endBlock)],
        deployer
      );

    const claimResult = simnet.callPublicFn(
      "founder-vesting",
      "claim-vested-tokens",
      [Cl.contractPrincipal(deployer, "mock-token")],
      beneficiary
    );
    expect(claimResult.result).toBeErr(Cl.uint(405)); // ERR_NOTHING_TO_CLAIM
  });
});
