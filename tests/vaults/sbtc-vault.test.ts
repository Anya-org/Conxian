import { beforeEach, describe, expect, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
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
const ERR_ACTIVE_VAULT = 5116;
const ERR_STRATEGY_DISABLED = 5117;

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
    expect(
      simnet.callPublicFn(VAULT, 'set-approved-token', [canonicalToken()], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
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
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(100), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(50), canonicalToken()], wallet2).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(readUint(VAULT, 'get-total-assets', [])).toBe(150n);
    expect(readUint(VAULT, 'get-total-shares', [])).toBe(150n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet1)])).toBe(100n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet2)])).toBe(50n);
    expect(readOkUint(VAULT, 'get-user-asset-value', [Cl.principal(wallet1)])).toBe(100n);
    expect(readOkUint(VAULT, 'get-user-asset-value', [Cl.principal(wallet2)])).toBe(50n);
    expect(mockBalance(vaultPrincipal())).toBe(150n);

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
    expect(
      simnet.callPublicFn(VAULT, 'withdraw', [Cl.uint(10), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

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

    expect(
      simnet.callPublicFn(VAULT, 'withdraw', [Cl.uint(25), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(readUint(VAULT, 'get-total-assets', [])).toBe(125n);
    expect(readUint(VAULT, 'get-total-shares', [])).toBe(125n);
    expect(readUint(VAULT, 'get-user-shares', [Cl.principal(wallet1)])).toBe(75n);
    expect(mockBalance(wallet1)).toBe(925n);
    expect(mockBalance(vaultPrincipal())).toBe(125n);
  });

  it('does not allow changing the canonical token while shares are outstanding', () => {
    expect(
      simnet.callPublicFn(VAULT, 'deposit', [Cl.uint(1), canonicalToken()], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expectError(
      simnet.callPublicFn(VAULT, 'set-approved-token', [wrongToken()], deployer).result,
      ERR_ACTIVE_VAULT,
    );
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
