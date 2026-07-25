import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const ZKML_VERIFIER = 'zkml-verifier';
const VERIFIER_UNAVAILABLE = 503;
const DEPLOYER = () => simnet.getAccounts().get('deployer')!;
const INPUT_HASH_A = Cl.buffer(Buffer.alloc(32, 0x11));
const INPUT_HASH_B = Cl.buffer(Buffer.from('candidate-input-mutated'.padEnd(32, '0')));
const MODEL_ID_A = Cl.stringAscii('risk-model-v1');
const MODEL_ID_B = Cl.stringAscii('candidate-model-mutated');

/*
* These labels are quarantine-category regressions only. The current ABI has
* model-id, input-hash, and proof fields but no key, curve, circuit,
* freshness/replay, or backend fields. The tests must therefore prove that
* the scaffold remains unavailable without implying that it parses evidence.
*/
const candidateProof = (marker: string) =>
  Cl.buffer(Buffer.from(`candidate:${marker}`));

function callVerify(
  modelId: ReturnType<typeof Cl.stringAscii>,
  inputHash: ReturnType<typeof Cl.buffer>,
  proof: ReturnType<typeof Cl.buffer>,
) {
  return simnet.callPublicFn(
    ZKML_VERIFIER,
    'verify-proof',
    [modelId, inputHash, proof],
    DEPLOYER(),
  );
}

function expectUnavailable(result: { result: unknown; events: unknown[] }) {
  expect(result.result).toEqual(Cl.error(Cl.uint(VERIFIER_UNAVAILABLE)));
  expect(result.events).toHaveLength(0);
}

describe('zkml-verifier quarantine', () => {
  it('rejects a malformed-length candidate instead of treating length as verification', () => {
    const result = callVerify(MODEL_ID_A, INPUT_HASH_A, Cl.buffer(Buffer.alloc(1024, 0xaa)));

    expectUnavailable(result);
  });

  it('rejects malformed-encoding candidates', () => {
    const payloads = [
      Cl.buffer(Buffer.from([0xde, 0xad, 0xbe, 0xef])),
      Cl.buffer(Buffer.alloc(1024, 0x00)),
      candidateProof('malformed-encoding'),
    ];

    for (const proof of payloads) {
      expectUnavailable(callVerify(MODEL_ID_A, INPUT_HASH_A, proof));
    }
  });

  it('rejects a wrong-key candidate marker', () => {
    expectUnavailable(
      callVerify(MODEL_ID_A, INPUT_HASH_A, candidateProof('wrong-key')),
    );
  });

  it('rejects a mutated-proof candidate marker', () => {
    expectUnavailable(
      callVerify(MODEL_ID_A, INPUT_HASH_A, candidateProof('mutated-proof')),
    );
  });

  it('rejects mutated-model and mutated-input candidate markers', () => {
    const proof = Cl.buffer(Buffer.alloc(1024, 0x42));
    const results = [
      callVerify(MODEL_ID_A, INPUT_HASH_A, proof),
      callVerify(MODEL_ID_B, INPUT_HASH_A, proof),
      callVerify(MODEL_ID_A, INPUT_HASH_B, proof),
      callVerify(MODEL_ID_B, INPUT_HASH_B, proof),
    ];

    for (const result of results) {
      expectUnavailable(result);
    }
  });

  it('rejects a curve-mismatch candidate marker', () => {
    expectUnavailable(
      callVerify(MODEL_ID_A, INPUT_HASH_A, candidateProof('curve-mismatch')),
    );
  });

  it('rejects a circuit-key-mismatch candidate marker', () => {
    expectUnavailable(
      callVerify(MODEL_ID_A, INPUT_HASH_A, candidateProof('circuit-key-mismatch')),
    );
  });

  it('rejects a replay/stale-evidence candidate marker', () => {
    expectUnavailable(
      callVerify(MODEL_ID_A, INPUT_HASH_A, candidateProof('replay-stale-evidence')),
    );
  });

  it('rejects an unsupported-backend candidate marker', () => {
    expectUnavailable(
      callVerify(MODEL_ID_A, INPUT_HASH_A, candidateProof('unsupported-backend')),
    );
  });

  it('emits no success-shaped zkml-verified event', () => {
    const result = callVerify(MODEL_ID_A, INPUT_HASH_A, Cl.buffer(Buffer.alloc(1024, 0x7f)));

    expectUnavailable(result);
    expect(result.events.some((event: unknown) => JSON.stringify(event).includes('zkml-verified'))).toBe(false);
  });

  it('reports unavailable status rather than active or compliant status', () => {
    const result = simnet.callReadOnlyFn(ZKML_VERIFIER, 'get-protocol-status', [], DEPLOYER());

    expect(result.result).toEqual(Cl.error(Cl.uint(VERIFIER_UNAVAILABLE)));
  });
});
