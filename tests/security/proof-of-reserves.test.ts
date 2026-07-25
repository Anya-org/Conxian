import { createHash } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { ec as EC } from 'elliptic';

const CONTRACT = 'proof-of-reserves';
const TOKEN = 'mock-token';
const ALTERNATE_TOKEN = 'cxd-token';
const SCHEMA = 1n;
const DOMAIN = 'CONXIAN-POR-SNAPSHOT';
const ALGORITHM = 'secp256k1';
const NETWORK = 'simnet';
const CHAIN_ID = 2_147_483_648n;

const ERR_UNAUTHORIZED = 8000;
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
const ERR_INVALID_ATTESTOR = 8014;
const ERR_INVALID_ASSET = 8016;
const ERR_UNSUPPORTED_SIGNATURE_ALGORITHM = 8017;

const ec = new EC('secp256k1');
const PRIVATE_KEYS = [
  '0000000000000000000000000000000000000000000000000000000000000001',
  '0000000000000000000000000000000000000000000000000000000000000002',
  '0000000000000000000000000000000000000000000000000000000000000003',
  '0000000000000000000000000000000000000000000000000000000000000004',
];

type Attestor = { principal: string; key: EC.KeyPair; publicKey: Buffer; identity: Buffer };
type Snapshot = { epoch: bigint; balance: bigint; supply: bigint; backing: bigint; height: bigint; expiresAt: bigint };
type SubmitOverrides = Partial<{
  tokenName: string; schema: bigint; domain: string; algorithm: string; network: string; chainId: bigint;
  epoch: bigint; balance: bigint; supply: bigint; backing: bigint; height: bigint; expiresAt: bigint;
}>;

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

// Each test receives a fresh simnet. No scenario inherits registry, nonce,
// token, candidate, or accepted-proof state from an unrelated test. Fixed
// private keys keep signatures deterministic across isolated instances.
describe('proof-of-reserves cryptographic snapshot binding', () => {
  let simnet: Simnet;
  let deployer: string;
  let token: ReturnType<typeof Cl.contractPrincipal>;
  let porPrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let assetIdentity: Buffer;
  let alternateAssetIdentity: Buffer;
  let attestors: Attestor[];

  const resetSimnet = async (): Promise<void> => {
    simnet = await initSimnet('Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    const principals = ['wallet_1', 'wallet_2', 'wallet_3'].map((name) => accounts.get(name)!);
    principals.push(deployer);
    token = Cl.contractPrincipal(deployer, TOKEN);
    porPrincipal = Cl.contractPrincipal(deployer, CONTRACT);
    assetIdentity = createHash('sha256').update(`${deployer}.${TOKEN}`).digest();
    alternateAssetIdentity = createHash('sha256').update(`${deployer}.${ALTERNATE_TOKEN}`).digest();
    attestors = principals.map((principal, index) => {
      const key = ec.keyFromPrivate(PRIVATE_KEYS[index], 'hex');
      const publicKey = Buffer.from(key.getPublic(true, 'array'));
      return { principal, key, publicKey, identity: createHash('sha256').update(publicKey).digest() };
    });
  };

  beforeEach(resetSimnet);

  const currentHeight = (): bigint => BigInt(simnet.mineEmptyBlocks(0));
  const config = (): { epoch: bigint; chainId: bigint; algorithm: string } => {
    const result = simnet.callReadOnlyFn(CONTRACT, 'get-domain-config', [], deployer).result as any;
    return {
      epoch: BigInt(tupleValue(result, 'registry-epoch')),
      chainId: BigInt(tupleValue(result, 'chain-id')),
      algorithm: tupleValue(result, 'signature-algorithm'),
    };
  };
  const configure = (count = 3, includeAlternateAsset = false): void => {
    expect(simnet.callPublicFn(CONTRACT, 'set-network-id', [Cl.stringAscii(NETWORK)], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'set-chain-id', [Cl.uint(CHAIN_ID)], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'set-asset', [token, Cl.buffer(assetIdentity)], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    if (includeAlternateAsset) {
      expect(simnet.callPublicFn(CONTRACT, 'set-asset', [
        Cl.contractPrincipal(deployer, ALTERNATE_TOKEN), Cl.buffer(alternateAssetIdentity),
      ], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    }
    for (const attestor of attestors.slice(0, count)) {
      expect(simnet.callPublicFn(CONTRACT, 'set-attestor', [Cl.principal(attestor.principal), Cl.buffer(attestor.publicKey)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
    }
  };
  const mintBackingState = (): void => {
    expect(simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(400), porPrincipal], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(600), Cl.principal(deployer)], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
  };
  const makeSnapshot = (overrides: Partial<Snapshot> = {}): Snapshot => {
    const now = currentHeight();
    return { epoch: config().epoch, balance: 400n, supply: 1000n, backing: 600n, height: now, expiresAt: now + 100n, ...overrides };
  };
  const snapshotDigest = (snapshot: Snapshot, overrides: Partial<{
    schema: bigint; domain: string; network: string; chainId: bigint; epoch: bigint; assetIdentity: Buffer;
    balance: bigint; supply: bigint; backing: bigint; height: bigint; expiresAt: bigint;
  }> = {}): Buffer => unwrapBuffer(simnet.callReadOnlyFn(CONTRACT, 'get-snapshot-digest', [
    Cl.uint(overrides.schema ?? SCHEMA), Cl.stringAscii(overrides.domain ?? DOMAIN),
    Cl.stringAscii(overrides.network ?? NETWORK), Cl.uint(overrides.chainId ?? CHAIN_ID),
    Cl.uint(overrides.epoch ?? snapshot.epoch), Cl.buffer(overrides.assetIdentity ?? assetIdentity),
    Cl.uint(overrides.balance ?? snapshot.balance), Cl.uint(overrides.supply ?? snapshot.supply),
    Cl.uint(overrides.backing ?? snapshot.backing), Cl.uint(overrides.height ?? snapshot.height),
    Cl.uint(overrides.expiresAt ?? snapshot.expiresAt),
  ], deployer).result);
  const envelopeDigest = (digest: Buffer, attestor: Attestor, nonce: bigint, overrides: Partial<{
    schema: bigint; algorithm: string; identity: Buffer;
  }> = {}): Buffer => unwrapBuffer(simnet.callReadOnlyFn(CONTRACT, 'get-attestation-digest', [
    Cl.uint(overrides.schema ?? SCHEMA), Cl.stringAscii(overrides.algorithm ?? ALGORITHM), Cl.buffer(digest),
    Cl.buffer(overrides.identity ?? attestor.identity), Cl.uint(nonce),
  ], deployer).result);
  const validSignature = (attestor: Attestor, snapshot: Snapshot, nonce: bigint): Buffer =>
    sign(attestor.key, envelopeDigest(snapshotDigest(snapshot), attestor, nonce));
  const submit = (attestor: Attestor, snapshot: Snapshot, nonce: bigint, signature: Buffer, overrides: SubmitOverrides = {}) =>
    simnet.callPublicFn(CONTRACT, 'submit-attestation', [
      Cl.contractPrincipal(deployer, overrides.tokenName ?? TOKEN), Cl.uint(overrides.schema ?? SCHEMA),
      Cl.stringAscii(overrides.domain ?? DOMAIN), Cl.stringAscii(overrides.algorithm ?? ALGORITHM),
      Cl.stringAscii(overrides.network ?? NETWORK), Cl.uint(overrides.chainId ?? CHAIN_ID),
      Cl.uint(overrides.epoch ?? snapshot.epoch), Cl.uint(overrides.balance ?? snapshot.balance),
      Cl.uint(overrides.supply ?? snapshot.supply), Cl.uint(overrides.backing ?? snapshot.backing),
      Cl.uint(overrides.height ?? snapshot.height), Cl.uint(overrides.expiresAt ?? snapshot.expiresAt),
      Cl.uint(nonce), Cl.buffer(signature),
    ], attestor.principal).result;
  const proofState = (snapshot: Snapshot, attestor: Attestor): unknown => {
    const digest = snapshotDigest(snapshot);
    return {
      candidate: simnet.callReadOnlyFn(CONTRACT, 'get-snapshot-candidate', [token, Cl.buffer(digest)], deployer).result,
      attestation: simnet.callReadOnlyFn(CONTRACT, 'get-attestation', [
        token, Cl.buffer(digest), Cl.principal(attestor.principal),
      ], deployer).result,
      accepted: simnet.callReadOnlyFn(CONTRACT, 'get-accepted-reserve', [token], deployer).result,
      status: simnet.callPublicFn(CONTRACT, 'get-proof-status', [token], deployer).result,
    };
  };
  const acceptSnapshot = (snapshot: Snapshot): void => {
    for (let index = 0; index < 3; index += 1) {
      const nonce = BigInt(index + 1);
      expect(submit(attestors[index], snapshot, nonce, validSignature(attestors[index], snapshot, nonce)))
        .toEqual(Cl.ok(Cl.bool(index === 2)));
    }
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  it('binds every valid mutable snapshot and signer-envelope field to a distinct digest', () => {
    configure();
    mintBackingState();
    const snapshot = makeSnapshot();
    const common = snapshotDigest(snapshot);
    const alternateIdentity = createHash('sha256').update('alternate-asset').digest();
    const mutations: Array<[string, Parameters<typeof snapshotDigest>[1]]> = [
      ['asset identity', { assetIdentity: alternateIdentity }],
      ['live balance', { balance: snapshot.balance + 1n }], ['total supply', { supply: snapshot.supply + 1n }],
      ['off-chain backing', { backing: snapshot.backing + 1n }], ['snapshot height', { height: snapshot.height + 1n }],
      ['expiry', { expiresAt: snapshot.expiresAt + 1n }],
    ];
    for (const [field, mutation] of mutations) expect(snapshotDigest(snapshot, mutation), field).not.toEqual(common);

    const envelope = envelopeDigest(common, attestors[0], 7n);
    expect(envelopeDigest(common, attestors[0], 7n, { identity: attestors[1].identity }), 'signer identity').not.toEqual(envelope);
    expect(envelopeDigest(common, attestors[0], 8n), 'nonce').not.toEqual(envelope);
    expect(config().algorithm).toBe(ALGORITHM);
  });

  it('rejects invalid or inconsistent public digest helper inputs', () => {
    const unconfigured = makeSnapshot();
    expect(simnet.callReadOnlyFn(CONTRACT, 'get-snapshot-digest', [
      Cl.uint(SCHEMA), Cl.stringAscii(DOMAIN), Cl.stringAscii(NETWORK), Cl.uint(CHAIN_ID), Cl.uint(unconfigured.epoch),
      Cl.buffer(assetIdentity), Cl.uint(0), Cl.uint(0), Cl.uint(0), Cl.uint(0), Cl.uint(1),
    ], deployer).result).toEqual(Cl.error(Cl.uint(ERR_INVALID_NETWORK)));

    configure();
    mintBackingState();
    const snapshot = makeSnapshot();
    const snapshotArgs = (overrides: Parameters<typeof snapshotDigest>[1]) => simnet.callReadOnlyFn(CONTRACT, 'get-snapshot-digest', [
      Cl.uint(overrides.schema ?? SCHEMA), Cl.stringAscii(overrides.domain ?? DOMAIN),
      Cl.stringAscii(overrides.network ?? NETWORK), Cl.uint(overrides.chainId ?? CHAIN_ID),
      Cl.uint(overrides.epoch ?? snapshot.epoch), Cl.buffer(assetIdentity), Cl.uint(snapshot.balance), Cl.uint(snapshot.supply),
      Cl.uint(snapshot.backing), Cl.uint(snapshot.height), Cl.uint(snapshot.expiresAt),
    ], deployer).result;
    expect(snapshotArgs({ schema: 999n })).toEqual(Cl.error(Cl.uint(ERR_INVALID_SCHEMA)));
    expect(snapshotArgs({ domain: 'ARBITRARY-DOMAIN' })).toEqual(Cl.error(Cl.uint(ERR_INVALID_DOMAIN)));
    expect(snapshotArgs({ network: 'invalid' })).toEqual(Cl.error(Cl.uint(ERR_INVALID_NETWORK)));
    expect(snapshotArgs({ network: 'testnet' })).toEqual(Cl.error(Cl.uint(ERR_INVALID_NETWORK)));
    expect(snapshotArgs({ chainId: CHAIN_ID + 99n })).toEqual(Cl.error(Cl.uint(ERR_INVALID_CHAIN)));
    expect(snapshotArgs({ epoch: snapshot.epoch + 99n })).toEqual(Cl.error(Cl.uint(ERR_INVALID_ATTESTOR)));

    const digest = snapshotDigest(snapshot);
    expect(simnet.callReadOnlyFn(CONTRACT, 'get-attestation-digest', [
      Cl.uint(999), Cl.stringAscii(ALGORITHM), Cl.buffer(digest), Cl.buffer(attestors[0].identity), Cl.uint(1),
    ], deployer).result).toEqual(Cl.error(Cl.uint(ERR_INVALID_SCHEMA)));
    expect(simnet.callReadOnlyFn(CONTRACT, 'get-attestation-digest', [
      Cl.uint(SCHEMA), Cl.stringAscii('arbitrary'), Cl.buffer(digest), Cl.buffer(attestors[0].identity), Cl.uint(1),
    ], deployer).result).toEqual(Cl.error(Cl.uint(ERR_UNSUPPORTED_SIGNATURE_ALGORITHM)));
  });

  it('rejects semantic mismatches, admissible mutations, token substitution, and failed-write contamination', () => {
    configure(3, true);
    mintBackingState();
    const snapshot = makeSnapshot();
    const nonce = 100n;
    const signature = validSignature(attestors[0], snapshot, nonce);
    const semanticCases: Array<[string, SubmitOverrides, number]> = [
      ['schema', { schema: 2n }, ERR_INVALID_SCHEMA], ['domain', { domain: 'CONXIAN-POR-OTHER' }, ERR_INVALID_DOMAIN],
      ['algorithm', { algorithm: 'secp256r1' }, ERR_UNSUPPORTED_SIGNATURE_ALGORITHM],
      ['network', { network: 'testnet' }, ERR_INVALID_NETWORK], ['chain', { chainId: CHAIN_ID + 1n }, ERR_INVALID_CHAIN],
      ['registry epoch', { epoch: snapshot.epoch + 1n }, ERR_INVALID_ATTESTOR],
      ['live balance', { balance: 401n }, ERR_LIVE_STATE_MISMATCH], ['total supply', { supply: 999n }, ERR_LIVE_STATE_MISMATCH],
      ['future height', { height: snapshot.height + 1n }, ERR_FUTURE_SNAPSHOT],
      ['expired', { expiresAt: snapshot.height }, ERR_EXPIRED_SNAPSHOT], ['unbacked', { backing: 599n }, ERR_UNBACKED_SNAPSHOT],
    ];
    for (const [field, overrides, error] of semanticCases) {
      expect(submit(attestors[0], snapshot, nonce, signature, overrides), field).toEqual(Cl.error(Cl.uint(error)));
    }
    const malformedLength = submit(attestors[0], snapshot, nonce, Buffer.alloc(64));
    expect(Cl.prettyPrint(malformedLength)).not.toMatch(/^\(ok /);
    expect(submit(attestors[0], snapshot, nonce, Buffer.alloc(65, 0x7f))).toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    const wrongKey = ec.keyFromPrivate(PRIVATE_KEYS[3], 'hex');
    expect(submit(attestors[0], snapshot, nonce, sign(wrongKey, envelopeDigest(snapshotDigest(snapshot), attestors[0], nonce))))
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));

    const altered = { ...snapshot, backing: 601n };
    const alteredDigest = snapshotDigest(altered);
    expect(submit(attestors[0], snapshot, nonce, signature, { backing: 601n })).toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    expect(simnet.callReadOnlyFn(CONTRACT, 'get-snapshot-candidate', [token, Cl.buffer(alteredDigest)], deployer).result).toEqual(Cl.none());
    expect(submit(attestors[0], altered, nonce, validSignature(attestors[0], altered, nonce))).toEqual(Cl.ok(Cl.bool(false)));

    const tokenNonce = 101n;
    const tokenSignature = validSignature(attestors[1], snapshot, tokenNonce);
    expect(submit(attestors[1], snapshot, tokenNonce, tokenSignature, {
      tokenName: ALTERNATE_TOKEN, balance: 0n, supply: 0n, backing: 0n,
    })).toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    expect(simnet.callPublicFn(CONTRACT, 'set-asset', [Cl.contractPrincipal(deployer, ALTERNATE_TOKEN), Cl.buffer(assetIdentity)], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_ASSET)));
  });

  it('enforces distinct quorum, replay protection, monotonic promotion, and live fail-closed status', () => {
    configure();
    mintBackingState();
    const snapshot = makeSnapshot();
    const split = { ...snapshot, backing: 650n };
    expect(submit(attestors[0], snapshot, 1n, validSignature(attestors[0], snapshot, 1n))).toEqual(Cl.ok(Cl.bool(false)));
    expect(submit(attestors[1], snapshot, 1n, validSignature(attestors[1], snapshot, 1n))).toEqual(Cl.ok(Cl.bool(false)));
    expect(submit(attestors[2], split, 1n, validSignature(attestors[2], split, 1n))).toEqual(Cl.ok(Cl.bool(false)));
    expect(submit(attestors[0], snapshot, 2n, validSignature(attestors[0], snapshot, 2n))).toEqual(Cl.error(Cl.uint(ERR_DUPLICATE_ATTESTATION)));
    expect(submit(attestors[0], split, 1n, validSignature(attestors[0], split, 1n))).toEqual(Cl.error(Cl.uint(ERR_REPLAYED_NONCE)));
    expect(submit(attestors[2], snapshot, 2n, validSignature(attestors[2], snapshot, 2n))).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(true)));

    simnet.mineEmptyBlocks(1);
    const newerHeight = currentHeight();
    const newer = makeSnapshot({ height: newerHeight, backing: 700n, expiresAt: newerHeight + 20n });
    for (let i = 0; i < 3; i += 1) {
      const nonce = 20n + BigInt(i);
      expect(submit(attestors[i], newer, nonce, validSignature(attestors[i], newer, nonce))).toEqual(Cl.ok(Cl.bool(i === 2)));
    }
    const newerDigest = snapshotDigest(newer);
    const older = { ...newer, height: newer.height - 1n, backing: 701n };
    for (let i = 0; i < 3; i += 1) {
      const nonce = 30n + BigInt(i);
      expect(submit(attestors[i], older, nonce, validSignature(attestors[i], older, nonce))).toEqual(Cl.ok(Cl.bool(false)));
    }
    const accepted = simnet.callReadOnlyFn(CONTRACT, 'get-accepted-reserve', [token], deployer).result as any;
    expect(unwrapBuffer(accepted.value.value['snapshot-digest'])).toEqual(newerDigest);
    simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(1), Cl.principal(deployer)], deployer);
    expect(simnet.callPublicFn(CONTRACT, 'get-reserve-ratio', [token], deployer).result).toEqual(Cl.ok(Cl.uint(0)));
    simnet.mineEmptyBlocks(21);
    const status = simnet.callPublicFn(CONTRACT, 'get-proof-status', [token], deployer).result as any;
    expect(status.value.value['fully-backed']).toEqual(Cl.bool(false));
    expect(status.value.value['is-stale']).toEqual(Cl.bool(true));
  });

  it('invalidates proofs across rotation/removal and recovers only with a fresh epoch quorum', () => {
    configure(4);
    mintBackingState();
    const acceptedSnapshot = makeSnapshot();
    for (let i = 0; i < 3; i += 1) {
      expect(submit(attestors[i], acceptedSnapshot, 1n, validSignature(attestors[i], acceptedSnapshot, 1n)))
        .toEqual(Cl.ok(Cl.bool(i === 2)));
    }
    const oldKey = attestors[0].key;
    const oldPublicKey = attestors[0].publicKey;
    const rotatedKey = ec.keyFromPrivate('0000000000000000000000000000000000000000000000000000000000000005', 'hex');
    const rotatedPublicKey = Buffer.from(rotatedKey.getPublic(true, 'array'));
    attestors[0] = { ...attestors[0], key: rotatedKey, publicKey: rotatedPublicKey, identity: createHash('sha256').update(rotatedPublicKey).digest() };
    expect(simnet.callPublicFn(CONTRACT, 'set-attestor', [Cl.principal(attestors[0].principal), Cl.buffer(rotatedPublicKey)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callPublicFn(CONTRACT, 'set-attestor', [Cl.principal(attestors[0].principal), Cl.buffer(oldPublicKey)], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_ATTESTOR)));

    simnet.mineEmptyBlocks(1);
    const rotatedHeight = currentHeight();
    const rotatedSnapshot = makeSnapshot({ height: rotatedHeight, expiresAt: rotatedHeight + 100n });
    const oldIdentity = createHash('sha256').update(oldPublicKey).digest();
    const oldSignature = sign(oldKey, envelopeDigest(snapshotDigest(rotatedSnapshot), attestors[0], 50n, { identity: oldIdentity }));
    expect(submit(attestors[0], rotatedSnapshot, 50n, oldSignature)).toEqual(Cl.error(Cl.uint(ERR_INVALID_SIGNATURE)));
    for (let i = 0; i < 3; i += 1) {
      const nonce = 60n + BigInt(i);
      expect(submit(attestors[i], rotatedSnapshot, nonce, validSignature(attestors[i], rotatedSnapshot, nonce)))
        .toEqual(Cl.ok(Cl.bool(i === 2)));
    }

    const removedPublicKey = attestors[1].publicKey;
    expect(simnet.callPublicFn(CONTRACT, 'remove-attestor', [Cl.principal(attestors[1].principal)], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callPublicFn(CONTRACT, 'set-attestor', [Cl.principal(attestors[1].principal), Cl.buffer(removedPublicKey)], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_ATTESTOR)));
    simnet.mineEmptyBlocks(1);
    const removedHeight = currentHeight();
    const removedSnapshot = makeSnapshot({ height: removedHeight, expiresAt: removedHeight + 100n });
    expect(submit(attestors[1], removedSnapshot, 70n, validSignature(attestors[1], removedSnapshot, 70n)))
      .toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    for (const [index, nonce] of [[0, 80n], [2, 82n], [3, 83n]] as const) {
      expect(submit(attestors[index], removedSnapshot, nonce, validSignature(attestors[index], removedSnapshot, nonce)))
        .toEqual(Cl.ok(Cl.bool(index === 3)));
    }
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('rejects stale evidence without consuming its nonce', () => {
    configure();
    mintBackingState();
    simnet.mineEmptyBlocks(1009);
    const now = currentHeight();
    const stale = makeSnapshot({ height: now - 1009n, expiresAt: now + 1n });
    expect(submit(attestors[0], stale, 99n, validSignature(attestors[0], stale, 99n))).toEqual(Cl.error(Cl.uint(ERR_STALE_SNAPSHOT)));
    const fresh = makeSnapshot({ height: now, expiresAt: now + 100n });
    expect(submit(attestors[0], fresh, 99n, validSignature(attestors[0], fresh, 99n))).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('keeps all proof state invariant on rejected submissions and preserves each nonce', async () => {
    const cases: Array<[string, (snapshot: Snapshot, nonce: bigint) => unknown]> = [
      ['malformed signature length', (snapshot, nonce) => submit(attestors[0], snapshot, nonce, Buffer.alloc(64))],
      ['random signature', (snapshot, nonce) => submit(attestors[0], snapshot, nonce, Buffer.alloc(65, 0x7f))],
      ['wrong key', (snapshot, nonce) => {
        const wrongKey = ec.keyFromPrivate(PRIVATE_KEYS[3], 'hex');
        return submit(attestors[0], snapshot, nonce, sign(wrongKey, envelopeDigest(snapshotDigest(snapshot), attestors[0], nonce)));
      }],
      ['altered signature', (snapshot, nonce) => {
        const altered = Buffer.from(validSignature(attestors[0], snapshot, nonce));
        altered[10] ^= 0x01;
        return submit(attestors[0], snapshot, nonce, altered);
      }],
      ['semantic rejection', (snapshot, nonce) => submit(
        attestors[0], snapshot, nonce, validSignature(attestors[0], snapshot, nonce), { backing: snapshot.backing - 1n },
      )],
    ];

    for (const [name, reject] of cases) {
      await resetSimnet();
      configure();
      mintBackingState();
      const snapshot = makeSnapshot();
      const nonce = 500n;
      const before = proofState(snapshot, attestors[0]);
      const rejected = reject(snapshot, nonce);
      expect(Cl.prettyPrint(rejected as any), name).not.toMatch(/^\(ok /);
      expect(proofState(snapshot, attestors[0]), `${name} state`).toEqual(before);
      expect(submit(attestors[0], snapshot, nonce, validSignature(attestors[0], snapshot, nonce)), `${name} nonce`)
        .toEqual(Cl.ok(Cl.bool(false)));
    }
  });

  it('preserves valid proof liveness across every supported no-op and rejected nonexistent removal', () => {
    configure();
    mintBackingState();
    const snapshot = makeSnapshot();
    acceptSnapshot(snapshot);
    const epoch = config().epoch;
    const assertProofUnchanged = (): void => {
      expect(config().epoch).toBe(epoch);
      expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(true)));
    };

    const noOps = [
      () => simnet.callPublicFn(CONTRACT, 'set-network-id', [Cl.stringAscii(NETWORK)], deployer).result,
      () => simnet.callPublicFn(CONTRACT, 'set-chain-id', [Cl.uint(CHAIN_ID)], deployer).result,
      () => simnet.callPublicFn(CONTRACT, 'set-asset', [token, Cl.buffer(assetIdentity)], deployer).result,
      ...attestors.slice(0, 3).map((attestor) => () => simnet.callPublicFn(CONTRACT, 'set-attestor', [
        Cl.principal(attestor.principal), Cl.buffer(attestor.publicKey),
      ], deployer).result),
      () => simnet.callPublicFn(CONTRACT, 'set-governance', [Cl.principal(deployer)], deployer).result,
      () => simnet.callPublicFn(CONTRACT, 'set-contract-owner', [Cl.principal(deployer)], deployer).result,
    ];
    for (const noOp of noOps) {
      expect(noOp()).toEqual(Cl.ok(Cl.bool(false)));
      assertProofUnchanged();
    }

    expect(simnet.callPublicFn(CONTRACT, 'remove-attestor', [Cl.principal(porPrincipal.value)], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_ATTESTOR)));
    assertProofUnchanged();
    expect(simnet.callPublicFn(CONTRACT, 'remove-asset', [Cl.contractPrincipal(deployer, ALTERNATE_TOKEN)], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_INVALID_ASSET)));
    assertProofUnchanged();

    expect(simnet.callPublicFn(CONTRACT, 'set-governance', [Cl.principal(attestors[0].principal)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(config().epoch).toBe(epoch + 1n);
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('invalidates a valid proof for every effective registry, configuration, and control change', async () => {
    const changes: Array<[string, () => unknown]> = [
      ['attestor rotation', () => {
        const replacement = ec.keyFromPrivate('0000000000000000000000000000000000000000000000000000000000000005', 'hex');
        return simnet.callPublicFn(CONTRACT, 'set-attestor', [
          Cl.principal(attestors[0].principal), Cl.buffer(Buffer.from(replacement.getPublic(true, 'array'))),
        ], deployer).result;
      }],
      ['attestor removal', () => simnet.callPublicFn(CONTRACT, 'remove-attestor', [Cl.principal(attestors[0].principal)], deployer).result],
      ['asset identity change', () => simnet.callPublicFn(CONTRACT, 'set-asset', [
        token, Cl.buffer(createHash('sha256').update('replacement-asset-identity').digest()),
      ], deployer).result],
      ['asset removal', () => simnet.callPublicFn(CONTRACT, 'remove-asset', [token], deployer).result],
      ['network change', () => simnet.callPublicFn(CONTRACT, 'set-network-id', [Cl.stringAscii('testnet')], deployer).result],
      ['chain change', () => simnet.callPublicFn(CONTRACT, 'set-chain-id', [Cl.uint(CHAIN_ID + 1n)], deployer).result],
      ['governance change', () => simnet.callPublicFn(CONTRACT, 'set-governance', [Cl.principal(attestors[0].principal)], deployer).result],
      ['control transfer', () => simnet.callPublicFn(CONTRACT, 'set-contract-owner', [Cl.principal(attestors[0].principal)], deployer).result],
    ];

    for (const [name, change] of changes) {
      await resetSimnet();
      configure();
      mintBackingState();
      acceptSnapshot(makeSnapshot());
      const epoch = config().epoch;
      expect(change(), name).toEqual(Cl.ok(Cl.bool(true)));
      expect(config().epoch, `${name} epoch`).toBe(epoch + 1n);
      expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result, `${name} proof`)
        .toEqual(Cl.ok(Cl.bool(false)));
    }
  });

  it('atomically transfers all PoR authority and revokes every former-owner control path', () => {
    configure();
    mintBackingState();
    const snapshot = makeSnapshot();
    acceptSnapshot(snapshot);
    const oldEpoch = config().epoch;
    const newOwner = attestors[0].principal;
    expect(simnet.callPublicFn(CONTRACT, 'set-contract-owner', [Cl.principal(newOwner)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(config().epoch).toBe(oldEpoch + 1n);
    expect(simnet.callPublicFn(CONTRACT, 'is-fully-backed', [token], deployer).result).toEqual(Cl.ok(Cl.bool(false)));

    const formerOwnerCalls = [
      simnet.callPublicFn(CONTRACT, 'set-attestor', [Cl.principal(attestors[3].principal), Cl.buffer(attestors[3].publicKey)], deployer).result,
      simnet.callPublicFn(CONTRACT, 'remove-attestor', [Cl.principal(attestors[1].principal)], deployer).result,
      simnet.callPublicFn(CONTRACT, 'set-asset', [Cl.contractPrincipal(deployer, ALTERNATE_TOKEN), Cl.buffer(alternateAssetIdentity)], deployer).result,
      simnet.callPublicFn(CONTRACT, 'remove-asset', [token], deployer).result,
      simnet.callPublicFn(CONTRACT, 'set-network-id', [Cl.stringAscii('testnet')], deployer).result,
      simnet.callPublicFn(CONTRACT, 'set-chain-id', [Cl.uint(CHAIN_ID + 1n)], deployer).result,
      simnet.callPublicFn(CONTRACT, 'set-governance', [Cl.principal(deployer)], deployer).result,
      simnet.callPublicFn(CONTRACT, 'set-contract-owner', [Cl.principal(deployer)], deployer).result,
    ];
    for (const result of formerOwnerCalls) expect(result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(config().epoch).toBe(oldEpoch + 1n);
    expect(simnet.callPublicFn(CONTRACT, 'set-contract-owner', [Cl.principal(newOwner)], newOwner).result)
      .toEqual(Cl.ok(Cl.bool(false)));
    expect(config().epoch).toBe(oldEpoch + 1n);
  });
});
