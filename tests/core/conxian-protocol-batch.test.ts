import { describe, it, expect, beforeEach } from 'vitest';
import { Tx, types, Cl } from '@stacks/transactions';
import { initSimnet } from "@stacks/clarinet-sdk";
import { resolve } from "path";

const CONTRACT_NAME = 'conxian-protocol';

describe('Conxian Protocol Batch Tests', () => {
  let simnet: any;
  let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeEach(async () => {
    const manifestPath = resolve(__dirname, '../../Clarinet.toml');
    simnet = await initSimnet(manifestPath);
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('allows the owner to register multiple modules in a batch', () => {
    const modules = [
      { name: Cl.stringAscii('module-1'), contract: Cl.principal(wallet1) },
      { name: Cl.stringAscii('module-2'), contract: Cl.principal(wallet2) },
    ];
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      'batch-register-modules',
      [Cl.list(modules)],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    let moduleInfo = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-module',
      [Cl.stringAscii('module-1')],
      deployer
    );
    expect(moduleInfo.result).toEqual(Cl.some(Cl.tuple({ contract: Cl.principal(wallet1), active: Cl.bool(true) })));

    moduleInfo = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-module',
      [Cl.stringAscii('module-2')],
      deployer
    );
    expect(moduleInfo.result).toEqual(Cl.some(Cl.tuple({ contract: Cl.principal(wallet2), active: Cl.bool(true) })));
  });

  it('allows the owner to set multiple modules active in a batch', () => {
    // First, register the modules
    const modulesToRegister = [
        { name: Cl.stringAscii('module-1'), contract: Cl.principal(wallet1) },
        { name: Cl.stringAscii('module-2'), contract: Cl.principal(wallet2) },
    ];
    simnet.callPublicFn(
        CONTRACT_NAME,
        'batch-register-modules',
        [Cl.list(modulesToRegister)],
        deployer
    );

    const modulesToUpdate = [
      { name: Cl.stringAscii('module-1'), active: Cl.bool(false) },
      { name: Cl.stringAscii('module-2'), active: Cl.bool(false) },
    ];
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      'batch-set-module-active',
      [Cl.list(modulesToUpdate)],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    let moduleInfo = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-module',
      [Cl.stringAscii('module-1')],
      deployer
    );
    expect(moduleInfo.result).toEqual(Cl.some(Cl.tuple({ contract: Cl.principal(wallet1), active: Cl.bool(false) })));

    moduleInfo = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-module',
      [Cl.stringAscii('module-2')],
      deployer
    );
    expect(moduleInfo.result).toEqual(Cl.some(Cl.tuple({ contract: Cl.principal(wallet2), active: Cl.bool(false) })));
  });
});
