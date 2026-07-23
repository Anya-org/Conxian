import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CONTRACT = 'zkml-verifier';
const ERR_VERIFIER_UNAVAILABLE = 7003;
const ERR_UNAUTHORIZED = 7002;

describe('ZKML verifier quarantine', () => {
  let deployer: string;
  let wallet1: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  const proofWithByte = (value: number): Buffer => Buffer.alloc(1024, value);
  const markedProof = (marker: string): Buffer => {
    const proof = Buffer.alloc(1024);
    Buffer.from(marker, 'ascii').copy(proof);
    return proof;
  };

  const expectUnavailable = (receipt: any) => {
    expect(receipt.result).toEqual(Cl.error(Cl.uint(ERR_VERIFIER_UNAVAILABLE)));
    expect(
      (receipt.events ?? []).some((event: any) =>
        event.event === 'print_event' && JSON.stringify(event).includes('zkml-verified'),
      ),
    ).toBe(false);
  };

  it.each([
    {
      name: 'an arbitrary 1024-byte proof candidate',
      modelId: 'model-arbitrary',
      inputHash: Buffer.alloc(32, 0x11),
      proof: proofWithByte(0xa5),
    },
    {
      name: 'a mutated proof candidate',
      modelId: 'model-arbitrary',
      inputHash: Buffer.alloc(32, 0x11),
      proof: proofWithByte(0xa4),
    },
    {
      name: 'a mutated model identifier',
      modelId: 'model-mutated',
      inputHash: Buffer.alloc(32, 0x11),
      proof: proofWithByte(0xa5),
    },
    {
      name: 'a mutated input hash',
      modelId: 'model-arbitrary',
      inputHash: Buffer.alloc(32, 0x12),
      proof: proofWithByte(0xa5),
    },
    {
      name: 'an empty malformed candidate',
      modelId: 'model-empty',
      inputHash: Buffer.alloc(32, 0x13),
      proof: Buffer.alloc(0),
    },
    {
      name: 'a short 31-byte candidate',
      modelId: 'model-short',
      inputHash: Buffer.alloc(32, 0x14),
      proof: Buffer.alloc(31, 0x14),
    },
    {
      name: 'a candidate encoding standing in for a wrong verification key',
      modelId: 'model-wrong-key',
      inputHash: Buffer.alloc(32, 0x15),
      proof: markedProof('wrong-key'),
    },
    {
      name: 'a candidate encoding standing in for a curve mismatch',
      modelId: 'model-curve-mismatch',
      inputHash: Buffer.alloc(32, 0x16),
      proof: markedProof('curve-mismatch'),
    },
    {
      name: 'a candidate encoding standing in for a circuit or model mismatch',
      modelId: 'model-circuit-mismatch',
      inputHash: Buffer.alloc(32, 0x17),
      proof: markedProof('circuit-mismatch'),
    },
    {
      name: 'a candidate encoding standing in for replay or stale evidence',
      modelId: 'model-replay-stale',
      inputHash: Buffer.alloc(32, 0x18),
      proof: markedProof('replay-stale'),
    },
    {
      name: 'a candidate encoding standing in for an unsupported backend',
      modelId: 'model-unsupported-backend',
      inputHash: Buffer.alloc(32, 0x19),
      proof: markedProof('unsupported-backend'),
    },
  ])('fails closed for $name', ({ modelId, inputHash, proof }) => {
    // The current ABI accepts only model-id, input-hash, and proof. Key,
    // curve, circuit, issuance, freshness, and replay fields are not
    // accepted here; the markers above are only negative-path candidates.
    const receipt = simnet.callPublicFn(
      CONTRACT,
      'verify-proof',
      [Cl.stringAscii(modelId), Cl.buffer(inputHash), Cl.buffer(proof)],
      deployer,
    );

    expectUnavailable(receipt);
  });

  it('reports a non-compliant paused status while the backend is unavailable', () => {
    const status = simnet.callReadOnlyFn(CONTRACT, 'get-protocol-status', [], deployer);
    const statusText = Cl.prettyPrint(status.result);

    expect(status.result).toBeDefined();
    expect(statusText).toContain('compliant: false');
    expect(statusText).toContain('mode: "ZKML-PAUSED"');
    expect(statusText).not.toContain('compliant: true');
    expect(statusText).not.toContain('ZKML-ACTIVE');
  });

  it('preserves admin authorization while the verifier remains quarantined', () => {
    const handoff = simnet.callPublicFn(
      CONTRACT,
      'set-admin',
      [Cl.principal(wallet1)],
      deployer,
    );
    expect(handoff.result).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn(
        CONTRACT,
        'set-admin',
        [Cl.principal(deployer)],
        deployer,
      ).result,
    ).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));

    const restore = simnet.callPublicFn(
      CONTRACT,
      'set-admin',
      [Cl.principal(deployer)],
      wallet1,
    );
    expect(restore.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
