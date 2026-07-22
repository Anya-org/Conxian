import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const RISK_UNIT = 'risk-unit';
const RISK_MANAGER = 'risk-manager';
const AGENT_RISK = 'agent-risk';
const FINANCE_METRICS = 'finance-metrics';
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const generatedReleasePlans = [
  'deployments/full-system.testnet-plan.yaml',
  'deployments/full-system.mainnet-plan.yaml',
];

describe('Canonical risk-unit and risk-manager compatibility facade', () => {
  let deployer: string;
  let wallet1: string;
  let riskUnitPrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let riskManagerPrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let agentRiskPrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let dimensionalEnginePrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let opsEnginePrincipal: ReturnType<typeof Cl.contractPrincipal>;
  let metricsPrincipal: ReturnType<typeof Cl.contractPrincipal>;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    riskUnitPrincipal = Cl.contractPrincipal(deployer, RISK_UNIT);
    riskManagerPrincipal = Cl.contractPrincipal(deployer, RISK_MANAGER);
    agentRiskPrincipal = Cl.contractPrincipal(deployer, AGENT_RISK);
    dimensionalEnginePrincipal = Cl.contractPrincipal(deployer, 'dimensional-engine');
    opsEnginePrincipal = Cl.contractPrincipal(deployer, 'ops-engine');
    metricsPrincipal = Cl.contractPrincipal(deployer, FINANCE_METRICS);
  });

  function readRisk(method: string, args: ReturnType<typeof Cl.uint>[] = []) {
    return simnet.callReadOnlyFn(RISK_UNIT, method, args, deployer).result;
  }

  function configureWiring() {
    const unauthorizedOps = simnet.callPublicFn('risk-unit', 'set-ops-engine', [opsEnginePrincipal], wallet1);
    expect(unauthorizedOps.result, 'wallet_1 must not configure risk-unit ops engine').toEqual(Cl.error(Cl.uint(1000)));

    const opsConfigured = simnet.callPublicFn('risk-unit', 'set-ops-engine', [opsEnginePrincipal], deployer);
    expect(opsConfigured.result, 'deployer must configure risk-unit ops engine').toEqual(Cl.ok(Cl.bool(true)));

    const unauthorizedAgentTarget = simnet.callPublicFn(
      AGENT_RISK,
      'set-risk-unit',
      [riskUnitPrincipal],
      wallet1,
    );
    expect(unauthorizedAgentTarget.result, 'wallet_1 must not configure agent-risk').toEqual(Cl.error(Cl.uint(1000)));

    const agentTargetConfigured = simnet.callPublicFn(
      AGENT_RISK,
      'set-risk-unit',
      [riskUnitPrincipal],
      deployer,
    );
    expect(agentTargetConfigured.result, 'deployer must configure agent-risk').toEqual(Cl.ok(Cl.bool(true)));

    const unauthorizedRiskRegistration = simnet.callPublicFn(
      'conxian-protocol',
      'register-module',
      [Cl.stringAscii('risk-unit'), riskUnitPrincipal],
      wallet1,
    );
    expect(unauthorizedRiskRegistration.result, 'wallet_1 must not register protocol modules')
      .toEqual(Cl.error(Cl.uint(1000)));

    const riskRegistration = simnet.callPublicFn(
      'conxian-protocol',
      'register-module',
      [Cl.stringAscii('risk-unit'), riskUnitPrincipal],
      deployer,
    );
    expect(riskRegistration.result, 'deployer must register risk-unit').toEqual(Cl.ok(Cl.bool(true)));

    const facadeRegistration = simnet.callPublicFn(
      'conxian-protocol',
      'register-module',
      [Cl.stringAscii('risk-manager'), riskManagerPrincipal],
      deployer,
    );
    expect(facadeRegistration.result, 'deployer must register risk-manager compatibility key')
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callReadOnlyFn(
      'conxian-protocol',
      'get-module',
      [Cl.stringAscii('risk-unit')],
      deployer,
    ).result).toEqual(Cl.some(Cl.tuple({ contract: riskUnitPrincipal, active: Cl.bool(true) })));
    expect(simnet.callReadOnlyFn(
      'conxian-protocol',
      'get-module',
      [Cl.stringAscii('risk-manager')],
      deployer,
    ).result).toEqual(Cl.some(Cl.tuple({ contract: riskManagerPrincipal, active: Cl.bool(true) })));
    expect(simnet.callReadOnlyFn(AGENT_RISK, 'get-risk-unit', [], deployer).result)
      .toEqual(Cl.ok(Cl.some(riskUnitPrincipal)));

    const config = Cl.prettyPrint(readRisk('get-risk-config'));
    expect(config).toContain('initialized: true');
    expect(config).toContain('agent-risk');
    expect(config).toContain('ops-engine');
  }

  function ensureInitialized() {
    const initialized = Cl.prettyPrint(simnet.getDataVar(RISK_UNIT, 'initialized'));
    if (initialized !== 'true') {
      const result = simnet.callPublicFn(
        RISK_UNIT,
        'initialize',
        [Cl.principal(deployer), Cl.principal(deployer + '.agent-risk'), Cl.principal(deployer + '.dimensional-engine')],
        deployer,
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    }
    configureWiring();
  }

  function mintPosition(positionId: number) {
    const result = simnet.callPublicFn(
      'position-nft',
      'mint',
      [Cl.principal(deployer), Cl.uint(positionId)],
      deployer,
    );
    expect(result.result).toEqual(Cl.ok(Cl.uint(positionId)));
  }

  it('requires trusted bootstrap authorization and rejects reinitialization', () => {
    const args = [
      Cl.principal(deployer),
      Cl.principal(deployer + '.agent-risk'),
      Cl.principal(deployer + '.dimensional-engine'),
    ];
    const unauthorized = simnet.callPublicFn(RISK_UNIT, 'initialize', args, wallet1);
    expect(unauthorized.result).toEqual(Cl.error(Cl.uint(1000)));

    const initialized = simnet.callPublicFn(RISK_UNIT, 'initialize', args, deployer);
    expect(initialized.result).toEqual(Cl.ok(Cl.bool(true)));

    const reinitialized = simnet.callPublicFn(RISK_UNIT, 'initialize', args, deployer);
    expect(reinitialized.result).toEqual(Cl.error(Cl.uint(1000)));
    configureWiring();
  });

  it('keeps health-factor math explicit for zero debt, normal, exact, and below-threshold values', () => {
    ensureInitialized();

    expect(readRisk('calculate-health-factor', [Cl.uint(1000), Cl.uint(0)])).toEqual(Cl.uint(100000));
    expect(readRisk('calculate-health-factor', [Cl.uint(2000), Cl.uint(1000)])).toEqual(Cl.uint(20000));
    expect(readRisk('calculate-health-factor', [Cl.uint(1000), Cl.uint(1000)])).toEqual(Cl.uint(10000));
    expect(readRisk('calculate-health-factor', [Cl.uint(999), Cl.uint(1000)])).toEqual(Cl.uint(9990));
  });

  it('bounds system scores, exposes thresholds, and preserves authorization', () => {
    ensureInitialized();

    expect(simnet.callPublicFn(RISK_UNIT, 'update-system-risk', [Cl.uint(5000)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(RISK_UNIT, 'update-system-risk', [Cl.uint(4999)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const normalThresholdConfig = Cl.prettyPrint(readRisk('get-risk-config'));
    expect(normalThresholdConfig).toContain('active-liquidation-threshold: u10000');

    expect(simnet.callPublicFn(RISK_UNIT, 'update-system-risk', [Cl.uint(5000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(RISK_UNIT, 'update-system-risk', [Cl.uint(10001)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1005)));

    const score = readRisk('get-system-risk-score');
    expect(score).toEqual(Cl.ok(Cl.uint(5000)));

    const config = Cl.prettyPrint(readRisk('get-risk-config'));
    expect(config).toContain('liquidation-threshold: u10000');
    expect(config).toContain('emergency-threshold: u11000');
    expect(config).toContain('active-liquidation-threshold: u11000');
    expect(config).toContain('system-risk-limit: u5000');
    expect(config).toContain('max-system-risk-score: u10000');
    expect(config).toContain('cache-max-age: u6');
  });

  it('refreshes and observes cache state, then fails closed when it becomes stale', () => {
    ensureInitialized();
    const positionId = 498001;
    mintPosition(positionId);

    expect(readRisk('get-position-health', [Cl.uint(positionId)])).toEqual(Cl.error(Cl.uint(1003)));
    expect(simnet.callPublicFn(RISK_UNIT, 'get-health-factor', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(20000)));
    expect(simnet.callReadOnlyFn(RISK_UNIT, 'get-health-factor-read-only', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(20000)));
    expect(simnet.callReadOnlyFn(RISK_UNIT, 'is-liquidatable', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(false)));

    const freshCache = Cl.prettyPrint(readRisk('get-position-health', [Cl.uint(positionId)]));
    expect(freshCache).toContain('health-factor: u20000');
    expect(freshCache).toContain('fresh: true');
    expect(freshCache).toContain('last-update:');

    simnet.mineEmptyBlocks(6);

    const maxAgeCache = Cl.prettyPrint(readRisk('get-position-health', [Cl.uint(positionId)]));
    expect(maxAgeCache).toContain('fresh: true');
    expect(simnet.callReadOnlyFn(RISK_UNIT, 'get-health-factor-read-only', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(20000)));

    simnet.mineEmptyBlocks(1);

    const staleCache = Cl.prettyPrint(readRisk('get-position-health', [Cl.uint(positionId)]));
    expect(staleCache).toContain('fresh: false');
    expect(simnet.callReadOnlyFn(RISK_UNIT, 'get-health-factor-read-only', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1004)));
    expect(simnet.callReadOnlyFn(RISK_UNIT, 'is-liquidatable', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1004)));
  });

  it('checks liquidation authorization before cache mutation and preserves healthy positions', () => {
    ensureInitialized();
    const positionId = 498002;
    mintPosition(positionId);

    const unauthorized = simnet.callPublicFn(RISK_UNIT, 'liquidate', [Cl.uint(positionId)], wallet1);
    expect(unauthorized.result).toEqual(Cl.error(Cl.uint(1000)));
    expect(readRisk('get-position-health', [Cl.uint(positionId)])).toEqual(Cl.error(Cl.uint(1003)));

    expect(simnet.callPublicFn(RISK_UNIT, 'get-health-factor', [Cl.uint(positionId)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(20000)));
    const cachedBeforeLiquidation = Cl.prettyPrint(readRisk('get-position-health', [Cl.uint(positionId)]));
    const healthyLiquidation = simnet.callPublicFn(RISK_UNIT, 'liquidate', [Cl.uint(positionId)], deployer);
    expect(healthyLiquidation.result).toEqual(Cl.error(Cl.uint(1002)));
    expect(Cl.prettyPrint(readRisk('get-position-health', [Cl.uint(positionId)])))
      .toEqual(cachedBeforeLiquidation);
  });

  it('keeps privileged facade writes fail-closed while pure/query compatibility remains available', () => {
    ensureInitialized();

    expect(simnet.callPublicFn(RISK_MANAGER, 'liquidate', [Cl.uint(498001)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1003)));
    expect(simnet.callPublicFn(RISK_MANAGER, 'update-system-risk', [Cl.uint(1)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1003)));
    expect(simnet.callPublicFn(
      RISK_MANAGER,
      'initialize',
      [Cl.principal(deployer), Cl.principal(deployer + '.agent-risk'), Cl.principal(deployer + '.dimensional-engine')],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1003)));
    expect(simnet.callReadOnlyFn(
      RISK_MANAGER,
      'calculate-health-factor',
      [Cl.uint(1000), Cl.uint(1000)],
      deployer,
    ).result).toEqual(Cl.uint(10000));
  });

  it('publishes normalized agent scores only through configured risk-unit wiring', () => {
    ensureInitialized();
    expect(simnet.callPublicFn('agent-risk', 'set-risk-unit', [Cl.principal(deployer + '.risk-unit')], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn('finance-metrics', 'set-mock-gcr', [Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const crisis = simnet.callPublicFn(
      AGENT_RISK,
      'publish-system-risk',
      [metricsPrincipal, riskUnitPrincipal],
      deployer,
    );
    expect(crisis.result).toEqual(Cl.ok(Cl.uint(9000)));
    expect(readRisk('get-system-risk-score')).toEqual(Cl.ok(Cl.uint(9000)));

    expect(simnet.callPublicFn('finance-metrics', 'set-mock-gcr', [Cl.uint(150)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const healthy = simnet.callPublicFn(
      AGENT_RISK,
      'publish-system-risk',
      [metricsPrincipal, riskUnitPrincipal],
      deployer,
    );
    expect(healthy.result).toEqual(Cl.ok(Cl.uint(1000)));
    expect(readRisk('get-system-risk-score')).toEqual(Cl.ok(Cl.uint(1000)));

    expect(simnet.callPublicFn('agent-risk', 'set-risk-score', [Cl.uint(1001)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1001)));
    expect(simnet.callPublicFn(
      AGENT_RISK,
      'publish-system-risk',
      [metricsPrincipal, riskManagerPrincipal],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
  });

  it('hardens agent initialization and propagates metrics responses without unwrap-panic paths', () => {
    ensureInitialized();

    expect(simnet.callReadOnlyFn(AGENT_RISK, 'get-contract-owner', [], deployer).result)
      .toEqual(Cl.ok(Cl.principal(deployer)));
    expect(simnet.callPublicFn(AGENT_RISK, 'initialize', [Cl.principal(wallet1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(AGENT_RISK, 'initialize', [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1000)));

    const gcr = simnet.callPublicFn(AGENT_RISK, 'get-gcr', [metricsPrincipal], deployer);
    expect(gcr.result).toEqual(Cl.ok(Cl.uint(150)));
  });

  it('keeps generator-owned release plans fully risk-wired in dependency-safe order', () => {
    for (const relativePath of generatedReleasePlans) {
      const content = readFileSync(path.join(repoRoot, relativePath), 'utf8');
      const calls = content
        .split(/\n    - contract-call:\n/)
        .slice(1)
        .map((block) => ({
          block,
          contractId: block.match(/^\s+contract-id:\s*"?([^"\n]+)"?\s*$/m)?.[1] ?? '',
          method: block.match(/^\s+method:\s*"?([^"\n]+)"?\s*$/m)?.[1] ?? '',
        }));

      const riskCalls = calls.filter(({ contractId, method }) => (
        (contractId.endsWith('.risk-unit') && ['initialize', 'set-ops-engine'].includes(method))
        || (contractId.endsWith('.agent-risk') && ['initialize', 'set-risk-unit'].includes(method))
        || (contractId.endsWith('.conxian-protocol') && method === 'register-module')
      ));

      expect(riskCalls.map(({ contractId, method }) => [contractId.split('.').pop(), method]), relativePath)
        .toEqual([
          ['risk-unit', 'initialize'],
          ['risk-unit', 'set-ops-engine'],
          ['agent-risk', 'initialize'],
          ['agent-risk', 'set-risk-unit'],
          ['conxian-protocol', 'register-module'],
          ['conxian-protocol', 'register-module'],
        ]);
      expect(riskCalls[0].block).toContain('.agent-risk');
      expect(riskCalls[0].block).toContain('.dimensional-engine');
      expect(riskCalls[1].block).toContain('.ops-engine');
      expect(riskCalls[2].block).toContain("'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P'");
      expect(riskCalls[3].block).toContain('.risk-unit');
      expect(riskCalls[4].block).toContain('\\"risk-unit\\"');
      expect(riskCalls[4].block).toContain('.risk-unit');
      expect(riskCalls[5].block).toContain('\\"risk-manager\\"');
      expect(riskCalls[5].block).toContain('.risk-manager');
    }
  });
});
