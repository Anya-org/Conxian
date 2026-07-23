import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const ZKML_VERIFIER = 'zkml-verifier';
const VERIFIER_UNAVAILABLE = 503;
const DEPLOYER = () => simnet.getAccounts().get('deployer')!;
const INPUT_HASH_A = Cl.buffer(Buffer.alloc(32, 0x11));
const INPUT_HASH_B = Cl.buffer(Buffer.alloc(32, 0xee));
const MODEL_ID_A = Cl.stringAscii('risk-model-v1');
const MODEL_ID_B = Cl.stringAscii('risk-model-mutated');

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
  it('rejects a 1024-byte payload instead of treating length as verification', () => {
    const result = callVerify(MODEL_ID_A, INPUT_HASH_A, Cl.buffer(Buffer.alloc(1024, 0xaa)));

    expectUnavailable(result);
  });

  it('rejects short, malformed, and mutated payloads', () => {
    const payloads = [
      Cl.buffer(Buffer.from([0xde, 0xad, 0xbe, 0xef])),
      Cl.buffer(Buffer.alloc(1024, 0x00)),
      Cl.buffer(Buffer.alloc(1024, 0x01)),
    ];

    for (const proof of payloads) {
      expectUnavailable(callVerify(MODEL_ID_A, INPUT_HASH_A, proof));
    }
  });

  it('cannot be made available by changing the model id or input hash', () => {
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
