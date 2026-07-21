import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';
import { ec as EC } from 'elliptic';
import crypto from 'crypto';

describe('OPEX Vault', () => {
  let deployer: string;
  let governance: string;
  let approver: string;
  let secondApprover: string;
  let nestedHelper: string;
  let unauthorized: string;
  let nonCompliantPayee: string;
  let token: ReturnType<typeof Cl.contractPrincipal>;
  let tokenPrincipal: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    governance = accounts.get('wallet_1')!;
    approver = accounts.get('wallet_2')!;
    secondApprover = accounts.get('wallet_3')!;
    nestedHelper = `${deployer}.test-c4-helper`;
    // The simnet plan provisions three wallets; use a valid but unconfigured
    // standard principal for negative authorization paths.
    unauthorized = 'ST000000000000000000002AMW42H';
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
        'set-approver',
        [Cl.principal(nestedHelper), Cl.bool(true)],
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

    const ec = new EC('secp256k1');
    const key = ec.genKeyPair();
    const pubkeyHex = key.getPublic(true, 'hex');
    const pubkeyBuff = Buffer.from(pubkeyHex, 'hex');

    expect(
      simnet.callPublicFn(
        'regulatory-adapter',
        'update-authority',
        [Cl.principal(deployer), Cl.buffer(pubkeyBuff)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    for (const payee of [governance, approver, secondApprover]) {
      // 0. Register user principal hash
      const payeeHash = crypto.createHash('sha256').update(payee).digest();
      expect(
        simnet.callPublicFn(
          'regulatory-adapter',
          'register-user-hash',
          [Cl.principal(payee), Cl.buffer(payeeHash)],
          deployer,
        ).result,
      ).toEqual(Cl.ok(Cl.bool(true)));

      // 1. Get SIP-018 hash from the contract
      const hashRes = simnet.callReadOnlyFn(
        'regulatory-adapter',
        'get-sip018-hash',
        [Cl.principal(payee), Cl.stringAscii('USA'), Cl.uint(1)],
        deployer,
      );
      const hashHex = (hashRes.result as any).value.value;
      const hashBytes = Buffer.from(hashHex.startsWith('0x') ? hashHex.slice(2) : hashHex, 'hex');

      // 2. Sign hash with canonical: true
      const signatureObj = key.sign(hashBytes, { canonical: true });
      const r = Buffer.from(signatureObj.r.toArray('be', 32));
      const s = Buffer.from(signatureObj.s.toArray('be', 32));
      const v = Buffer.from([signatureObj.recoveryParam]);
      const sigBuff = Buffer.concat([r, s, v]);

      // 3. Verify and update compliance
      expect(
        simnet.callPublicFn(
          'regulatory-adapter',
          'verify-and-update-compliance',
          [
            Cl.principal(payee),
            Cl.stringAscii('USA'),
            Cl.uint(1),
            Cl.buffer(sigBuff),
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

    // A direct transfer is visible on-chain but remains outside the tracked
    // spendable ledger until an explicit deposit records it.
    expect(
      simnet.callPublicFn(
        'mock-token',
        'mint',
        [Cl.uint(50), Cl.principal(deployer)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'mock-token',
        'transfer',
        [Cl.uint(50), Cl.principal(deployer), Cl.contractPrincipal(deployer, 'opex-vault'), Cl.none()],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const liveSummary = simnet.callPublicFn(
      'opex-vault',
      'get-summary-live',
      [token],
      governance,
    );
    expect(liveSummary.result.type).toBe('ok');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('tracked-balance: u700');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('live-balance: u750');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('available-tracked: u700');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('available-live: u750');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('live-solvent: true');

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

  it('records the immediate nested caller and blocks nested self-approval', () => {
    const create = simnet.callPublicFn(
      'test-c4-helper',
      'submit-opex-expense',
      [
        token,
        Cl.uint(1),
        Cl.uint(40),
        Cl.principal(governance),
        Cl.stringAscii('nested caller regression'),
      ],
      deployer,
    );
    expect(create.result).toEqual(Cl.ok(Cl.uint(2)));

    const storedExpense = simnet.callReadOnlyFn(
      'opex-vault',
      'get-expense',
      [Cl.uint(2)],
      deployer,
    );
    expect(Cl.prettyPrint(storedExpense.result)).toContain(nestedHelper);

    expect(
      simnet.callPublicFn(
        'test-c4-helper',
        'approve-opex-expense',
        [Cl.uint(2)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1011)));

    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(2)], approver).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(2)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
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
    expect(canceled.result).toEqual(Cl.ok(Cl.uint(3)));

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(3)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const canceledExpense = simnet.callReadOnlyFn(
      'opex-vault',
      'get-expense',
      [Cl.uint(3)],
      deployer,
    );
    expect(Cl.prettyPrint(canceledExpense.result)).toContain('status: u2');

    const executeCanceled = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(3), token],
      governance,
    );
    expect(executeCanceled.result).toEqual(Cl.error(Cl.uint(1009)));

    const cancelAgain = simnet.callPublicFn(
      'opex-vault',
      'cancel-expense',
      [Cl.uint(3)],
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
    expect(reserved.result).toEqual(Cl.ok(Cl.uint(4)));

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
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(4)], governance).result,
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
    ).toEqual(Cl.ok(Cl.uint(5)));

    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(5)], approver).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(5)], secondApprover).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const wrongToken = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(5), Cl.contractPrincipal(deployer, 'cxd-token')],
      governance,
    );
    expect(wrongToken.result).toEqual(Cl.error(Cl.uint(1014)));

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(5)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('rejects unauthorized workflow calls and prevents threshold bypasses', () => {
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'create-expense',
        [
          token,
          Cl.uint(3),
          Cl.uint(1),
          Cl.principal(governance),
          Cl.stringAscii('unauthorized request'),
        ],
        unauthorized,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1000)));

    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(999)], unauthorized).result,
    ).toEqual(Cl.error(Cl.uint(1015)));
    expect(
      simnet.callPublicFn('opex-vault', 'execute-expense', [Cl.uint(999), token], unauthorized).result,
    ).toEqual(Cl.error(Cl.uint(1000)));
    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(999)], unauthorized).result,
    ).toEqual(Cl.error(Cl.uint(1000)));

    expect(
      simnet.callPublicFn('opex-vault', 'set-approval-threshold', [Cl.uint(0)], deployer).result,
    ).toEqual(Cl.error(Cl.uint(1012)));
    expect(
      simnet.callPublicFn('opex-vault', 'set-approval-threshold', [Cl.uint(5)], deployer).result,
    ).toEqual(Cl.error(Cl.uint(1012)));
    expect(
      simnet.callPublicFn('opex-vault', 'set-approval-threshold', [Cl.uint(2)], unauthorized).result,
    ).toEqual(Cl.error(Cl.uint(1000)));
  });

  it('prevents cross-category reservations from exceeding tracked funds', () => {
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-category-budget',
        [Cl.principal(tokenPrincipal), Cl.uint(2), Cl.uint(1000)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-category-budget',
        [Cl.principal(tokenPrincipal), Cl.uint(3), Cl.uint(1000)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'create-expense',
        [
          token,
          Cl.uint(2),
          Cl.uint(400),
          Cl.principal(governance),
          Cl.stringAscii('category two reservation'),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(6)));

    const overGlobalReservation = simnet.callPublicFn(
      'opex-vault',
      'create-expense',
      [
        token,
        Cl.uint(3),
        Cl.uint(400),
        Cl.principal(governance),
        Cl.stringAscii('category three reservation'),
      ],
      deployer,
    );
    expect(overGlobalReservation.result).toEqual(Cl.error(Cl.uint(1006)));

    const summary = simnet.callReadOnlyFn(
      'opex-vault',
      'get-summary',
      [Cl.principal(tokenPrincipal)],
      deployer,
    );
    expect(Cl.prettyPrint(summary.result)).toContain('reserved: u400');

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(6)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('fails execution when live token solvency is lower than all tracked reservations', () => {
    const cxdToken = Cl.contractPrincipal(deployer, 'cxd-token');
    const vaultPrincipal = Cl.contractPrincipal(deployer, 'opex-vault');

    expect(
      simnet.callPublicFn(
        'cxd-token',
        'mint',
        [Cl.uint(100), Cl.principal(deployer)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'deposit',
        [cxdToken, Cl.uint(100)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-category-budget',
        [Cl.principal(`${deployer}.cxd-token`), Cl.uint(4), Cl.uint(100)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'create-expense',
        [
          cxdToken,
          Cl.uint(4),
          Cl.uint(40),
          Cl.principal(governance),
          Cl.stringAscii('live solvency check one'),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(7)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'create-expense',
        [
          cxdToken,
          Cl.uint(4),
          Cl.uint(40),
          Cl.principal(governance),
          Cl.stringAscii('live solvency check two'),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(8)));
    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(7)], approver).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(7)], secondApprover).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(8)], approver).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('opex-vault', 'approve-expense', [Cl.uint(8)], secondApprover).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    // Use the token's existing administrative burn hook to model a live
    // balance falling below the vault's tracked reservation.
    expect(
      simnet.callPublicFn(
        'cxd-token',
        'burn',
        [Cl.uint(30), vaultPrincipal],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const insufficientLiveBalance = simnet.callPublicFn(
      'opex-vault',
      'execute-expense',
      [Cl.uint(7), cxdToken],
      governance,
    );
    expect(insufficientLiveBalance.result).toEqual(Cl.error(Cl.uint(1006)));

    const liveSummary = simnet.callPublicFn(
      'opex-vault',
      'get-summary-live',
      [cxdToken],
      governance,
    );
    expect(Cl.prettyPrint(liveSummary.result)).toContain('tracked-balance: u100');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('live-balance: u70');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('reserved: u80');
    expect(Cl.prettyPrint(liveSummary.result)).toContain('live-solvent: false');

    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(7)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('opex-vault', 'cancel-expense', [Cl.uint(8)], governance).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('prevents admin approver collisions and preserves distinct threshold accounting', () => {
    expect(
      simnet.callPublicFn('opex-vault', 'set-approval-threshold', [Cl.uint(4)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-admin',
        [Cl.principal(approver)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1016)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-authorized-principals',
        [Cl.principal(secondApprover), Cl.principal(governance)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1016)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-approver',
        [Cl.principal(deployer), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1010)));

    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-approver',
        [Cl.principal(secondApprover), Cl.bool(false)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1012)));
    expect(
      simnet.callPublicFn('opex-vault', 'set-approval-threshold', [Cl.uint(1)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'opex-vault',
        'set-approver',
        [Cl.principal(secondApprover), Cl.bool(false)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callReadOnlyFn('opex-vault', 'is-approver-address', [Cl.principal(secondApprover)], deployer).result,
    ).toEqual(Cl.bool(false));
    expect(
      simnet.callReadOnlyFn('opex-vault', 'get-approval-threshold', [], deployer).result,
    ).toEqual(Cl.uint(1));
  });
});
