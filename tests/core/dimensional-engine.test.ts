import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initializeSimnet } from "../setup-test-env";

describe("dimensional-engine-optimization", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("ensures open-position fails when the protocol is paused", () => {
    // deployer is global-admin in admin-facade by default
    simnet.callPublicFn(
      "conxian-protocol",
      "set-paused",
      [Cl.bool(true)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      "dimensional-engine",
      "open-position",
      [
        Cl.principal(deployer + ".position-nft"),
        Cl.principal(deployer + ".cxd-token"),
        Cl.uint(100),
        Cl.uint(2),
        Cl.bool(true),
        Cl.none(),
        Cl.none(),
      ],
      deployer
    );
    // ERR_CONTRACT_PAUSED = u5000 in dimensional-engine
    expect(result).toEqual(Cl.error(Cl.uint(5000)));
  });
});
