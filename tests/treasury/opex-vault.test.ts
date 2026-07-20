import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('OPEX Vault', () => {
  let deployer: string;
  let governance: string;
  let approver: string;
  let secondApprover: string;
  let nonCompliantPayee: string;
  let token: ReturnType<typeof Cl.contractPrincipal>;
  let tokenPrincipal: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    governance = accounts.get('wallet_1')!;
    approver = accounts.get('wallet_2')!;
    secondApprover = accounts.get('wallet_3')!;
    nonCompliantPayee = deployer;
    token = Cl.contractPrincipal(deployer, 'mock-token');
    tokenPrincipal = `${deployer}.mock-token`;

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-authorized-principals',
        [Cl.principal(deployer), Cl.principal(governance)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-current-period',
        [Cl.uint(200)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-approver',
        [Cl.principal(approver), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-approver',
        [Cl.principal(secondApprover), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-approval-threshold',
        [Cl.uint(2)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    for (const payee of [governance, approver, secondApprover]) {
      expect(
        simnet.callPublicFn(
          'regulatory-adapter',
          'update-authority',
          [Cl.principal(deployer), Cl.buffer(Buffer.alloc(33, 1))],
          deployer,
        ).result,
      ).toEqual(Cl.ok(Cl.bool(true)));

      expect(
        simnet.callPublicFn(
          'regulatory-adapter',
          'verify-and-update-compliance',
          [
            Cl.principal(payee),
            Cl.stringAscii('USA'),
            Cl.uint(1),
            Cl.buffer(Buffer.alloc(65, 1)),
          ],
          deployer,
        ).result,
      ).toEqual(Cl.ok(Cl.bool(true)));
    }

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
        'opex-vault',
        'deposit',
        [token, Cl.uint(1000)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    for (const categoryBudget of [
      [1, 500],
      [2, 200],
      [3, 100],
    ]) {
      expect(
        simnet.callPublicFn(
          'opex-vault',
          'set-category-budget',
          [Cl.principal(tokenPrincipal), Cl.uint(categoryBudget[0]), Cl.uint(categoryBudget[1])],
          deployer,
        ).result,
      ).toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  it('deposits native token units and executes an N-of-M approved expense once', () => {
    const create = simnet.callPublicFn(
      'opex-vault',
      'create-expense',
      [
        token,
        Cl.uint(1),
        Cl.uint(300),
        Cl.principal(governance),
        Cl.stringAscii('cloud infrastructure'),
      ],
      deployer,
    );
    expect(create.result).toEqual(Cl.ok(Cl.uint(1)));

    const selfApproval = simnet.callPublicFn(
      'opex-vault',
      'approve-expense',
      [Cl.uint(1)],
      deployer,
    );
    expect(selfApproval.result).toEqual(Cl.error(Cl.uint(1011)));

    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(1)], approver).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const duplicateApproval = simnet.callPublicFn(
      'opex-vault',
      'approve-expense',
      [Cl.uint(1)],
      approver,
    );
    expect(duplicateApproval.result).toEqual(Cl.error(Cl.uint(1010)));

    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(1)], secondApprover).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const execute = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(1), token],
      governance,
    );
    expect(execute.result).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callReadOnlyFn('opex-vault', 'get-vault-balance', [Cl.principal(tokenPrincipal)], deployer).result,
    ).toEqual(Cl.uint(700));

    const summary = simnet.callReadOnlyFn(
      'opex-vault',
      'get-summary',
      [Cl.principal(tokenPrincipal)],
      deployer,
    );
    expect(Cl.prettyPrint(summary.result)).toContain('balance: u700');
    expect(Cl.prettyPrint(summary.result)).toContain('reserved: u0');
    expect(Cl.prettyPrint(summary.result)).toContain('available: u700');

    const categoryReport = simnet.callReadOnlyFn(
      'opex-vault',
      'get-category-report',
      [Cl.uint(200), Cl.principal(tokenPrincipal), Cl.uint(1)],
      deployer,
    );
    expect(Cl.prettyPrint(categoryReport.result)).toContain('spent: u300');
    expect(Cl.prettyPrint(categoryReport.result)).toContain('reserved: u0');

    expect(
      simnet.callReadOnlyFn('mock-token', 'get-balance', [Cl.principal(governance)], deployer).result,
    ).toEqual(Cl.ok(Cl.uint(300)));

    const replay = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(1), token],
      governance,
    );
    expect(replay.result).toEqual(Cl.error(Cl.uint(1009)));
  });

  it('cancels pending expenses, rejects non-compliant payees, and protects reservations', () => {
    const canceled = simnet.callPublicFn(
      'opex-vault',
      'create-expense',
      [
        token,
        Cl.uint(2),
        Cl.uint(100),
        Cl.principal(approver),
        Cl.stringAscii('vendor support'),
      ],
      deployer,
    );
    expect(canceled.result).toEqual(Cl.ok(Cl.uint(2)));

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(2)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const canceledExpense = simnet.callReadOnlyFn(
      'opex-vault',
      'get-expense',
      [Cl.uint(2)],
      deployer,
    );
    expect(Cl.prettyPrint(canceledExpense.result)).toContain('status: u2');

    const executeCanceled = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(2), token],
      governance,
    );
    expect(executeCanceled.result).toEqual(Cl.error(Cl.uint(1009)));

    const cancelAgain = simnet.callPublicFn(
      'opex-vault',
      'cancel-expense',
      [Cl.uint(2)],
      governance,
    );
    expect(cancelAgain.result).toEqual(Cl.error(Cl.uint(1009)));

    const nonCompliant = simnet.callPublicFn(
      'opex-vault',
      'create-expense',
      [
        token,
        Cl.uint(2),
        Cl.uint(50),
        Cl.principal(nonCompliantPayee),
        Cl.stringAscii('blocked beneficiary'),
      ],
      deployer,
    );
    expect(nonCompliant.result).toEqual(Cl.error(Cl.uint(1007)));

    const reserved = simnet.callPublicFn(
      'opex-vault',
      'create-expense',
      [
        token,
        Cl.uint(3),
        Cl.uint(90),
        Cl.principal(governance),
        Cl.stringAscii('reserved budget'),
      ],
      deployer,
    );
    expect(reserved.result).toEqual(Cl.ok(Cl.uint(3)));

    const unsafeBudgetReduction = simnet.callPublicFn(
      'opex-vault',
      'set-category-budget',
      [Cl.principal(tokenPrincipal), Cl.uint(3), Cl.uint(80)],
      deployer,
    );
    expect(unsafeBudgetReduction.result).toEqual(Cl.error(Cl.uint(1005)));

    const overBudget = simnet.callPublicFn(
      'opex-vault',
      'create-expense',
      [
        token,
        Cl.uint(3),
        Cl.uint(20),
        Cl.principal(governance),
        Cl.stringAscii('over budget'),
      ],
      deployer,
    );
    expect(overBudget.result).toEqual(Cl.error(Cl.uint(1005)));

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(3)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('rejects duplicate approver setup, invalid deposits, and token mismatches', () => {
    const duplicateApprover = simnet.callPublicFn(
      'opex-vault',
      'set-approver',
      [Cl.principal(approver), Cl.bool(true)],
      governance,
    );
    expect(duplicateApprover.result).toEqual(Cl.error(Cl.uint(1010)));

    const zeroDeposit = simnet.callPublicFn(
      'opex-vault',
      'deposit',
      [token, Cl.uint(0)],
      deployer,
    );
    expect(zeroDeposit.result).toEqual(Cl.error(Cl.uint(1001)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'create-expense',
        [
          token,
          Cl.uint(2),
          Cl.uint(25),
          Cl.principal(governance),
          Cl.stringAscii('token identity check'),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(4)));

    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(4)], approver).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(4)], secondApprover).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const wrongToken = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(4), Cl.contractPrincipal(deployer, 'cxd-token')],
      governance,
    );
    expect(wrongToken.result).toEqual(Cl.error(Cl.uint(1014)));

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(4)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });
});
