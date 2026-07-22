import { beforeEach, describe, expect, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import crypto from 'node:crypto';

const STAKING = 'cxd-staking';
const CXD = 'cxd-token';
const REGULATORY = 'regulatory-adapter';
const FORWARDER = 'mock-admin-forwarder';

const ERR_UNAUTHORIZED = 8000;
const ERR_NON_COMPLIANT = 8001;
const ERR_ZERO_STAKE = 8002;
const ERR_PAUSED = 8004;
const ERR_PENDING_UNSTAKE = 8005;
const ERR_COOLDOWN = 8006;
const ERR_NOT_FUNDED = 8007;
const ERR_INVALID_RATE = 8008;
const ERR_INVALID_COOLDOWN = 8009;
const ERR_INSUFFICIENT_BALANCE = 8014;

type SimnetLike = any;

describe('CXD staking Phase 1', () => {
  let simnet: SimnetLike;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let forwarder: string;
  const unregisteredUser = 'ST000000000000000000002AMW42H';

  const readOkUint = (contract: string, functionName: string, args: any[], sender = deployer): bigint => {
    const result = simnet.callReadOnlyFn(contract, functionName, args, sender).result as any;
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('uint');
    return BigInt(result.value.value);
  };

  const readUint = (contract: string, functionName: string, args: any[], sender = deployer): bigint => {
    const result = simnet.callReadOnlyFn(contract, functionName, args, sender).result as any;
    expect(result.type).toBe('uint');
    return BigInt(result.value);
  };

  const cxdBalance = (user: string): bigint =>
    readOkUint(CXD, 'get-balance', [Cl.principal(user)]);

  const callForwarder = (method: string, args: any[], sender = deployer) =>
    simnet.callPublicFn(FORWARDER, method, args, sender);

  const expectError = (result: any, code: number) => {
    expect(result).toEqual(Cl.error(Cl.uint(code)));
  };

  const mintCxd = (amount: number | bigint, recipient: string) => {
    expect(
      simnet.callPublicFn(CXD, 'mint', [Cl.uint(amount), Cl.principal(recipient)], deployer).result,
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
    const r = Buffer.from(signature.r.toArray('be', 32));
    const s = Buffer.from(signature.s.toArray('be', 32));
    const v = Buffer.from([signature.recoveryParam ?? 0]);

    expect(
      simnet.callPublicFn(
        REGULATORY,
        'verify-and-update-compliance',
        [
          Cl.principal(user),
          Cl.stringAscii('USA'),
          Cl.uint(1),
          Cl.buffer(Buffer.concat([r, s, v])),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  };

  beforeEach(async () => {
    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    wallet2 = simnet.getAccounts().get('wallet_2')!;
    wallet3 = simnet.getAccounts().get('wallet_3')!;
    forwarder = `${deployer}.${FORWARDER}`;

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

    mintCxd(10_000, deployer);
    mintCxd(1_000, wallet1);
    mintCxd(1_000, wallet2);

    expect(
      simnet.callPublicFn(STAKING, 'set-cooldown-blocks', [Cl.uint(3)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('enforces authorization, bounds, zero/over-balance checks, and fail-closed compliance', () => {
    expectError(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(1)], wallet3).result,
      ERR_UNAUTHORIZED,
    );
    expectError(
      simnet.callPublicFn(STAKING, 'set-paused', [Cl.bool(true)], wallet3).result,
      ERR_UNAUTHORIZED,
    );
    expectError(
      simnet.callPublicFn(STAKING, 'fund-rewards', [Cl.uint(1)], wallet1).result,
      ERR_UNAUTHORIZED,
    );

    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(1_000_000_000_001)], deployer).result,
    ).toEqual(Cl.error(Cl.uint(ERR_INVALID_RATE)));
    expect(
      simnet.callPublicFn(STAKING, 'set-cooldown-blocks', [Cl.uint(0)], deployer).result,
    ).toEqual(Cl.error(Cl.uint(ERR_INVALID_COOLDOWN)));
    expect(
      simnet.callPublicFn(STAKING, 'set-cooldown-blocks', [Cl.uint(1_000_001)], deployer).result,
    ).toEqual(Cl.error(Cl.uint(ERR_INVALID_COOLDOWN)));

    expectError(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(0)], wallet1).result,
      ERR_ZERO_STAKE,
    );
    expectError(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(1)], unregisteredUser).result,
      ERR_NON_COMPLIANT,
    );
    expectError(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(1_001)], wallet1).result,
      ERR_INSUFFICIENT_BALANCE,
    );
  });

  it('accepts the maximum reward rate and accumulates over mined blocks without overflow', () => {
    expect(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(100)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(1_000_000_000_000)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    simnet.mineEmptyBlocks(3);

    const stats = simnet.callReadOnlyFn(STAKING, 'get-staking-stats', [], deployer).result as any;
    expect(stats.type).toBe('ok');
    expect(Cl.prettyPrint(stats)).toContain('reward-rate: u1000000000000');
    expect(Cl.prettyPrint(stats)).not.toContain('reward-per-token: u0');
    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet1)], wallet1)).toBeGreaterThan(0n);
  });

  it('accepts the maximum cooldown and exercises the checked block-boundary addition', () => {
    expect(
      simnet.callPublicFn(STAKING, 'set-cooldown-blocks', [Cl.uint(1_000_000)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(100)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    const requestBlock = readUint('block-utils', 'get-burn-block-height', []);
    expect(
      simnet.callPublicFn(STAKING, 'request-unstake', [Cl.uint(100)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const position = Cl.prettyPrint(
      simnet.callReadOnlyFn(STAKING, 'get-position', [Cl.principal(wallet1)], deployer).result,
    );
    expect(position).toContain('pending-unstake: u100');
    expect(position).toContain(`cooldown-end: u${requestBlock + 1_000_000n}`);
  });

  it('authenticates the immediate caller and supports deliberate contract-admin forwarding', () => {
    expectError(
      callForwarder('forward-staking-set-admin', [Cl.principal(wallet1)], deployer).result,
      ERR_UNAUTHORIZED,
    );
    expectError(
      callForwarder('forward-staking-set-reward-rate', [Cl.uint(7)], deployer).result,
      ERR_UNAUTHORIZED,
    );
    expectError(
      callForwarder('forward-staking-fund-rewards', [Cl.uint(100)], deployer).result,
      ERR_UNAUTHORIZED,
    );
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(STAKING, 'get-config', [], deployer).result)).toContain(
      `admin: '${deployer}`,
    );

    expect(
      simnet.callPublicFn(STAKING, 'set-admin', [Cl.contractPrincipal(deployer, FORWARDER)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    mintCxd(500, forwarder);

    const forwardedRate = callForwarder('forward-staking-set-reward-rate', [Cl.uint(7)], wallet2);
    expect(forwardedRate.result).toEqual(Cl.ok(Cl.bool(true)));

    const forwardedFunding = callForwarder('forward-staking-fund-rewards', [Cl.uint(100)], wallet2);
    expect(forwardedFunding.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(cxdBalance(forwarder)).toBe(400n);
    expect(readOkUint(STAKING, 'get-available-reward-reserve', [], deployer)).toBe(100n);
    expect(JSON.stringify(forwardedFunding.events)).toContain(forwarder);

    const handoff = callForwarder('forward-staking-set-admin', [Cl.principal(wallet1)], wallet2);
    expect(handoff.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(JSON.stringify(handoff.events)).toContain(`old-admin`);
    expect(JSON.stringify(handoff.events)).toContain(forwarder);

    expectError(
      callForwarder('forward-staking-set-reward-rate', [Cl.uint(8)], wallet2).result,
      ERR_UNAUTHORIZED,
    );
    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(8)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('checkpoints accrued rewards when the admin changes the reward rate', () => {
    expect(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(100)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(100)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    simnet.mineEmptyBlocks(5);
    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(200)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet1)], wallet1)).toBe(500n);

    simnet.mineEmptyBlocks(3);
    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet1)], wallet1)).toBe(1_100n);
  });

  it('moves CXD, accrues proportionally with checkpoints, and protects prefunded principal', () => {
    const userBalanceBefore = cxdBalance(wallet1);
    const stakingBalanceBefore = cxdBalance(`${deployer}.${STAKING}`);

    expect(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(400)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(cxdBalance(wallet1)).toBe(userBalanceBefore - 400n);
    expect(cxdBalance(`${deployer}.${STAKING}`)).toBe(stakingBalanceBefore + 400n);
    expect(readOkUint(STAKING, 'get-user-balance', [Cl.principal(wallet1)], wallet1)).toBe(400n);
    expect(readUint(STAKING, 'get-governance-weight', [Cl.principal(wallet1)], wallet1)).toBe(400n);

    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(100)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(10);
    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet1)], wallet1)).toBe(1_000n);

    // A failed claim cannot spend the 400 CXD principal when no reward reserve
    // has been recorded, even though the live contract balance is non-zero.
    expect(
      simnet.callPublicFn(STAKING, 'claim-rewards', [], wallet1).result,
    ).toEqual(Cl.error(Cl.uint(ERR_NOT_FUNDED)));
    expect(cxdBalance(`${deployer}.${STAKING}`)).toBe(400n);
    expect(readOkUint(STAKING, 'get-available-reward-reserve', [], deployer)).toBe(0n);

    mintCxd(5_000, deployer);
    expect(
      simnet.callPublicFn(STAKING, 'fund-rewards', [Cl.uint(5_000)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(400)], wallet2).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(10);

    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet1)], wallet1)).toBe(1_500n);
    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet2)], wallet2)).toBe(500n);

    expect(
      simnet.callPublicFn(STAKING, 'request-unstake', [Cl.uint(100)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(readUint(STAKING, 'get-governance-weight', [Cl.principal(wallet1)], wallet1)).toBe(300n);
    expect(readOkUint(STAKING, 'get-earned', [Cl.principal(wallet1)], wallet1)).toBe(1_500n);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(STAKING, 'get-staking-stats', [], deployer).result)).toContain(
      'total-active-stake: u700',
    );
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(STAKING, 'get-position', [Cl.principal(wallet1)], deployer).result)).toContain(
      'pending-unstake: u100',
    );

    const wallet1BeforeClaim = cxdBalance(wallet1);
    expect(
      simnet.callPublicFn(STAKING, 'claim-rewards', [], wallet1).result,
    ).toEqual(Cl.ok(Cl.uint(1_500)));
    expect(cxdBalance(wallet1)).toBe(wallet1BeforeClaim + 1_500n);
    expect(cxdBalance(`${deployer}.${STAKING}`)).toBe(4_300n);
    expect(readOkUint(STAKING, 'get-available-reward-reserve', [], deployer)).toBe(3_500n);
  });

  it('keeps claims and completed withdrawals open while staking is paused', () => {
    expect(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(500)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(STAKING, 'set-reward-rate', [Cl.uint(100)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    mintCxd(1_000, deployer);
    expect(
      simnet.callPublicFn(STAKING, 'fund-rewards', [Cl.uint(1_000)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(5);

    expect(
      simnet.callPublicFn(STAKING, 'set-paused', [Cl.bool(true)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expectError(
      simnet.callPublicFn(STAKING, 'stake', [Cl.uint(1)], wallet2).result,
      ERR_PAUSED,
    );
    expect(
      simnet.callPublicFn(STAKING, 'claim-rewards', [], wallet1).result,
    ).toEqual(Cl.ok(Cl.uint(500)));

    const balanceBeforeRequest = cxdBalance(wallet1);
    expect(
      simnet.callPublicFn(STAKING, 'request-unstake', [Cl.uint(100)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expectError(
      simnet.callPublicFn(STAKING, 'request-unstake', [Cl.uint(1)], wallet1).result,
      ERR_PENDING_UNSTAKE,
    );
    expectError(
      simnet.callPublicFn(STAKING, 'complete-unstake', [], wallet1).result,
      ERR_COOLDOWN,
    );
    simnet.mineEmptyBlocks(2);
    expectError(
      simnet.callPublicFn(STAKING, 'complete-unstake', [], wallet1).result,
      ERR_COOLDOWN,
    );
    simnet.mineEmptyBlocks(1);
    expect(
      simnet.callPublicFn(STAKING, 'complete-unstake', [], wallet1).result,
    ).toEqual(Cl.ok(Cl.uint(100)));
    expect(cxdBalance(wallet1)).toBe(balanceBeforeRequest + 100n);
  });
});
