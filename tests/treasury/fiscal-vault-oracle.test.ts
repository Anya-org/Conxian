import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('Fiscal Vault Oracle', () => {
  let deployer: string;
  let governance: string;
  let paymentForge: string;
  let unauthorized: string;
  let beneficiary: string;
  let token: ReturnType<typeof Cl.contractPrincipal>;
  let tokenPrincipal: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    governance = accounts.get('wallet_1')!;
    paymentForge = accounts.get('wallet_2')!;
    unauthorized = accounts.get('wallet_3')!;
    beneficiary = governance;
    token = Cl.contractPrincipal(deployer, 'mock-token');
    tokenPrincipal = `${deployer}.mock-token`;

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-authorized-principals',
        [Cl.principal(deployer), Cl.principal(governance), Cl.principal(paymentForge)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-current-period',
        [Cl.uint(100)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'mock-token',
        'mint',
        [Cl.uint(1000), Cl.principal(deployer)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'deposit',
        [token, Cl.uint(1000)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('registers SBCs, enforces one active allocation, and releases through payment-forge', () => {
    const sbc = 'SBC-FISCAL-001';

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'register-sbc',
        [Cl.stringAscii(sbc), Cl.principal(beneficiary)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-category-cap',
        [Cl.principal(tokenPrincipal), Cl.uint(1), Cl.uint(1000)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const allocation = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'create-allocation',
      [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal), Cl.uint(1), Cl.uint(500)],
      deployer,
    );
    expect(allocation.result).toEqual(Cl.ok(Cl.uint(1)));

    const duplicate = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'create-allocation',
      [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal), Cl.uint(1), Cl.uint(100)],
      deployer,
    );
    expect(duplicate.result).toEqual(Cl.error(Cl.uint(407)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'approve-allocation',
        [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal)],
        governance,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const firstRelease = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'release-funds-to-sbc',
      [Cl.stringAscii(sbc), Cl.uint(200), token],
      paymentForge,
    );
    expect(firstRelease.result).toEqual(Cl.ok(Cl.bool(true)));

    const afterPartialRelease = simnet.callReadOnlyFn(
      'fiscal-vault-oracle',
      'get-allocation',
      [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal)],
      deployer,
    );
    expect(Cl.prettyPrint(afterPartialRelease.result)).toContain('released: u200');
    expect(Cl.prettyPrint(afterPartialRelease.result)).toContain('active: true');

    const report = simnet.callReadOnlyFn(
      'fiscal-vault-oracle',
      'get-category-report',
      [Cl.uint(100), Cl.principal(tokenPrincipal), Cl.uint(1)],
      deployer,
    );
    expect(Cl.prettyPrint(report.result)).toContain('spent: u200');
    expect(Cl.prettyPrint(report.result)).toContain('committed: u300');

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'release-funds-to-sbc',
        [Cl.stringAscii(sbc), Cl.uint(300), token],
        paymentForge,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const afterFullRelease = simnet.callReadOnlyFn(
      'fiscal-vault-oracle',
      'get-allocation',
      [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal)],
      deployer,
    );
    expect(Cl.prettyPrint(afterFullRelease.result)).toContain('active: false');
    expect(Cl.prettyPrint(afterFullRelease.result)).toContain('released: u500');

    const beneficiaryBalance = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(beneficiary)],
      deployer,
    );
    expect(beneficiaryBalance.result).toEqual(Cl.ok(Cl.uint(500)));
  });

  it('rejects unauthorized mutations, invalid categories, unsafe caps, and insufficient reserves', () => {
    const sbc = 'SBC-FISCAL-002';

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'register-sbc',
        [Cl.stringAscii(sbc), Cl.principal(beneficiary)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-category-cap',
        [Cl.principal(tokenPrincipal), Cl.uint(2), Cl.uint(200)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const unauthorizedCap = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'set-category-cap',
      [Cl.principal(tokenPrincipal), Cl.uint(2), Cl.uint(300)],
      unauthorized,
    );
    expect(unauthorizedCap.result).toEqual(Cl.error(Cl.uint(400)));

    const invalidAllocation = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'create-allocation',
      [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal), Cl.uint(9), Cl.uint(10)],
      deployer,
    );
    expect(invalidAllocation.result).toEqual(Cl.error(Cl.uint(402)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'create-allocation',
        [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal), Cl.uint(2), Cl.uint(200)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(2)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'approve-allocation',
        [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal)],
        governance,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-required-reserve',
        [Cl.principal(tokenPrincipal), Cl.uint(400)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const reserveBlocked = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'release-funds-to-sbc',
      [Cl.stringAscii(sbc), Cl.uint(200), token],
      paymentForge,
    );
    expect(reserveBlocked.result).toEqual(Cl.error(Cl.uint(414)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-required-reserve',
        [Cl.principal(tokenPrincipal), Cl.uint(0)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'release-funds-to-sbc',
        [Cl.stringAscii(sbc), Cl.uint(200), token],
        paymentForge,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const unsafeReduction = simnet.callPublicFn(
      'fiscal-vault-oracle',
      'set-category-cap',
      [Cl.principal(tokenPrincipal), Cl.uint(1), Cl.uint(100)],
      deployer,
    );
    expect(unsafeReduction.result).toEqual(Cl.error(Cl.uint(417)));

    const health = simnet.callReadOnlyFn(
      'fiscal-vault-oracle',
      'get-treasury-health',
      [Cl.principal(tokenPrincipal)],
      deployer,
    );
    expect(Cl.prettyPrint(health.result)).toContain('balance: u300');
    expect(Cl.prettyPrint(health.result)).toContain('solvent: true');
  });

  it('preserves the payment-forge contract compatibility call', () => {
    const sbc = 'SBC-FISCAL-FORGE';
    const paymentForgeContract = Cl.contractPrincipal(deployer, 'payment-forge');

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'register-sbc',
        [Cl.stringAscii(sbc), Cl.principal(beneficiary)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-category-cap',
        [Cl.principal(tokenPrincipal), Cl.uint(3), Cl.uint(50)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'create-allocation',
        [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal), Cl.uint(3), Cl.uint(50)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(3)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'approve-allocation',
        [Cl.stringAscii(sbc), Cl.principal(tokenPrincipal)],
        governance,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-payment-forge',
        [paymentForgeContract],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'payment-forge',
        'settle-sbc-obligation',
        [Cl.stringAscii(sbc), Cl.uint(50), token],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'fiscal-vault-oracle',
        'set-payment-forge',
        [Cl.principal(paymentForge)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });
});
