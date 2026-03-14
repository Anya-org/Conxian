
import { describe, expect, it, beforeAll } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Root Recovery: Conxian Protocol', () => {
  let deployer: string;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('should allow the admin to pause and unpause the protocol', () => {
    // Initial state is unpaused
    let paused = simnet.getDataVar('conxian-protocol', 'paused');
    expect(paused).toStrictEqual(Cl.bool(false));

    // Admin (deployer) pauses
    const pauseResponse = simnet.callPublicFn(
      'conxian-protocol',
      'set-paused',
      [Cl.bool(true)],
      deployer
    );
    expect(pauseResponse.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    paused = simnet.getDataVar('conxian-protocol', 'paused');
    expect(paused).toStrictEqual(Cl.bool(true));

    // Admin unpauses
    const unpauseResponse = simnet.callPublicFn(
      'conxian-protocol',
      'set-paused',
      [Cl.bool(false)],
      deployer
    );
    expect(unpauseResponse.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    paused = simnet.getDataVar('conxian-protocol', 'paused');
    expect(paused).toStrictEqual(Cl.bool(false));
  });

  it('should allow registering a module', () => {
    const registerResponse = simnet.callPublicFn(
      'conxian-protocol',
      'register-module',
      [Cl.stringAscii('test-module'), Cl.principal(deployer)],
      deployer
    );
    expect(registerResponse.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    const module = simnet.getMapEntry('conxian-protocol', 'modules', Cl.tuple({ name: Cl.stringAscii('test-module') }));
    expect(module).toStrictEqual(Cl.some(Cl.tuple({
      contract: Cl.principal(deployer),
      active: Cl.bool(true)
    })));
  });

  it('should return protocol status', () => {
    const statusResponse = simnet.callReadOnlyFn(
      'conxian-protocol',
      'get-protocol-status',
      [],
      deployer
    );
    expect(statusResponse.result).toBeDefined();
    const statusStr = Cl.prettyPrint(statusResponse.result);
    expect(statusStr).toContain('compliant: true');
    expect(statusStr).toContain('version: "C4"');
  });
});
