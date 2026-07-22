import { beforeEach, describe, expect, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl, ClarityVersion } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import crypto from 'node:crypto';

const VAULT = 'sbtc-vault';
const TOKEN = 'mock-token';
const WRONG_TOKEN = 'cxd-token';
const REGULATORY = 'regulatory-adapter';

const ERR_UNAUTHORIZED = 5100;
const ERR_TOKEN_MISMATCH = 5102;
const ERR_ZERO_AMOUNT = 5103;
const ERR_NON_COMPLIANT = 5104;
const ERR_PAUSED = 5106;
const ERR_CAP_EXCEEDED = 5108;
const ERR_INSUFFICIENT_ASSETS = 5111;
const ERR_INSUFFICIENT_SHARES = 5112;
const ERR_STRATEGY_DISABLED = 5117;
const ERR_INSOLVENT = 5118;
const ERR_DEPOSIT_RECONCILIATION = 5119;
const ERR_TOKEN_ALREADY_CONFIGURED = 5120;

// This fixture is deployed ad hoc by the Clarinet SDK from test source. It is
// intentionally not listed in Clarinet.toml or any production deployment
// manifest. The two toggles let tests create the strongest feasible negative
// custody cases without adding production-only state mutation.
const ADVERSARIAL_TOKEN_SOURCE = `
(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token adversarial-token)
(define-data-var admin principal tx-sender)
(define-data-var under-credit bool false)
(define-data-var balance-offset uint u0)

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-public (set-under-credit (enabled bool))
  (begin
    (asserts! (is-admin) (err u1))
    (var-set under-credit enabled)
    (ok true)
  )
)

(define-public (set-balance-offset (offset uint))
  (begin
    (asserts! (is-admin) (err u1))
    (var-set balance-offset offset)
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin) (err u1))
    (ft-mint? adversarial-token amount recipient)
  )
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) (err u2))
    (ft-transfer?
      adversarial-token
      (if (and (var-get under-credit) (> amount u0)) (- amount u1) amount)
      from
      to
    )
  )
)

(define-read-only (get-name) (ok "Adversarial Token"))
(define-read-only (get-symbol) (ok "ADVR"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (user principal))
  (let (
    (actual (ft-get-balance adversarial-token user))
    (offset (var-get balance-offset))
  )
    (ok (if (> actual offset) (- actual offset) u0))
  )
)
(define-read-only (get-total-supply) (ok (ft-get-supply adversarial-token)))
(define-read-only (get-token-uri) (ok none))
`;

type SimnetLike = any;

describe('sBTC vault Phase 2A custody and share accounting', () => {
  let simnet: SimnetLike;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;

  const canonicalToken = () => Cl.contractPrincipal(deployer, TOKEN);
  const wrongToken = () => Cl.contractPrincipal(deployer, WRONG_TOKEN);
  const vaultPrincipal = () => `${deployer}.${VAULT}`;

  const expectError = (result: unknown, code: number) => {
    expect(result).toEqual(Cl.error(Cl.uint(code)));
  };

  const readUint = (contract: string, functionName: string, args: any[], sender = deployer): bigint => {
    const result = simnet.callReadOnlyFn(contract, functionName, args, sender).result as any;
    expect(result.type).toBe('uint');
    return BigInt(result.value);
  };

  const readOkUint = (contract: string, functionName: string, args: any[], sender = deployer): bigint => {
    const result = simnet.callReadOnlyFn(contract, functionName, args, sender).result as any;
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('uint');
    return BigInt(result.value.value);
  };

  const mockBalance = (user: string) =>
    readOkUint(TOKEN, 'get-balance', [Cl.principal(user)]);

  const accounting = (user: string) =>
    Cl.prettyPrint(
      simnet.callReadOnlyFn(VAULT, 'get-accounting', [Cl.principal(user)], deployer).result,
    );

  const mintMock = (amount: number, recipient: string) => {
    expect(
      simnet.callPublicFn(
        TOKEN,
        'mint',
        [Cl.uint(amount), Cl.principal(recipient)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  };

  const makeCompliant = (user: string, key: EC.KeyPair) => {
    const userHash = crypto.createHash('sha256').update(user).digest();
    expect(
      simnet.callPublicFn(
        REGULATORY,
        'register-user-hash',
        [Cl.principal(user), Cl.buffer(userHash)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const hashResult = simnet.callReadOnlyFn(
      REGULATORY,
      'get-sip018-hash',
      [Cl.principal(user), Cl.stringAscii('USA'), Cl.uint(1)],
      deployer,
    ).result as any;
    const hashHex = hashResult.value.value as string;
    const hashBytes = Buffer.from(hashHex.startsWith('0x') ? hashHex.slice(2) : hashHex, 'hex');
    const signature = key.sign(hashBytes, { canonical: true });
    const signatureBuffer = Buffer.concat([
      Buffer.from(signature.r.toArray('be', 32)),
      Buffer.from(signature.s.toArray('be', 32)),
      Buffer.from([signature.recoveryParam ?? 0]),
    ]);

    expect(
      simnet.callPublicFn(
        REGULATORY,
        'verify-and-update-compliance',
        [
          Cl.principal(user),
          Cl.stringAscii('USA'),
          Cl.uint(1),
          Cl.buffer(signatureBuffer),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  };

  const configureVault = () => {
    const tokenConfiguration = simnet.callPublicFn(
      VAULT,
      'set-approved-token',
      [canonicalToken()],
      deployer,
    );
    expect(tokenConfiguration.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(tokenConfiguration.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(JSON.stringify(tokenConfiguration.events)).toContain('sbtc-vault-token-configured');
    expect(
      simnet.callPublicFn(VAULT, 'set-deposit-cap', [Cl.uint(150)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  };

  beforeEach(async () => {
    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    wallet2 = simnet.getAccounts().get('wallet_2')!;
    wallet3 = simnet.getAccounts().get('wallet_3')!;

    const key = new EC('secp256k1').genKeyPair();
    expect(
      simnet.callPublicFn(
        REGULATORY,
        'update-authority',
        [Cl.principal(deployer), Cl.buffer(Buffer.from(key.getPublic(true, 'hex'), 'hex'))],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    makeCompliant(wallet1, key);
    makeCompliant(wallet2, key);

    mintMock(1_000, wallet1);
    mintMock(1_000, wallet2);
    configureVault();
  });

  it('requires admin authorization for token, cap, and pause configuration', () => {
    expectError(
      simnet.callPublicFn(VAULT, 'set-approved-token', [wrongToken()], wallet3).result,
      ERR_UNAUTHORIZED,
    );
    expectError(
      simnet.callPublicFn(VAULT, 'set-deposit-cap', [Cl.uint(200)], wallet3).result,
      ERR_UNAUTHORIZED,
    );
    expectError(
      simnet.callPublicFn(VAULT, 'set-paused', [Cl.bool(true)], wallet3).result,
      ERR_UNAUTHORIZED,
    );

    expect(
      simnet.callReadOnlyFn(VAULT, 'get-admin', [], deployer).result,
    ).toEqual(Cl.ok(Cl.principal(deployer)));
    expect(
      simnet.callReadOnlyFn(VAULT, 'get-approved-token', [], deployer).result,
    ).toEqual(Cl.some(Cl.contractPrincipal(deployer, TOKEN)));
    expect(accounting(wallet1)).toContain(`total-assets: u0`);
    expect(accounting(wallet1)).toContain(`total-shares: u0`);
  });

  it('rejects noncanonical tokens, zero amounts, and noncompliant depositors', () => {
    expectError(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(1), wrongToken()], wallet1).result,
      ERR_TOKEN_MISMATCH,
    );
    expectError(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(0), canonicalToken()], wallet1).result,
      ERR_ZERO_AMOUNT,
    );
    expectError(
      simnet.callPublicFn(VAULT, 'withdraw', [Cl.uint(0), canonicalToken()], wallet1).result,
      ERR_ZERO_AMOUNT,
    );
    expectError(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(1), canonicalToken()], wallet3).result,
      ERR_NON_COMPLIANT,
    );
  });

  it('mints first and subsequent deposits pro rata and enforces the deposit cap', () => {
    const firstDeposit = simnet.callPublicFn(
      VAULT,
      'deposit',
      [Cl.uint(100), canonicalToken()],
      wallet1,
    );
    const secondDeposit = simnet.callPublicFn(
      VAULT,
      'deposit',
      [Cl.uint(50), canonicalToken()],
      wallet2,
    );
    expect(firstDeposit.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(secondDeposit.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(firstDeposit.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(secondDeposit.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(JSON.stringify(firstDeposit.events)).toContain('sbtc-vault-deposit');
    expect(JSON.stringify(secondDeposit.events)).toContain('sbtc-vault-deposit');

    expect(readUint(VAULT, 'get-total-assets', [])).toBe(150n);
    expect(readUint(VAULT, 'get-total-shares', [])).toBe(150n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet1)])).toBe(100n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet2)])).toBe(50n);
    expect(readOkUint(VAULT, 'get-user-asset-value', [Cl.principal(wallet1)])).toBe(100n);
    expect(readOkUint(VAULT, 'get-user-asset-value', [Cl.principal(wallet2)])).toBe(50n);
    expect(mockBalance(vaultPrincipal())).toBe(150n);
    expect(accounting(wallet1)).toContain('total-assets: u150');
    expect(accounting(wallet1)).toContain('total-shares: u150');
    expect(accounting(wallet1)).toContain('user-shares: u100');

    expectError(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(1), canonicalToken()], wallet1).result,
      ERR_CAP_EXCEEDED,
    );
  });

  it('blocks new deposits while paused but preserves compliant withdrawals', () => {
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(100), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(50), canonicalToken()], wallet2).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(VAULT, 'set-paused', [Cl.bool(true)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expectError(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(1), canonicalToken()], wallet1).result,
      ERR_PAUSED,
    );
    const withdrawal = simnet.callPublicFn(
      VAULT,
      'withdraw',
      [Cl.uint(10), canonicalToken()],
      wallet1,
    );
    expect(withdrawal.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(withdrawal.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(JSON.stringify(withdrawal.events)).toContain('sbtc-vault-withdraw');

    expect(readUint(VAULT, 'get-total-assets', [])).toBe(140n);
    expect(readUint(VAULT, 'get-total-shares', [])).toBe(140n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet1)])).toBe(90n);
    expect(mockBalance(wallet1)).toBe(910n);
  });

  it('rejects insufficient assets or shares and completes a successful withdrawal', () => {
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(100), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(50), canonicalToken()], wallet2).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expectError(
      simnet.callPublicFn(VAULT, 'withdraw', [Cl.uint(200), canonicalToken()], wallet1).result,
      ERR_INSUFFICIENT_ASSETS,
    );
    expectError(
      simnet.callPublicFn(VAULT, 'withdraw', [Cl.uint(60), canonicalToken()], wallet2).result,
      ERR_INSUFFICIENT_SHARES,
    );

    const withdrawal = simnet.callPublicFn(
      VAULT,
      'withdraw',
      [Cl.uint(25), canonicalToken()],
      wallet1,
    );
    expect(withdrawal.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(withdrawal.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(JSON.stringify(withdrawal.events)).toContain('sbtc-vault-withdraw');
    expect(readUint(VAULT, 'get-total-assets', [])).toBe(125n);
    expect(readUint(VAULT, 'get-total-shares', [])).toBe(125n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet1)])).toBe(75n);
    expect(mockBalance(wallet1)).toBe(925n);
    expect(mockBalance(vaultPrincipal())).toBe(125n);
  });

  it('configures the canonical token only once, even before deposits', () => {
    expectError(
      simnet.callPublicFn(VAULT, 'set-approved-token', [wrongToken()], deployer).result,
      ERR_TOKEN_ALREADY_CONFIGURED,
    );
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(1), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expectError(
      simnet.callPublicFn(VAULT, 'set-approved-token', [wrongToken()], deployer).result,
      ERR_TOKEN_ALREADY_CONFIGURED,
    );
  });

  it('transfers admin authority and locks out the previous admin', () => {
    const transfer = simnet.callPublicFn(
      VAULT,
      'set-admin',
      [Cl.principal(wallet2)],
      deployer,
    );
    expect(transfer.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(transfer.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(JSON.stringify(transfer.events)).toContain('sbtc-vault-admin-updated');
    expect(simnet.callReadOnlyFn(VAULT, 'get-admin', [], deployer).result).toEqual(
      Cl.ok(Cl.principal(wallet2)),
    );

    expectError(
      simnet.callPublicFn(VAULT, 'set-paused', [Cl.bool(true)], deployer).result,
      ERR_UNAUTHORIZED,
    );
    const newAdminUpdate = simnet.callPublicFn(
      VAULT,
      'set-paused',
      [Cl.bool(true)],
      wallet2,
    );
    expect(newAdminUpdate.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(newAdminUpdate.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(simnet.callReadOnlyFn(VAULT, 'is-paused', [], deployer).result).toEqual(Cl.bool(true));
  });

  it('fails closed for strategy allocation without moving or accounting assets', () => {
    expectError(
      simnet.callPublicFn(
        VAULT,
        'allocate-to-strategy',
        [Cl.principal(wallet2), Cl.uint(1)],
        deployer,
      ).result,
      ERR_STRATEGY_DISABLED,
    );
    expect(readUint(VAULT, 'get-total-assets', [])).toBe(0n);
    expect(readUint(VAULT, 'get-total-shares', [])).toBe(0n);
    expect(mockBalance(vaultPrincipal())).toBe(0n);
  });
});

describe('sBTC vault test-only custody failure fixtures', () => {
  let simnet: SimnetLike;
  let deployer: string;
  let wallet1: string;
  let fixtureName: string;

  const fixtureToken = () => Cl.contractPrincipal(deployer, fixtureName);
  const vaultPrincipal = () => `${deployer}.${VAULT}`;

  const expectError = (result: unknown, code: number) => {
    expect(result).toEqual(Cl.error(Cl.uint(code)));
  };

  const readAccounting = (user: string) =>
    Cl.prettyPrint(
      simnet.callReadOnlyFn(VAULT, 'get-accounting', [Cl.principal(user)], deployer).result,
    );

  const makeCompliant = (user: string, key: EC.KeyPair) => {
    const userHash = crypto.createHash('sha256').update(user).digest();
    expect(
      simnet.callPublicFn(
        REGULATORY,
        'register-user-hash',
        [Cl.principal(user), Cl.buffer(userHash)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const hashResult = simnet.callReadOnlyFn(
      REGULATORY,
      'get-sip018-hash',
      [Cl.principal(user), Cl.stringAscii('USA'), Cl.uint(1)],
      deployer,
    ).result as any;
    const hashHex = hashResult.value.value as string;
    const hashBytes = Buffer.from(hashHex.startsWith('0x') ? hashHex.slice(2) : hashHex, 'hex');
    const signature = key.sign(hashBytes, { canonical: true });
    const signatureBuffer = Buffer.concat([
      Buffer.from(signature.r.toArray('be', 32)),
      Buffer.from(signature.s.toArray('be', 32)),
      Buffer.from([signature.recoveryParam ?? 0]),
    ]);

    expect(
      simnet.callPublicFn(
        REGULATORY,
        'verify-and-update-compliance',
        [
          Cl.principal(user),
          Cl.stringAscii('USA'),
          Cl.uint(1),
          Cl.buffer(signatureBuffer),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  };

  beforeEach(async () => {
    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    fixtureName = 'sbtc-vault-adversarial-token';

    const key = new EC('secp256k1').genKeyPair();
    expect(
      simnet.callPublicFn(
        REGULATORY,
        'update-authority',
        [Cl.principal(deployer), Cl.buffer(Buffer.from(key.getPublic(true, 'hex'), 'hex'))],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    makeCompliant(wallet1, key);

    const deployment = simnet.deployContract(
      fixtureName,
      ADVERSARIAL_TOKEN_SOURCE,
      // The current Clarinet SDK simnet epoch is 3.0, so ad hoc deployments
      // must use Clarity 3 even though production manifests target Clarity 4.
      { clarityVersion: ClarityVersion.Clarity3 },
      deployer,
    );
    expect(deployment.result).toEqual(Cl.bool(true));
    expect(
      simnet.callPublicFn(
        fixtureName,
        'mint',
        [Cl.uint(100), Cl.principal(wallet1)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(VAULT, 'set-approved-token', [fixtureToken()], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(VAULT, 'set-deposit-cap', [Cl.uint(150)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('preserves state when a token reports success but under-credits the vault', () => {
    expect(
      simnet.callPublicFn(fixtureName, 'set-under-credit', [Cl.bool(true)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const deposit = simnet.callPublicFn(
      VAULT,
      'deposit',
      [Cl.uint(10), fixtureToken()],
      wallet1,
    );
    expectError(deposit.result, ERR_DEPOSIT_RECONCILIATION);
    expect(readAccounting(wallet1)).toContain('total-assets: u0');
    expect(readAccounting(wallet1)).toContain('total-shares: u0');
    expect(
      simnet.callReadOnlyFn(fixtureName, 'get-balance', [Cl.principal(vaultPrincipal())], deployer).result,
    ).toEqual(Cl.ok(Cl.uint(0)));
    expect(
      simnet.callReadOnlyFn(fixtureName, 'get-balance', [Cl.principal(wallet1)], deployer).result,
    ).toEqual(Cl.ok(Cl.uint(100)));
  });

  it('rejects every withdrawal when live assets are below aggregate accounting', () => {
    expect(
      simnet.callPublicFn(
        VAULT,
        'deposit',
        [Cl.uint(100), fixtureToken()],
        wallet1,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(fixtureName, 'set-balance-offset', [Cl.uint(1)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const withdrawal = simnet.callPublicFn(
      VAULT,
      'withdraw',
      [Cl.uint(1), fixtureToken()],
      wallet1,
    );
    expectError(withdrawal.result, ERR_INSOLVENT);
    expect(readAccounting(wallet1)).toContain('total-assets: u100');
    expect(readAccounting(wallet1)).toContain('total-shares: u100');
    expect(
      simnet.callReadOnlyFn(fixtureName, 'get-balance', [Cl.principal(vaultPrincipal())], deployer).result,
    ).toEqual(Cl.ok(Cl.uint(99)));
  });
});
