import crypto from 'node:crypto';
import { ec as EC } from 'elliptic';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CXLP = 'cxlp-token';
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
  }

  if (!restored) return;

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
    simnet.callPublicFn(CXLP, 'remove-minter', [principalValue(target)], deployer);
    simnet.callPublicFn(CXLP, 'remove-burner', [principalValue(target)], deployer);
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
