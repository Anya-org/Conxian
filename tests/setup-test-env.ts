import { beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let internalSimnet: Simnet | null = null;
let initializationPromise: Promise<Simnet> | null = null;

export async function initializeSimnet(): Promise<Simnet> {
  if (internalSimnet) return internalSimnet;
  if (initializationPromise) return initializationPromise;

  initializationPromise = (async () => {
    try {
      console.log('🚀 Initializing Simnet and Bootstrapping Protocol...');
      const instance = await initSimnet('Clarinet.toml');
      internalSimnet = instance;

      const deployer = instance.deployer;

      const contractsToInit = [
        'conxian-protocol',
        'conxian-access',
        'oracle-aggregator',
        'finance-metrics',
        'agent-risk',
        'dex-factory',
        'federated-oracle-adapter',
        'lending-manager',
        'bme-engine',
        'office-manager',
        'operational-treasury',
        'agent-treasury',
        'cxd-token',
        'mock-token'
      ];

      for (const name of contractsToInit) {
        try {
          const res = instance.callPublicFn(name, 'initialize', [Cl.principal(deployer)], deployer);
          // console.log(`Init ${name}: ${Cl.prettyPrint(res.result)}`);
        } catch (e) {
          // console.log(`Skip init ${name}`);
        }
      }

      // Configure Operational Treasury for Office Manager
      try {
        instance.callPublicFn('operational-treasury', 'set-protocol-principal', [Cl.stringAscii('office-manager-owner'), Cl.principal(deployer)], deployer);
      } catch (e) {}

      // Authorize reporters in BME Engine
      try {
        instance.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.contractPrincipal(deployer, 'swap-router')], deployer);
        instance.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.contractPrincipal(deployer, 'lending-manager')], deployer);
      } catch (e) {}

      console.log('✅ Bootstrap Complete');
      return instance;
    } catch (error) {
      console.error('❌ Simnet initialization failed:', error);
      initializationPromise = null;
      throw error;
    }
  })();

  return initializationPromise;
}

export const simnet: Simnet = new Proxy({} as Simnet, {
  get: (_target, prop) => {
    const value = (internalSimnet as any)?.[prop];
    if (typeof value === 'function') {
      return value.bind(internalSimnet);
    }
    return value;
  }
});

beforeAll(async () => {
  await initializeSimnet();
});
