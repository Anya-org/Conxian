import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { validateIssue501RuntimePlan } from './issue501-plan-validation';

const deploymentPlanPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../deployments/default.simnet-plan.yaml',
);

// Clarinet SDK may rewrite default.simnet-plan.yaml during initSimnet. Keep a
// source snapshot available to tests that validate generator-owned artifacts.
export const canonicalDeploymentPlan = readFileSync(deploymentPlanPath, 'utf8');

let internalSimnet: Simnet | null = null;
let initializationPromise: Promise<Simnet> | null = null;

export async function initializeSimnet(): Promise<Simnet> {
  if (internalSimnet) return internalSimnet;
  if (initializationPromise) return initializationPromise;

  initializationPromise = (async () => {
    try {
      console.log('🚀 Initializing Simnet and Bootstrapping Protocol...');
      const instance = await initSimnet('Clarinet.toml');

      // Validate the SDK-generated plan before restoring the canonical source.
      // This is intentionally limited to issue-501 artifact presence/order:
      // the pinned SDK can emit stale Clarity 1 metadata, while canonical
      // version enforcement remains in the generator and plan regressions.
      validateIssue501RuntimePlan(readFileSync(deploymentPlanPath, 'utf8'));

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

      // Clarinet SDK simnet bootstrapping regenerates the publish plan and
      // does not reliably execute custom emulated post-deploy calls. Keep the
      // canonical fresh-simnet wiring here, using the runtime deployer so no
      // production principal is embedded in the test harness.
      try {
        instance.callPublicFn(
          'operational-treasury',
          'set-protocol-principal',
          [Cl.stringAscii('cxvg-token'), Cl.contractPrincipal(deployer, 'cxvg-token')],
          deployer,
        );
        instance.callPublicFn(
          'operational-treasury',
          'set-protocol-principal',
          [Cl.stringAscii('regulatory-adapter'), Cl.contractPrincipal(deployer, 'regulatory-adapter')],
          deployer,
        );
      } catch (e) {
        // Individual tests assert route availability and fail closed if this
        // bootstrap wiring cannot be applied.
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

      internalSimnet = instance;
      console.log('✅ Bootstrap Complete');
      return instance;
    } catch (error) {
      console.error('❌ Simnet initialization or runtime-plan validation failed:', error);
      initializationPromise = null;
      throw error;
    } finally {
      // initSimnet can rewrite the plan even when initialization or the
      // compatibility gate fails. Always restore the canonical source so a
      // failed setup cannot leave generator-owned artifacts dirty.
      writeFileSync(deploymentPlanPath, canonicalDeploymentPlan);
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

export async function checkDeployments(instance: Simnet) {
    const deployer = instance.deployer;
    const contracts = [
        'conxian-protocol',
        'regulatory-adapter',
        'kyc-registry',
        'bond-factory'
    ];
    for (const name of contracts) {
        const source = instance.getContractSource(name);
        if (!source) {
            console.error(`❌ Contract ${name} not found in simnet`);
        } else {
            console.log(`✅ Contract ${name} is deployed`);
        }
    }
}
