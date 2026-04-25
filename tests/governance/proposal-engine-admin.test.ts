import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { simnet } from '../setup-test-env';
import { Cl } from '@stacks/transactions';

let deployer: string;

describe('Proposal Engine - Admin Functions', () => {
  beforeAll(async () => {

  });

  beforeEach(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("allows admin to update proposal registry address", () => {
    const newRegistry = Cl.contractPrincipal(deployer, "new-registry");

    const update = simnet.callPublicFn(
      "proposal-engine",
      "set-proposal-registry",
      [newRegistry],
      deployer
    );

    expect(update.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
