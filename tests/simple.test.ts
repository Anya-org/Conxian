import { describe, expect, it } from 'vitest';
import { simnet } from './setup-test-env';

describe('Simple Test', () => {
  it('should load conxian-access', () => {
    const deployer = simnet.deployer;
    const owner = simnet.callReadOnlyFn(
      'conxian-access',
      'get-contract-owner',
      [],
      deployer
    );
    expect(owner.result).toBeDefined();
  });
});
