import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const ZKML_VERIFIER = 'zkml-verifier';
const VERIFICATION_UNSUPPORTED = 501;
const STATUS_UNAVAILABLE = 503;

describe('Quarantined ZKML verifier boundary', () => {
  let deployer: string;

  beforeAll(() => {
    deployer = simnet.getAccounts().get('deployer')!;
  });

  const verifyProof = (modelId: string, inputHash: Buffer, proof: Buffer) => simnet.callPublicFn(
    ZKML_VERIFIER,
    'verify-proof',
    [Cl.stringAscii(modelId), Cl.buffer(inputHash), Cl.buffer(proof)],
    deployer,
  ).result;

  it('rejects an arbitrary 1024-byte payload instead of treating length as verification', () => {
    const result = verifyProof('risk-model-v1', Buffer.alloc(32, 0x11), Buffer.alloc(1024, 0xa5));

    expect(result).toEqual(Cl.error(Cl.uint(VERIFICATION_UNSUPPORTED)));
  });

  it('rejects both short and empty payloads with the unsupported result', () => {
    for (const proof of [Buffer.alloc(1, 0x01), Buffer.alloc(0)]) {
      expect(verifyProof('risk-model-v1', Buffer.alloc(32, 0x22), proof))
        .toEqual(Cl.error(Cl.uint(VERIFICATION_UNSUPPORTED)));
    }
  });

  it('cannot produce success for model or input variations', () => {
    const cases = [
      ['risk-model-v1', Buffer.alloc(32, 0x01)],
      ['different-model', Buffer.alloc(32, 0x02)],
      ['risk-model-v1', Buffer.alloc(32, 0x03)],
    ] as const;

    for (const [modelId, inputHash] of cases) {
      expect(verifyProof(modelId, inputHash, Buffer.alloc(1024, 0x5a)))
        .toEqual(Cl.error(Cl.uint(VERIFICATION_UNSUPPORTED)));
    }
  });

  it('reports the verifier status as unavailable', () => {
    const result = simnet.callReadOnlyFn(ZKML_VERIFIER, 'get-protocol-status', [], deployer);

    expect(result.result).toEqual(Cl.error(Cl.uint(STATUS_UNAVAILABLE)));
  });
});
