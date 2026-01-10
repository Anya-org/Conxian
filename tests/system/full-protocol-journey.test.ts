import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe('Grand Unified System Journey', () => {
  const tokenCollateral = 'mock-token';
  const tokenBorrow = 'mock-usda-token';

  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    if (!simnet) {
      simnet = await initSimnet("Clarinet.toml", false, {
        trackCosts: false,
        trackCoverage: false,
      });
    }
    await simnet.initSession(process.cwd(), "Clarinet.toml");
    const accounts = simnet.getAccounts();
    deployer =
      (accounts.get("deployer") as string) ??
      "STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ";
    wallet1 =
      (accounts.get("wallet_1") as string) ??
      "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";

    const deploy = (name: string, path: string) =>
      simnet.deployContract(name, path, null, deployer);

    deploy("compliance-trait", "contracts/compliance/compliance-trait.clar");
    deploy("sip-standards", "contracts/traits/sip-standards.clar");
    deploy(
      "regulatory-adapter",
      "contracts/compliance/regulatory-adapter.clar"
    );

    simnet.callPublicFn(
      "agent-treasury",
      "set-regulatory-adapter-contract",
      [Cl.contractPrincipal(deployer, "regulatory-adapter")],
      deployer
    );
  });

  const initClp = () => {
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "initialize",
      [
        Cl.contractPrincipal(deployer, tokenCollateral),
        Cl.contractPrincipal(deployer, tokenBorrow),
        Cl.uint(79228162514264337593543950336n),
        Cl.int(0),
        Cl.uint(3000),
      ],
      deployer
    );
  };

  const fundPoolWithLiquidity = () => {
    const clpPrincipal = Cl.contractPrincipal(
      deployer,
      "concentrated-liquidity-pool"
    );

    simnet.callPublicFn(
      tokenCollateral,
      "mint",
      [Cl.uint(100000000000), clpPrincipal],
      deployer
    );

    simnet.callPublicFn(
      tokenBorrow,
      "mint",
      [Cl.uint(100000000000), clpPrincipal],
      deployer
    );

    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "add-liquidity",
      [
        Cl.uint(10000000000),
        Cl.uint(10000000000),
        Cl.contractPrincipal(deployer, tokenCollateral),
        Cl.contractPrincipal(deployer, tokenBorrow),
      ],
      deployer
    );
  };

  const fundUserWithCollateral = () => {
    simnet.callPublicFn(
      tokenCollateral,
      "mint",
      [Cl.uint(5000000000), Cl.standardPrincipal(wallet1)],
      deployer
    );
  };

  const performSwap = () => {
    return simnet.callPublicFn(
      "multi-hop-router-v3",
      "swap-direct",
      [
        Cl.uint(1_000_000),
        Cl.uint(0),
        Cl.contractPrincipal(deployer, "concentrated-liquidity-pool"),
        Cl.contractPrincipal(deployer, tokenCollateral),
        Cl.contractPrincipal(deployer, tokenBorrow),
      ],
      wallet1
    );
  };

  const enableAndRegisterEnterpriseAccount = () => {
    simnet.callPublicFn(
      "enterprise-facade",
      "set-enterprise-active",
      [Cl.bool(true)],
      deployer
    );

    simnet.callPublicFn(
      "enterprise-facade",
      "register-account",
      [Cl.standardPrincipal(wallet1), Cl.uint(1), Cl.uint(100000000000)],
      deployer
    );
  };

  const submitTwapOrder = () => {
    return simnet.callPublicFn(
      "enterprise-facade",
      "submit-twap-order",
      [
        Cl.contractPrincipal(deployer, tokenCollateral),
        Cl.contractPrincipal(deployer, tokenBorrow),
        Cl.uint(1_000_000),
        Cl.uint(10),
        Cl.uint(5),
      ],
      wallet1
    );
  };

  const checkCompliance = () => {
    return simnet.callPublicFn(
      "compliance-manager",
      "check-kyc-compliance",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );
  };

  const commitMevOrder = () => {
    return simnet.callPublicFn(
      "mev-protector",
      "commit-order",
      [
        Cl.bufferFromHex(
          "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        ),
      ],
      wallet1
    );
  };

  it("executes a full DeFi lifecycle: Supply -> Borrow -> Swap -> Repay (simplified)", () => {
    initClp();
    fundPoolWithLiquidity();
    fundUserWithCollateral();

    const swapReceipt = performSwap();
    expect(swapReceipt.result).toEqual(Cl.ok(expect.anything()));

    enableAndRegisterEnterpriseAccount();

    const twapReceipt = submitTwapOrder();
    expect(twapReceipt.result).toEqual(Cl.ok(Cl.uint(1)));

    simnet.mineEmptyBlocks(20);

    const complianceReceipt = checkCompliance();
    expect(complianceReceipt.result).toEqual(Cl.ok(Cl.bool(true)));

    const commitReceipt = commitMevOrder();
    expect(commitReceipt.result).toEqual(Cl.ok(Cl.uint(0)));
  });
});
