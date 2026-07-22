import crypto from 'node:crypto';
import { ec as EC } from 'elliptic';
import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CXLP = 'cxlp-token';
const CLP = 'concentrated-liquidity-pool';
const COORDINATOR = 'token-system-coordinator';

const ERR_UNAUTHORIZED = 1000;
const ERR_INVALID_AMOUNT = 1001;
const ERR_OWNER_MISMATCH = 1002;
const ERR_INSUFFICIENT_BALANCE = 1003;

function principalValue(principal: string) {
  const separator = principal.indexOf('.');
  return separator === -1
    ? Cl.principal(principal)
    : Cl.contractPrincipal(principal.slice(0, separator), principal.slice(separator + 1));
}

function cxlpPrincipal(deployer: string) {
  return Cl.contractPrincipal(deployer, CXLP);
}

function coordinatorPrincipal(deployer: string) {
  return Cl.contractPrincipal(deployer, COORDINATOR);
}

function balanceOf(owner: string, deployer: string) {
  return simnet.callReadOnlyFn(CXLP, 'get-balance', [principalValue(owner)], deployer).result;
}

function totalSupply(deployer: string) {
  return simnet.callReadOnlyFn(CXLP, 'get-total-supply', [], deployer).result;
}

function uintResult(result: any): bigint {
  const match = Cl.prettyPrint(result).match(/^\(ok u(\d+)\)$/);
  if (!match) {
    throw new Error(`Expected an ok uint, got ${Cl.prettyPrint(result)}`);
  }
  return BigInt(match[1]);
}

function okTrue() {
  return Cl.ok(Cl.bool(true));
}

function error(code: number) {
  return Cl.error(Cl.uint(code));
}

function accounts() {
  const values = simnet.getAccounts();
  return {
    deployer: values.get('deployer')!,
    wallet1: values.get('wallet_1')!,
    wallet2: values.get('wallet_2')!,
    wallet3: values.get('wallet_3')!,
  };
}

function restoreCxlpState() {
  const { deployer, wallet1, wallet2, wallet3 } = accounts();
  const candidates = [deployer, wallet1, wallet2, wallet3];
  let restored = false;

  for (const candidate of candidates) {
    const result = simnet.callPublicFn(
      CXLP,
      'initialize',
      [Cl.principal(deployer)],
      candidate,
    ).result;
    if (Cl.prettyPrint(result) === '(ok true)') {
      restored = true;
      break;
    }
    expect(result).toEqual(error(ERR_UNAUTHORIZED));
  }

  expect(restored).toBe(true);

  const owners = [deployer, wallet1, wallet2, wallet3, `${deployer}.${COORDINATOR}`];
  for (const owner of owners) {
    const balance = uintResult(balanceOf(owner, deployer));
    if (balance > 0n) {
      simnet.callPublicFn(
        CXLP,
        'burn',
        [Cl.uint(balance), principalValue(owner)],
        deployer,
      );
    }
  }

  const roleTargets = [wallet1, wallet2, wallet3, `${deployer}.${COORDINATOR}`];
  for (const target of roleTargets) {
    expect(
      simnet.callPublicFn(CXLP, 'remove-minter', [principalValue(target)], deployer).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(CXLP, 'remove-burner', [principalValue(target)], deployer).result,
    ).toEqual(okTrue());
  }
}

function setCompliance(user: string, deployer: string) {
  const userHash = crypto.createHash('sha256').update(user).digest();
  expect(
    simnet.callPublicFn(
      'regulatory-adapter',
      'register-user-hash',
      [Cl.principal(user), Cl.buffer(userHash)],
      deployer,
    ).result,
  ).toEqual(okTrue());

  const hashResult = simnet.callReadOnlyFn(
    'regulatory-adapter',
    'get-sip018-hash',
    [Cl.principal(user), Cl.stringAscii('USA'), Cl.uint(1)],
    deployer,
  ).result;
  const hashHex = String((hashResult as any).value.value);
  const hashBytes = Buffer.from(hashHex.replace(/^0x/, ''), 'hex');

  const key = new EC('secp256k1').genKeyPair();
  const signature = key.sign(hashBytes, { canonical: true });
  const signatureBuffer = Buffer.concat([
    Buffer.from(signature.r.toArray('be', 32)),
    Buffer.from(signature.s.toArray('be', 32)),
    Buffer.from([signature.recoveryParam]),
  ]);

  expect(
    simnet.callPublicFn(
      'regulatory-adapter',
      'update-authority',
      [Cl.principal(deployer), Cl.buffer(Buffer.from(key.getPublic(true, 'hex'), 'hex'))],
      deployer,
    ).result,
  ).toEqual(okTrue());

  expect(
    simnet.callPublicFn(
      'regulatory-adapter',
      'verify-and-update-compliance',
      [
        Cl.principal(user),
        Cl.stringAscii('USA'),
        Cl.uint(1),
        Cl.buffer(signatureBuffer),
      ],
      deployer,
    ).result,
  ).toEqual(okTrue());
}

function readUint(contract: string, method: string, args: any[], sender: string): bigint {
  const result = simnet.callReadOnlyFn(contract, method, args, sender).result;
  expect(result.type).toBe('ok');
  return uintResult(result);
}

function readPool(poolId: bigint, sender: string): string {
  const result = simnet.callReadOnlyFn(CLP, 'get-pool', [Cl.uint(poolId)], sender).result;
  return Cl.prettyPrint(result);
}

function readPoolOutstanding(poolId: bigint, sender: string): bigint {
  return readUint(CLP, 'get-pool-outstanding-shares', [Cl.uint(poolId)], sender);
}

describe('CXLP mint and burn authorization', () => {
  beforeEach(() => {
    restoreCxlpState();
    const { deployer } = accounts();
    expect(simnet.callReadOnlyFn(CXLP, 'get-admin', [], deployer).result).toEqual(
      Cl.ok(Cl.principal(deployer)),
    );
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(0)));
  });

  afterEach(() => {
    restoreCxlpState();
  });

  it('keeps the admin, minter, and burner roles separate and admin-managed', () => {
    const { deployer, wallet1, wallet2, wallet3 } = accounts();

    expect(simnet.callReadOnlyFn(CXLP, 'is-admin', [Cl.principal(deployer)], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-admin', [Cl.principal(wallet3)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'get-name', [], deployer).result).toEqual(
      Cl.ok(Cl.stringAscii('Conxian LP Token               ')),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'get-symbol', [], deployer).result).toEqual(
      Cl.ok(Cl.stringAscii('CXLP                            ')),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'get-decimals', [], deployer).result).toEqual(
      Cl.ok(Cl.uint(8)),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'get-token-uri', [], deployer).result).toEqual(
      Cl.ok(Cl.none()),
    );

    expect(simnet.callPublicFn(CXLP, 'add-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      okTrue(),
    );
    expect(simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(wallet2)], deployer).result).toEqual(
      okTrue(),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(wallet1)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(wallet2)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(wallet2)], deployer).result).toEqual(
      Cl.bool(true),
    );

    expect(simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(wallet3)], wallet1).result).toEqual(
      error(ERR_UNAUTHORIZED),
    );
    expect(simnet.callPublicFn(CXLP, 'remove-minter', [Cl.principal(wallet1)], wallet1).result).toEqual(
      error(ERR_UNAUTHORIZED),
    );

    expect(simnet.callPublicFn(CXLP, 'remove-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      okTrue(),
    );
    expect(simnet.callPublicFn(CXLP, 'remove-burner', [Cl.principal(wallet2)], deployer).result).toEqual(
      okTrue(),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(wallet2)], deployer).result).toEqual(
      Cl.bool(false),
    );
  });

  it('mints supply for direct admin and nested coordinator callers only', () => {
    const { deployer, wallet1, wallet2 } = accounts();
    const coordinator = coordinatorPrincipal(deployer);

    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(100), Cl.principal(wallet1)], deployer).result,
    ).toEqual(okTrue());
    expect(balanceOf(wallet1, deployer)).toEqual(Cl.ok(Cl.uint(100)));

    expect(simnet.callPublicFn(CXLP, 'add-minter', [coordinator], deployer).result).toEqual(okTrue());
    setCompliance(wallet2, deployer);

    expect(
      simnet.callPublicFn(
        COORDINATOR,
        'mint-cxd',
        [cxlpPrincipal(deployer), Cl.uint(250), Cl.principal(wallet2)],
        deployer,
      ).result,
    ).toEqual(okTrue());
    expect(balanceOf(wallet2, deployer)).toEqual(Cl.ok(Cl.uint(250)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(350)));

    const revokedBalance = balanceOf(wallet2, deployer);
    const revokedSupply = totalSupply(deployer);
    expect(simnet.callPublicFn(CXLP, 'remove-minter', [coordinator], deployer).result).toEqual(
      okTrue(),
    );
    expect(
      simnet.callPublicFn(
        COORDINATOR,
        'mint-cxd',
        [cxlpPrincipal(deployer), Cl.uint(25), Cl.principal(wallet2)],
        deployer,
      ).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(balanceOf(wallet2, deployer)).toEqual(revokedBalance);
    expect(totalSupply(deployer)).toEqual(revokedSupply);

    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(1), Cl.principal(wallet2)], wallet2).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(0), Cl.principal(wallet1)], deployer).result,
    ).toEqual(error(ERR_INVALID_AMOUNT));
  });

  it('supports direct and nested burns with exact failure invariants', () => {
    const { deployer, wallet1, wallet2 } = accounts();
    const coordinator = coordinatorPrincipal(deployer);

    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(700), Cl.principal(wallet1)], deployer).result,
    ).toEqual(okTrue());
    expect(simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(wallet1)], deployer).result).toEqual(
      okTrue(),
    );

    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(100), Cl.principal(wallet1)], wallet1).result,
    ).toEqual(okTrue());
    expect(balanceOf(wallet1, deployer)).toEqual(Cl.ok(Cl.uint(600)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(600)));

    // The retained admin emergency path may burn another owner's balance.
    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(50), Cl.principal(wallet1)], deployer).result,
    ).toEqual(okTrue());
    expect(balanceOf(wallet1, deployer)).toEqual(Cl.ok(Cl.uint(550)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(550)));

    expect(simnet.callPublicFn(CXLP, 'add-burner', [coordinator], deployer).result).toEqual(okTrue());

    const crossOwnerBalance = balanceOf(wallet1, deployer);
    const crossOwnerSupply = totalSupply(deployer);
    expect(
      simnet.callPublicFn(
        COORDINATOR,
        'burn-cxd',
        [cxlpPrincipal(deployer), Cl.uint(50), Cl.principal(wallet1)],
        wallet2,
      ).result,
    ).toEqual(error(ERR_OWNER_MISMATCH));
    expect(balanceOf(wallet1, deployer)).toEqual(crossOwnerBalance);
    expect(totalSupply(deployer)).toEqual(crossOwnerSupply);

    expect(
      simnet.callPublicFn(
        COORDINATOR,
        'burn-cxd',
        [cxlpPrincipal(deployer), Cl.uint(50), Cl.principal(wallet1)],
        wallet1,
      ).result,
    ).toEqual(okTrue());
    expect(balanceOf(wallet1, deployer)).toEqual(Cl.ok(Cl.uint(500)));
    expect(totalSupply(deployer)).toEqual(Cl.ok(Cl.uint(500)));

    const revokedBalance = balanceOf(wallet1, deployer);
    const revokedSupply = totalSupply(deployer);
    expect(simnet.callPublicFn(CXLP, 'remove-burner', [coordinator], deployer).result).toEqual(
      okTrue(),
    );
    expect(
      simnet.callPublicFn(
        COORDINATOR,
        'burn-cxd',
        [cxlpPrincipal(deployer), Cl.uint(1), Cl.principal(wallet1)],
        wallet1,
      ).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(balanceOf(wallet1, deployer)).toEqual(revokedBalance);
    expect(totalSupply(deployer)).toEqual(revokedSupply);

    const insufficientBalance = balanceOf(wallet1, deployer);
    const insufficientSupply = totalSupply(deployer);
    expect(
      simnet.callPublicFn(
        CXLP,
        'burn',
        [Cl.uint(501), Cl.principal(wallet1)],
        wallet1,
      ).result,
    ).toEqual(error(ERR_INSUFFICIENT_BALANCE));
    expect(balanceOf(wallet1, deployer)).toEqual(insufficientBalance);
    expect(totalSupply(deployer)).toEqual(insufficientSupply);

    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(1), Cl.principal(wallet2)], wallet2).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(0), Cl.principal(wallet1)], wallet1).result,
    ).toEqual(error(ERR_INVALID_AMOUNT));
  });

  it('rotates a standard-principal admin and restores the original admin', () => {
    const { deployer, wallet1, wallet2, wallet3 } = accounts();

    expect(
      simnet.callPublicFn(CXLP, 'initialize', [Cl.principal(wallet3)], deployer).result,
    ).toEqual(okTrue());
    expect(simnet.callReadOnlyFn(CXLP, 'get-admin', [], deployer).result).toEqual(
      Cl.ok(Cl.principal(wallet3)),
    );

    expect(simnet.callPublicFn(CXLP, 'add-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      error(ERR_UNAUTHORIZED),
    );
    expect(simnet.callPublicFn(CXLP, 'add-minter', [Cl.principal(wallet1)], wallet3).result).toEqual(
      okTrue(),
    );
    expect(simnet.callPublicFn(CXLP, 'add-burner', [Cl.principal(wallet2)], wallet3).result).toEqual(
      okTrue(),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [Cl.principal(wallet2)], deployer).result).toEqual(
      Cl.bool(true),
    );

    expect(
      simnet.callPublicFn(CXLP, 'initialize', [Cl.principal(deployer)], deployer).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(
      simnet.callPublicFn(CXLP, 'initialize', [Cl.principal(deployer)], wallet3).result,
    ).toEqual(okTrue());
    expect(simnet.callReadOnlyFn(CXLP, 'get-admin', [], deployer).result).toEqual(
      Cl.ok(Cl.principal(deployer)),
    );

    expect(simnet.callPublicFn(CXLP, 'remove-minter', [Cl.principal(wallet1)], deployer).result).toEqual(
      okTrue(),
    );
    expect(simnet.callPublicFn(CXLP, 'remove-burner', [Cl.principal(wallet2)], deployer).result).toEqual(
      okTrue(),
    );
  });

  it('does not mint CXLP when a concentrated pool is created', () => {
    const { deployer } = accounts();
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

describe('CXLP mint/burn primitive and CLP reconciliation', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;

  beforeAll(() => {
    const values = simnet.getAccounts();
    deployer = values.get('deployer')!;
    wallet1 = values.get('wallet_1')!;
    wallet2 = values.get('wallet_2')!;
    wallet3 = values.get('wallet_3')!;

    const clp = Cl.contractPrincipal(deployer, CLP);
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [clp], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [clp], deployer).result).toEqual(
      Cl.bool(true),
    );
  });

  function createPool(): bigint {
    const result = simnet.callPublicFn(
      CLP,
      'create-pool',
      [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.contractPrincipal(deployer, 'cxvg-token'),
        Cl.uint(3000),
        Cl.uint(1_000_000_000_000),
        Cl.int(0),
      ],
      deployer,
    ).result;

    expect(result.type).toBe('ok');
    return uintResult(result);
  }

  it('supports separate admin role management and revocation', () => {
    const minter = Cl.principal(wallet1);
    const burner = Cl.principal(wallet2);

    expect(simnet.callPublicFn(CXLP, 'add-minter', [minter], deployer).result).toEqual(okTrue());
    expect(simnet.callPublicFn(CXLP, 'add-burner', [burner], deployer).result).toEqual(okTrue());
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [minter], deployer).result).toEqual(
      Cl.bool(true),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [burner], deployer).result).toEqual(
      Cl.bool(true),
    );

    expect(
      simnet.callPublicFn(CXLP, 'add-minter', [Cl.principal(wallet3)], wallet1).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(simnet.callPublicFn(CXLP, 'remove-burner', [burner], wallet2).result).toEqual(
      error(ERR_UNAUTHORIZED),
    );

    expect(simnet.callPublicFn(CXLP, 'remove-minter', [minter], deployer).result).toEqual(okTrue());
    expect(simnet.callPublicFn(CXLP, 'remove-burner', [burner], deployer).result).toEqual(okTrue());
    expect(simnet.callReadOnlyFn(CXLP, 'is-minter', [minter], deployer).result).toEqual(
      Cl.bool(false),
    );
    expect(simnet.callReadOnlyFn(CXLP, 'is-burner', [burner], deployer).result).toEqual(
      Cl.bool(false),
    );
  });

  it('rejects unauthorized EOA and contract mint/burn calls', () => {
    expect(
      simnet.callPublicFn(CXLP, 'mint', [Cl.uint(1), Cl.principal(wallet1)], wallet1).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(
      simnet.callPublicFn(CXLP, 'burn', [Cl.uint(1), Cl.principal(wallet1)], wallet1).result,
    ).toEqual(error(ERR_UNAUTHORIZED));

    const cxlp = Cl.contractPrincipal(deployer, CXLP);
    expect(
      simnet.callPublicFn(
        COORDINATOR,
        'burn-cxvg',
        [cxlp, Cl.uint(1), Cl.principal(wallet1)],
        deployer,
      ).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
  });

  it('uses an injected settlement authority for nested CLP mint and burn', () => {
    const poolId = createPool();

    expect(
      simnet.callPublicFn(CLP, 'set-settlement-authority', [Cl.principal(wallet2)], deployer).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet1), Cl.uint(100)],
        deployer,
      ).result,
    ).toEqual(error(ERR_UNAUTHORIZED));

    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(100)],
        wallet2,
      ).result,
    ).toEqual(okTrue());

    expect(
      simnet.callPublicFn(
        CLP,
        'burn-shares',
        [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(40)],
        wallet2,
      ).result,
    ).toEqual(okTrue());

    expect(readPoolOutstanding(poolId, deployer)).toBe(60n);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(
      readUint(CXLP, 'get-total-supply', [], deployer),
    );
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet2)], deployer)).toBe(60n);

    expect(
      simnet.callPublicFn(CLP, 'set-settlement-authority', [Cl.principal(deployer)], deployer).result,
    ).toEqual(okTrue());
  });

  it('rejects zero, missing-pool, and insufficient-share operations without state changes', () => {
    const poolId = createPool();
    const supplyBefore = readUint(CXLP, 'get-total-supply', [], deployer);

    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(0)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1002)));
    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(999_999), Cl.principal(wallet3), Cl.uint(1)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1003)));
    expect(
      simnet.callPublicFn(
        CLP,
        'burn-shares',
        [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(1)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(1005)));

    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(supplyBefore);
    expect(readPoolOutstanding(poolId, deployer)).toBe(0n);
    expect(readPool(poolId, deployer)).toContain('outstanding-shares: u0');
  });

  it('reconciles pool, owner, canonical balance, and global supply exactly', () => {
    const poolId = createPool();
    const beforeSupply = readUint(CXLP, 'get-total-supply', [], deployer);

    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(250)],
        deployer,
      ).result,
    ).toEqual(okTrue());

    expect(readPoolOutstanding(poolId, deployer)).toBe(250n);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(beforeSupply + 250n);
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet3)], deployer)).toBe(250n);
    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(beforeSupply + 250n);

    expect(
      simnet.callPublicFn(CLP, 'set-settlement-authority', [Cl.principal(wallet3)], deployer).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'burn-shares',
        [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(90)],
        wallet3,
      ).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(CLP, 'set-settlement-authority', [Cl.principal(deployer)], deployer).result,
    ).toEqual(okTrue());

    expect(readPoolOutstanding(poolId, deployer)).toBe(160n);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(beforeSupply + 160n);
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet3)], deployer)).toBe(160n);
    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(beforeSupply + 160n);
  });

  it('rolls back local reconciliation when downstream mint or burn authorization fails', () => {
    const poolId = createPool();
    const clp = Cl.contractPrincipal(deployer, CLP);

    const beforeMintPool = readPoolOutstanding(poolId, deployer);
    const beforeMintGlobal = readUint(CLP, 'get-total-outstanding-shares', [], deployer);
    const beforeMintSupply = readUint(CXLP, 'get-total-supply', [], deployer);

    expect(simnet.callPublicFn(CXLP, 'remove-minter', [clp], deployer).result).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(75)],
        deployer,
      ).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(simnet.callPublicFn(CXLP, 'add-minter', [clp], deployer).result).toEqual(okTrue());

    expect(readPoolOutstanding(poolId, deployer)).toBe(beforeMintPool);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(beforeMintGlobal);
    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(beforeMintSupply);

    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(75)],
        deployer,
      ).result,
    ).toEqual(okTrue());

    const beforePool = readPool(poolId, deployer);
    const beforePoolShares = readPoolOutstanding(poolId, deployer);
    const beforeGlobal = readUint(CLP, 'get-total-outstanding-shares', [], deployer);
    const beforeBalance = readUint(CXLP, 'get-balance', [Cl.principal(wallet2)], deployer);
    const beforeSupply = readUint(CXLP, 'get-total-supply', [], deployer);

    expect(simnet.callPublicFn(CXLP, 'remove-burner', [clp], deployer).result).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'burn-shares',
        [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(25)],
        deployer,
      ).result,
    ).toEqual(error(ERR_UNAUTHORIZED));
    expect(simnet.callPublicFn(CXLP, 'add-burner', [clp], deployer).result).toEqual(okTrue());

    expect(readPool(poolId, deployer)).toBe(beforePool);
    expect(readPoolOutstanding(poolId, deployer)).toBe(beforePoolShares);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(beforeGlobal);
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet2)], deployer)).toBe(beforeBalance);
    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(beforeSupply);
  });

  it('keeps direct and proxy transfers aggregate-safe across multiple pools', () => {
    const poolOne = createPool();
    const poolTwo = createPool();

    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolOne), Cl.principal(wallet1), Cl.uint(100)],
        deployer,
      ).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolTwo), Cl.principal(wallet2), Cl.uint(50)],
        deployer,
      ).result,
    ).toEqual(okTrue());

    const wallet1BeforeTransfer = readUint(CXLP, 'get-balance', [Cl.principal(wallet1)], deployer);
    const wallet2BeforeTransfer = readUint(CXLP, 'get-balance', [Cl.principal(wallet2)], deployer);
    const wallet3BeforeTransfer = readUint(CXLP, 'get-balance', [Cl.principal(wallet3)], deployer);
    const supplyBeforeTransfer = readUint(CXLP, 'get-total-supply', [], deployer);
    const globalBeforeTransfer = readUint(CLP, 'get-total-outstanding-shares', [], deployer);
    const poolOneBeforeTransfer = readPoolOutstanding(poolOne, deployer);
    const poolTwoBeforeTransfer = readPoolOutstanding(poolTwo, deployer);

    expect(
      simnet.callPublicFn(
        CXLP,
        'transfer',
        [Cl.uint(40), Cl.principal(wallet1), Cl.principal(wallet2), Cl.none()],
        wallet1,
      ).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'transfer',
        [Cl.uint(10), Cl.principal(wallet2), Cl.principal(wallet3), Cl.none()],
        wallet2,
      ).result,
    ).toEqual(okTrue());

    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet1)], deployer)).toBe(
      wallet1BeforeTransfer - 40n,
    );
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet2)], deployer)).toBe(
      wallet2BeforeTransfer + 30n,
    );
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet3)], deployer)).toBe(
      wallet3BeforeTransfer + 10n,
    );
    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(supplyBeforeTransfer);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(globalBeforeTransfer);
    expect(readPoolOutstanding(poolOne, deployer)).toBe(poolOneBeforeTransfer);
    expect(readPoolOutstanding(poolTwo, deployer)).toBe(poolTwoBeforeTransfer);

    // Settlement authority selects the pool; #536 will provide the position
    // attribution and custody checks that justify that selection.
    expect(
      simnet.callPublicFn(CLP, 'set-settlement-authority', [Cl.principal(wallet3)], deployer).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'burn-shares',
        [Cl.uint(poolOne), Cl.principal(wallet3), Cl.uint(10)],
        wallet3,
      ).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(CLP, 'set-settlement-authority', [Cl.principal(deployer)], deployer).result,
    ).toEqual(okTrue());
    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolTwo), Cl.principal(wallet3), Cl.uint(25)],
        deployer,
      ).result,
    ).toEqual(okTrue());

    expect(readPoolOutstanding(poolOne, deployer)).toBe(poolOneBeforeTransfer - 10n);
    expect(readPoolOutstanding(poolTwo, deployer)).toBe(poolTwoBeforeTransfer + 25n);
    expect(readUint(CLP, 'get-total-outstanding-shares', [], deployer)).toBe(
      globalBeforeTransfer + 15n,
    );
    expect(readUint(CXLP, 'get-total-supply', [], deployer)).toBe(supplyBeforeTransfer + 15n);
    expect(readUint(CXLP, 'get-balance', [Cl.principal(wallet3)], deployer)).toBe(
      wallet3BeforeTransfer + 25n,
    );
  });

  it('exposes canonical proxy getters without fabricating token state', () => {
    const poolId = createPool();
    expect(
      simnet.callPublicFn(
        CLP,
        'mint-shares',
        [Cl.uint(poolId), Cl.principal(wallet1), Cl.uint(30)],
        deployer,
      ).result,
    ).toEqual(okTrue());

    expect(simnet.callReadOnlyFn(CLP, 'get-name', [], deployer).result).toEqual(
      simnet.callReadOnlyFn(CXLP, 'get-name', [], deployer).result,
    );
    expect(simnet.callReadOnlyFn(CLP, 'get-symbol', [], deployer).result).toEqual(
      simnet.callReadOnlyFn(CXLP, 'get-symbol', [], deployer).result,
    );
    expect(simnet.callReadOnlyFn(CLP, 'get-decimals', [], deployer).result).toEqual(
      simnet.callReadOnlyFn(CXLP, 'get-decimals', [], deployer).result,
    );
  });
});
