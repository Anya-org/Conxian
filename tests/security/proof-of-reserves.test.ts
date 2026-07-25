import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import { simnet } from '../setup-test-env';

const CONTRACT = 'proof-of-reserves';
const TOKEN = 'mock-token';
const SCHEMA = 1n;
const DOMAIN = 'CONXIAN-POR-SNAPSHOT';
const NETWORK = 'simnet';
const CHAIN_ID = 2_147_483_648n;

const ERR_INVALID_SIGNATURE = 8001;
const ERR_STALE_SNAPSHOT = 8002;
const ERR_DUPLICATE_ATTESTATION = 8003;
const ERR_INVALID_SCHEMA = 8004;
const ERR_INVALID_DOMAIN = 8005;
const ERR_INVALID_NETWORK = 8006;
const ERR_INVALID_CHAIN = 8007;
const ERR_FUTURE_SNAPSHOT = 8008;
const ERR_EXPIRED_SNAPSHOT = 8009;
const ERR_REPLAYED_NONCE = 8010;
const ERR_LIVE_STATE_MISMATCH = 8012;
const ERR_UNBACKED_SNAPSHOT = 8013;

const ec = new EC('secp256k1');

type Attestor = {
  principal: string;
  key: EC.KeyPair;
  publicKey: Buffer;
  identity: Buffer;
};

type Snapshot = {
  epoch: bigint;
  balance: bigint;
  supply: bigint;
  backing: bigint;
  height: bigint;
  expiresAt: bigint;
};

const unwrapBuffer = (result: any): Buffer => {
  const value = result?.value?.value ?? result?.value ?? result;
  if (Buffer.isBuffer(value)) return value;
  if (value instanceof Uint8Array) return Buffer.from(value);
  if (typeof value === 'string') return Buffer.from(value.replace(/^0x/, ''), 'hex');
  throw new Error(`Expected buffer result, received ${JSON.stringify(result)}`);
};

const tupleValue = (result: any, key: string): any => result.value[key].value;

const sign = (key: EC.KeyPair, digest: Buffer): Buffer => {
  const signature = key.sign(digest, { canonical: true });
  return Buffer.concat([
    Buffer.from(signature.r.toArray('be', 32)),
    Buffer.from(signature.s.toArray('be', 32)),
    Buffer.from([signature.recoveryParam ?? 0]),
  ]);
};

describe.sequential('proof-of-reserves cryptographic snapshot binding', () => {
  let deployer: string;
  let token: ReturnType<typeof Cl.contractPrincipal>;
  let porPrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let assetIdentity: Buffer;
  let attestors: Attestor[];

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    const principals = [accounts.get('wallet_1')!, accounts.get('wallet_2')!, accounts.get('wallet_3')!];
    token = Cl.contractPrincipal(deployer, TOKEN);
    porPrincipal = Cl.contractPrincipal(deployer, CONTRACT);
    assetIdentity = createHash('sha256').update(`${deployer}.${TOKEN}`).digest();
    attestors = principals.map((principal) => {
      const key = ec.genKeyPair();
      const publicKey = Buffer.from(key.getPublic(true, 'array'));
      return { principal, key, publicKey, identity: createHash('sha256').update(publicKey).digest() };
    });
  });

  const currentHeight = (): bigint => BigInt(simnet.mineEmptyBlocks(0));

  const config = (): { epoch: bigint; chainId: bigint } => {
    const result = simnet.callReadOnlyFn(CONTRACT, 'get-domain-config', [], deployer).result as any;
    return {
      epoch: BigInt(tupleValue(result, 'registry-epoch')),
      chainId: BigInt(tupleValue(result, 'chain-id')),
    };
  };

  const snapshotDigest = (snapshot: Snapshot, overrides: Partial<{ schema: bigint; domain: string; network: string; chainId: bigint }> = {}): Buffer => {
    const result = simnet.callReadOnlyFn(CONTRACT, 'get-snapshot-digest', [
      Cl.uint(overrides.schema ?? SCHEMA),
      Cl.stringAscii(overrides.domain ?? DOMAIN),
      Cl.stringAscii(overrides.network ?? NETWORK),
      Cl.uint(overrides.chainId ?? CHAIN_ID),
      Cl.uint(snapshot.epoch),
      Cl.buffer(assetIdentity),
      Cl.uint(snapshot.balance),
      Cl.uint(snapshot.supply),
      Cl.uint(snapshot.backing),
      Cl.uint(snapshot.height),
      Cl.uint(snapshot.expiresAt),
    ], deployer).result;
    return unwrapBuffer(result);
  };

  const envelopeDigest = (digest: Buffer, attestor: Attestor, nonce: bigint): Buffer => {
    const result = simnet.callReadOnlyFn(CONTRACT, 'get-attestation-digest', [
      Cl.uint(SCHEMA),
      Cl.buffer(digest),
      Cl.buffer(attestor.identity),
      Cl.uint(nonce),
    ], deployer).result;
    return unwrapBuffer(result);
  };

  const submit = (
    attestor: Attestor,
    snapshot: Snapshot,
    nonce: bigint,
    signature: Buffer,
    overrides: Partial<{
      schema: bigint;
      domain: string;
      network: string;
      chainId: bigint;
      epoch: bigint;
      balance: bigint;
      supply: bigint;
      backing: bigint;
      height: bigint;
      expiresAt: bigint;
    }> = {},
  ) => simnet.callPublicFn(CONTRACT, 'submit-attestation', [
    token,
    Cl.uint(overrides.schema ?? SCHEMA),
    Cl.stringAscii(overrides.domain ?? DOMAIN),
    Cl.stringAscii(overrides.network ?? NETWORK),
    Cl.uint(overrides.chainId ?? CHAIN_ID),
    Cl.uint(overrides.epoch ?? snapshot.epoch),
    Cl.uint(overrides.balance ?? snapshot.balance),
    Cl.uint(overrides.supply ?? snapshot.supply),
    Cl.uint(overrides.backing ?? snapshot.backing),
    Cl.uint(overrides.height ?? snapshot.height),
    Cl.uint(overrides.expiresAt ?? snapshot.expiresAt),
    Cl.uint(nonce),
    Cl.buffer(signature),
  ], attestor.principal).result;

  const validSignature = (attestor: Attestor, snapshot: Snapshot, nonce: bigint): Buffer => {
    const digest = snapshotDigest(snapshot);
    return sign(attestor.key, envelopeDigest(digest, attestor, nonce));
  };

  it('configures authoritative registries and starts fail closed', () => {
    expect(simnet.callPublicFn(CONTRACT, 'set-network-id', [Cl.stringAscii(NETWORK)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'set-chain-id', [Cl.uint(CHAIN_ID)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'set-asset', [token, Cl.buffer(assetIdentity)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    for (const attestor of attestors) {
      expect(simnet.callPublicFn(CONTRACT, 'set-attestor', [
        Cl.principal(attestor.principal),
        Cl.buffer(attestor.publicKey),
      ], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    }

    expect(simnet.callPublicFn(CONTRACT, 'set-attestor', [
      Cl.principal(attestors[2].principal),
      Cl.buffer(attestors[0].publicKey),
    ], deployer).result).toEqual(Cl.error(Cl.uint(8014)));
    expect(simnet.callPublicFn(CONTRACT, 'set-network-id', [Cl.stringAscii('testnet')], attestors[2].principal).result)
      .toEqual(Cl.error(Cl.uint(8000)));

    expect(config().chainId).toBe(CHAIN_ID);
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(false)));
  });

  it('rejects malformed, wrong-key, altered, unsupported, stale, expired, and unreconciled evidence', () => {
    simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(400), porPrincipal], deployer);
    simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(600), Cl.principal(deployer)], deployer);

    const now = currentHeight();
    const snapshot: Snapshot = { epoch: config().epoch, balance: 400n, supply: 1000n, backing: 600n, height: now, expiresAt: now + 100n };
    const nonce = 100n;
    const signature = validSignature(attestors[0], snapshot, nonce);
    const randomSignature = Buffer.alloc(65, 0x7f);
    const wrongKey = ec.genKeyPair();

    const malformedLength = submit(attestors[0], snapshot, nonce, Buffer.alloc(64));
    expect(Cl.prettyPrint(malformedLength)).not.toMatch(/^\(ok /);
    expect(submit(attestors[0], snapshot, nonce, randomSignature)).toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    expect(submit(attestors[0], snapshot, nonce, sign(wrongKey, envelopeDigest(snapshotDigest(snapshot), attestors[0], nonce))))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    expect(submit(attestors[0], snapshot, nonce, signature, { backing: 601n }))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    expect(submit(attestors[0], snapshot, nonce, signature, { schema: 2n }))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_SCHEMA)));
    expect(submit(attestors[0], snapshot, nonce, signature, { domain: 'CONXIAN-POR-OTHER' }))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_DOMAIN)));
    expect(submit(attestors[0], snapshot, nonce, signature, { network: 'testnet' }))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_NETWORK)));
    expect(submit(attestors[0], snapshot, nonce, signature, { chainId: CHAIN_ID + 1n }))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_CHAIN)));
    expect(submit(attestors[0], snapshot, nonce, signature, { height: now + 1n }))
      .toEqual(Cl.error(Cl.uint(ERR_FUTURE_SNAPSHOT)));
    expect(submit(attestors[0], snapshot, nonce, signature, { expiresAt: now }))
      .toEqual(Cl.error(Cl.uint(ERR_EXPIRED_SNAPSHOT)));
    expect(submit(attestors[0], snapshot, nonce, signature, { balance: 401n }))
      .toEqual(Cl.error(Cl.uint(ERR_LIVE_STATE_MISMATCH)));
    expect(submit(attestors[0], snapshot, nonce, signature, { supply: 999n }))
      .toEqual(Cl.error(Cl.uint(ERR_LIVE_STATE_MISMATCH)));
    expect(submit(attestors[0], snapshot, nonce, signature, { backing: 599n }))
      .toEqual(Cl.error(Cl.uint(ERR_UNBACKED_SNAPSHOT)));

    simnet.mineEmptyBlocks(1009);
    const staleNow = currentHeight();
    const stale = { ...snapshot, height: staleNow - 1009n, expiresAt: staleNow + 1n };
    expect(submit(attestors[0], stale, nonce, validSignature(attestors[0], stale, nonce)))
      .toEqual(Cl.error(Cl.uint(ERR_STALE_SNAPSHOT)));
  });

  it('isolates quorum by snapshot and counts each registered identity once', () => {
    const now = currentHeight();
    const epoch = config().epoch;
    const snapshotA: Snapshot = { epoch, balance: 400n, supply: 1000n, backing: 600n, height: now, expiresAt: now + 100n };
    const snapshotB: Snapshot = { ...snapshotA, backing: 650n };

    expect(submit(attestors[0], snapshotA, 1n, validSignature(attestors[0], snapshotA, 1n))).toEqual(Cl.ok(Cl.bool(false)));
    expect(submit(attestors[1], snapshotA, 1n, validSignature(attestors[1], snapshotA, 1n))).toEqual(Cl.ok(Cl.bool(false)));
    expect(submit(attestors[2], snapshotB, 1n, validSignature(attestors[2], snapshotB, 1n))).toEqual(Cl.ok(Cl.bool(false)));

    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(false)));

    expect(submit(attestors[0], snapshotA, 2n, validSignature(attestors[0], snapshotA, 2n)))
      .toEqual(Cl.error(Cl.uint(ERR_DUPLICATE_ATTESTATION)));
    expect(submit(attestors[0], snapshotB, 1n, validSignature(attestors[0], snapshotB, 1n)))
      .toEqual(Cl.error(Cl.uint(ERR_REPLAYED_NONCE)));

    expect(submit(attestors[2], snapshotA, 2n, validSignature(attestors[2], snapshotA, 2n))).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it('promotes only newer quorum snapshots and fails closed after live state drift and expiry', () => {
    simnet.mineEmptyBlocks(1);
    const newerHeight = currentHeight();
    const epoch = config().epoch;
    const newer: Snapshot = { epoch, balance: 400n, supply: 1000n, backing: 700n, height: newerHeight, expiresAt: newerHeight + 20n };
    const newerDigest = snapshotDigest(newer);

    for (let i = 0; i < attestors.length; i += 1) {
      const nonce = 20n + BigInt(i);
      const expected = i === 2 ? Cl.ok(Cl.bool(true)) : Cl.ok(Cl.bool(false));
      expect(submit(attestors[i], newer, nonce, validSignature(attestors[i], newer, nonce))).toEqual(expected);
    }

    const older: Snapshot = { ...newer, backing: 701n, height: newerHeight - 1n };
    for (let i = 0; i < attestors.length; i += 1) {
      const nonce = 30n + BigInt(i);
      expect(submit(attestors[i], older, nonce, validSignature(attestors[i], older, nonce))).toEqual(Cl.ok(Cl.bool(false)));
    }

    const accepted = simnet.callReadOnlyFn(CONTRACT, 'get-accepted-reserve', [Cl.contractPrincipal(deployer, TOKEN)], deployer).result as any;
    expect(unwrapBuffer(accepted.value.value['snapshot-digest'])).toEqual(newerDigest);

    simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(1), Cl.principal(deployer)], deployer);
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(false)));

    simnet.mineEmptyBlocks(21);
    const status = simnet.callPublicFn(CONTRACT, 'get-proof-status', [token], deployer).result as any;
    expect(status.value.value['fully-backed']).toEqual(Cl.bool(false));
    expect(status.value.value['is-stale']).toEqual(Cl.bool(true));
  });

  it('contains a source guard against legacy raw-attestation authority', () => {
    const source = readFileSync('contracts/security/proof-of-reserves.clar', 'utf8');
    expect(source).toContain('(secp256k1-verify envelope-digest signature');
    expect(source).toContain('(define-map accepted-reserves');
    expect(source).not.toContain('(define-public (sync-on-chain-balance');
    expect(source).not.toMatch(/define-map attestations[\s\S]*signature:/);
    expect(source).not.toMatch(/off-chain-backing:\s*off-chain-amount/);
  });
});
