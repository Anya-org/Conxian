import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CXLP = 'cxlp-token';
const COORDINATOR = 'token-system-coordinator';

function cxlpPrincipal(deployer: string) {
  return Cl.contractPrincipal(deployer, CXLP);
}

function coordinatorPrincipal(deployer: string) {
  return Cl.contractPrincipal(deployer, COORDINATOR);
}

function balanceOf(owner: string, deployer: string) {
  return simnet.callReadOnlyFn(CXLP, 'get-balance', [Cl.principal(owner)], deployer).result;
}

function totalSupply(deployer: string) {
  return simnet.callReadOnlyFn(CXLP, 'get-total-supply', [], deployer).result;
}

describe('CXLP mint and burn authorization', () => {
  it('keeps admin, minter, and burner roles separate and admin-managed', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const minter = accounts.get('wallet_1')!;
    const burner = accounts.get('wallet_2')!;
    const nonAdmin = accounts.get('wallet_3')!;

    expect(simnet.callReadOnlyFn(CXLP, 'get-admin', [], deployer).result).toEqual(
      Cl.ok(Cl.principal(deployer)),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-admin', [Cl.principal(deployer)], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-admin', [Cl.principal(nonAdmin)], deployer).result).toEqual(
      Cl.bool(false),
    );

    expect(
      simnet.callPublicFn(CXLP, 'add-minter', [Cl.principal(minter)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(burner)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(minter)], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(minter)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(burner)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(burner)], deployer).result).toEqual(
      Cl.bool(true),
    );

    expect(
      simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(nonAdmin)], minter).result,
    ).toEqual(Cl.error(Cl.uint(1000)));
    expect(
      simnet.callPublicFn(CXLP, 'remove-minter', [Cl.principal(minter)], minter).result,
    ).toEqual(Cl.error(Cl.uint(1000)));

    expect(
      simnet.callPublicFn(CXLP, 'remove-minter', [Cl.principal(minter)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(CXLP, 'remove-burner', [Cl.principal(burner)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(minter)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(burner)], deployer).result).toEqual(
      Cl.bool(false),
    );
  });

  it('mints real SIP-010 supply only for an authorized immediate caller', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const minter = accounts.get('wallet_1')!;
    const unauthorized = accounts.get('wallet_2')!;

    expect(
      simnet.callPublicFn(CXLP, 'add-minter', [Cl.principal(minter)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const beforeSupply = totalSupply(deployer);
    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(500), Cl.principal(minter)], minter).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(balanceOf(minter, deployer)).toEqual(Cl.ok(Cl.uint(500)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(500)));
    expect(beforeSupply).toEqual(Cl.ok(Cl.uint(0)));

    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(1), Cl.principal(unauthorized)], unauthorized).result,
    ).toEqual(Cl.error(Cl.uint(1000)));
    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(0), Cl.principal(minter)], minter).result,
    ).toEqual(Cl.error(Cl.uint(1001)));

    expect(
      simnet.callPublicFn(CXLP, 'remove-minter', [Cl.principal(minter)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(1), Cl.principal(minter)], minter).result,
    ).toEqual(Cl.error(Cl.uint(1000)));
  });

  it('burns only through an authorized burner and preserves owner context', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const owner = accounts.get('wallet_1')!;
    const userA = accounts.get('wallet_2')!;
    const coordinator = coordinatorPrincipal(deployer);

    expect(
      simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(owner)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(100), Cl.principal(owner)], owner).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(balanceOf(owner, deployer)).toEqual(Cl.ok(Cl.uint(400)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(400)));

    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(1), Cl.principal(userA)], userA).result,
    ).toEqual(Cl.error(Cl.uint(1000)));
    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(0), Cl.principal(owner)], owner).result,
    ).toEqual(Cl.error(Cl.uint(1001)));

    const insufficient = simnet.callPublicFn(
      CXLP,
      'burn',
      [Cl.uint(401), Cl.principal(owner)],
      owner,
    );
    expect(Cl.prettyPrint(insufficient.result)).toMatch(/^\(err /);

    expect(
      simnet.callPublicFn(CXLP, 'remove-burner', [Cl.principal(owner)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(1), Cl.principal(owner)], owner).result,
    ).toEqual(Cl.error(Cl.uint(1000)));

    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(300), Cl.principal(owner)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(CXLP, 'add-burner', [coordinator], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const crossOwnerBurn = simnet.callPublicFn(
      COORDINATOR,
      'burn-cxd',
      [cxlpPrincipal(deployer), Cl.uint(50), Cl.principal(owner)],
      userA,
    );
    expect(crossOwnerBurn.result).toEqual(Cl.error(Cl.uint(1002)));
    expect(balanceOf(owner, deployer)).toEqual(Cl.ok(Cl.uint(700)));

    const ownerBurn = simnet.callPublicFn(
      COORDINATOR,
      'burn-cxd',
      [cxlpPrincipal(deployer), Cl.uint(50), Cl.principal(owner)],
      owner,
    );
    expect(ownerBurn.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(balanceOf(owner, deployer)).toEqual(Cl.ok(Cl.uint(650)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(650)));

    expect(
      simnet.callPublicFn(CXLP, 'remove-burner', [coordinator], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('does not change CXLP supply when a concentrated pool is created', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const beforeSupply = totalSupply(deployer);

    const createPool = simnet.callPublicFn(
      'concentrated-liquidity-pool',
      'create-pool',
      [
        Cl.principal(`${deployer}.cxd-token`),
        Cl.principal(`${deployer}.cxvg-token`),
        Cl.uint(3000),
        Cl.uint(1000000000000),
        Cl.int(0),
      ],
      deployer,
    );
    expect(Cl.prettyPrint(createPool.result)).toMatch(/^\(ok u\d+\)$/);

    expect(totalSupply(deployer)).toEqual(beforeSupply);
  });
});
