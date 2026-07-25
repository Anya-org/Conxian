import { describe, expect, it } from 'vitest';
import { Cl, serializeCV } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import crypto from 'node:crypto';
import { simnet } from '../setup-test-env';

const POR = 'proof-of-reserves';
const TOKEN = 'mock-token';
const ec = new EC('secp256k1');
const err = (code: number) => Cl.error(Cl.uint(code));

describe('proof-of-reserves cryptographic boundary', () => {
  it('binds authoritative state to a distinct-attestor quorum and fails closed', () => {
    const deployer = simnet.deployer;
    const attestors = ['wallet_1', 'wallet_2', 'wallet_3'].map((name) => simnet.getAccounts().get(name)!);
    const keys = attestors.map(() => ec.genKeyPair());
    const porPrincipal = `${deployer}.${POR}`;
    const assetPrincipal = `${deployer}.${TOKEN}`;

    const call = (fn: string, args: any[], sender = deployer) =>
      simnet.callPublicFn(POR, fn, args, sender).result;
    const read = (fn: string, args: any[], sender = deployer) =>
      simnet.callReadOnlyFn(POR, fn, args, sender).result as any;
    const token = () => Cl.contractPrincipal(deployer, TOKEN);
    const digestBytes = (result: any) => {
      const hex = result.value.value as string;
      return Buffer.from(hex.startsWith('0x') ? hex.slice(2) : hex, 'hex');
    };
    const sign = (key: EC.KeyPair, digest: Buffer) => {
      const sig = key.sign(digest, { canonical: true });
      return Buffer.concat([
        Buffer.from(sig.r.toArray('be', 32)),
        Buffer.from(sig.s.toArray('be', 32)),
        Buffer.from([sig.recoveryParam ?? 0]),
      ]);
    };
    const shared = (balance: bigint, supply: bigint, backing: bigint, asOf: bigint, expiry: bigint, nonce: bigint) =>
      digestBytes(read('get-shared-snapshot-digest', [
        Cl.principal(assetPrincipal), Cl.uint(balance), Cl.uint(supply), Cl.uint(backing),
        Cl.uint(asOf), Cl.uint(expiry), Cl.uint(nonce),
      ]));
    const envelope = (snapshot: Buffer, attestor: string) =>
      digestBytes(read('get-attestor-envelope-digest', [Cl.buffer(snapshot), Cl.principal(attestor)]));
    const submit = (index: number, backing: bigint, asOf: bigint, expiry: bigint, nonce: bigint, signature?: Buffer) => {
      const snapshot = shared(500n, 1000n, backing, asOf, expiry, nonce);
      const sig = signature ?? sign(keys[index], envelope(snapshot, attestors[index]));
      return call('submit-attestation', [token(), Cl.uint(backing), Cl.uint(asOf), Cl.uint(expiry), Cl.uint(nonce), Cl.buffer(sig)], attestors[index]);
    };

    for (let i = 0; i < attestors.length; i++) {
      expect(call('add-attestor', [Cl.principal(attestors[i]), Cl.buffer(Buffer.from(keys[i].getPublic(true, 'array')))]))
        .toEqual(Cl.ok(Cl.bool(true)));
    }
    expect(call('set-quorum', [Cl.uint(3)])).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(500), Cl.principal(porPrincipal)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(500), Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    const asOf = BigInt(simnet.burnBlockHeight);
    const expiry = asOf + 100n;

    // Random/mutated signatures and the wrong registered key fail.
    expect(submit(0, 500n, asOf, expiry, 90n, Buffer.alloc(65, 7))).toEqual(err(8001));
    const validForZero = sign(keys[0], envelope(shared(500n, 1000n, 500n, asOf, expiry, 91n), attestors[0]));
    const mutated = Buffer.from(validForZero); mutated[10] ^= 1;
    expect(submit(0, 500n, asOf, expiry, 91n, mutated)).toEqual(err(8001));
    expect(submit(0, 500n, asOf, expiry, 92n,
      sign(keys[1], envelope(shared(500n, 1000n, 500n, asOf, expiry, 92n), attestors[0])))).toEqual(err(8001));

    // Any changed signed field makes the submitted envelope invalid.
    const baseSnapshot = shared(500n, 1000n, 500n, asOf, expiry, 93n);
    const wrongDigests = [
      shared(499n, 1000n, 500n, asOf, expiry, 93n),
      shared(500n, 999n, 500n, asOf, expiry, 93n),
      shared(500n, 1000n, 499n, asOf, expiry, 93n),
      shared(500n, 1000n, 500n, asOf + 1n, expiry, 93n),
      shared(500n, 1000n, 500n, asOf, expiry + 1n, 93n),
      shared(500n, 1000n, 500n, asOf, expiry, 94n),
    ];
    for (const wrong of wrongDigests) {
      expect(submit(0, 500n, asOf, expiry, 93n, sign(keys[0], envelope(wrong, attestors[0])))).toEqual(err(8001));
    }

    // Wrong schema/network/asset/verifier are rejected through canonical serialization.
    const localSnapshot = (overrides: Record<string, any>) => crypto.createHash('sha256').update(Buffer.from(serializeCV(Cl.tuple({
      domain: Cl.stringAscii('CONXIAN_POR_SNAPSHOT_V1'),
      'schema-version': Cl.uint(overrides.schema ?? 1),
      network: Cl.uint(overrides.network ?? 0x80000000),
      'verifying-contract': Cl.principal(overrides.verifier ?? porPrincipal),
      asset: Cl.principal(overrides.asset ?? assetPrincipal),
      'on-chain-balance': Cl.uint(500), 'total-supply': Cl.uint(1000),
      'off-chain-backing': Cl.uint(500), 'as-of-height': Cl.uint(asOf),
      'expiry-height': Cl.uint(expiry), nonce: Cl.uint(95),
    })))).digest();
    for (const wrong of [
      localSnapshot({ schema: 2 }), localSnapshot({ network: 1 }),
      localSnapshot({ asset: porPrincipal }), localSnapshot({ verifier: assetPrincipal }),
    ]) {
      expect(submit(0, 500n, asOf, expiry, 95n, sign(keys[0], envelope(wrong, attestors[0])))).toEqual(err(8001));
    }

    // Future/expired evidence and attestor-bound signature reuse fail.
    expect(submit(0, 500n, asOf + 1n, expiry, 96n)).toEqual(err(8002));
    expect(submit(0, 500n, asOf, asOf, 97n)).toEqual(err(8002));
    expect(submit(1, 500n, asOf, expiry, 98n,
      sign(keys[0], envelope(shared(500n, 1000n, 500n, asOf, expiry, 98n), attestors[0])))).toEqual(err(8001));

    // Same-snapshot distinct signers reach quorum; duplicates cannot inflate it.
    const firstQuorumSubmission: any = submit(0, 500n, asOf, expiry, 1n);
    expect(firstQuorumSubmission.value.value.activated).toEqual(Cl.bool(false));
    expect(submit(0, 500n, asOf, expiry, 1n)).toEqual(err(8003));
    expect((submit(1, 500n, asOf, expiry, 1n) as any).value.value.activated).toEqual(Cl.bool(false));
    expect(call('is-fully-backed', [token()])).toEqual(Cl.ok(Cl.bool(false)));
    expect((submit(2, 500n, asOf, expiry, 1n) as any).value.value.activated).toEqual(Cl.bool(true));
    expect(call('is-fully-backed', [token()])).toEqual(Cl.ok(Cl.bool(true)));
    const activeStatus: any = call('get-proof-status', [token()]);
    expect(activeStatus.value.value['fully-backed']).toEqual(Cl.bool(true));
    expect(activeStatus.value.value['attestation-count']).toEqual(Cl.uint(3));
    expect(read('get-active-snapshot-digest', [Cl.principal(assetPrincipal)]))
      .toEqual(Cl.some(Cl.buffer(shared(500n, 1000n, 500n, asOf, expiry, 1n))));

    // Reusing a nonce for a different snapshot is rejected.
    expect(submit(0, 501n, asOf, expiry, 1n)).toEqual(err(8009));

    // Split/non-quorate candidates do not replace the active snapshot.
    const activeBefore = read('get-active-snapshot-digest', [Cl.principal(assetPrincipal)]);
    expect((submit(0, 600n, asOf, expiry, 2n) as any).value.value.activated).toEqual(Cl.bool(false));
    expect((submit(1, 600n, asOf, expiry, 2n) as any).value.value.activated).toEqual(Cl.bool(false));
    expect(read('get-active-snapshot-digest', [Cl.principal(assetPrincipal)])).toEqual(activeBefore);
    expect((submit(2, 601n, asOf, expiry, 2n) as any).value.value.activated).toEqual(Cl.bool(false));
    expect(read('get-active-snapshot-digest', [Cl.principal(assetPrincipal)])).toEqual(activeBefore);

    // Live state changes and registry changes immediately fail closed.
    expect(simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(1), Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(call('is-fully-backed', [token()])).toEqual(Cl.ok(Cl.bool(false)));
    const supplyDriftStatus: any = call('get-proof-status', [token()]);
    expect(supplyDriftStatus.value.value['live-balance-matches']).toEqual(Cl.bool(true));
    expect(supplyDriftStatus.value.value['live-supply-matches']).toEqual(Cl.bool(false));
    expect(simnet.callPublicFn(TOKEN, 'mint', [Cl.uint(1), Cl.principal(porPrincipal)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const balanceDriftStatus: any = call('get-proof-status', [token()]);
    expect(balanceDriftStatus.value.value['live-balance-matches']).toEqual(Cl.bool(false));
    expect(call('deactivate-attestor', [Cl.principal(attestors[2])])).toEqual(Cl.ok(Cl.bool(true)));
    const deactivatedStatus: any = call('get-proof-status', [token()]);
    expect(deactivatedStatus.value.value['attestation-count']).toEqual(Cl.uint(2));
    expect(call('rotate-attestor-key', [Cl.principal(attestors[2]), Cl.buffer(Buffer.from(ec.genKeyPair().getPublic(true, 'array')))]))
      .toEqual(Cl.ok(Cl.bool(true)));

    // The API type caps signatures at 65 bytes and runtime logic requires exactly 65.
    expect(call('submit-attestation', [token(), Cl.uint(500), Cl.uint(asOf), Cl.uint(expiry), Cl.uint(200), Cl.buffer(Buffer.alloc(64))], attestors[0]))
      .toEqual(err(8014));

    simnet.mineEmptyBurnBlocks(1009);
    const staleAsOf = BigInt(simnet.burnBlockHeight) - 1009n;
    expect(submit(0, 500n, staleAsOf, BigInt(simnet.burnBlockHeight) + 5n, 201n)).toEqual(err(8002));
  });
});
