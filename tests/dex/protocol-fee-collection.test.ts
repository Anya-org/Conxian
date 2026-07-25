import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CLP = 'concentrated-liquidity-pool';
const AGGREGATOR = 'swap-aggregator';
const BME = 'bme-engine';
const CXD = 'cxd-token';
const FISCAL_ORCHESTRATOR = 'fiscal-orchestrator';
const FINANCE_METRICS = 'finance-metrics';

const ERR_CLP_FEE_CUSTODY_UNAVAILABLE = 1008;
const ERR_AGGREGATOR_FEE_CUSTODY_UNAVAILABLE = 1003;
const ERR_FISCAL_EXECUTION_FAILED = 2002;

describe('DEX protocol-fee custody boundaries', () => {
  let deployer: string;
  let wallet1: string;
  let token: ReturnType<typeof Cl.contractPrincipal>;

  const contractPrincipal = (name: string) => `${deployer}.${name}`;
  const balance = (principal: string) =>
    simnet.callReadOnlyFn(CXD, 'get-balance', [Cl.principal(principal)], deployer).result;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    token = Cl.contractPrincipal(deployer, CXD);
  });

  it('fails CLP fee collection closed for admin and non-admin callers without moving tokens', () => {
    const trackedPrincipals = [
      deployer,
      wallet1,
      contractPrincipal(CLP),
      contractPrincipal(AGGREGATOR),
    ];
    const balancesBefore = trackedPrincipals.map(balance);

    expect(simnet.callPublicFn(CLP, 'collect-protocol-fees', [token], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_CLP_FEE_CUSTODY_UNAVAILABLE)));
    expect(simnet.callPublicFn(CLP, 'collect-protocol-fees', [token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(ERR_CLP_FEE_CUSTODY_UNAVAILABLE)));

    expect(trackedPrincipals.map(balance)).toEqual(balancesBefore);
  });

  it('fails aggregator fee collection closed for admin and non-admin callers without moving tokens', () => {
    const trackedPrincipals = [
      deployer,
      wallet1,
      contractPrincipal(CLP),
      contractPrincipal(AGGREGATOR),
    ];
    const balancesBefore = trackedPrincipals.map(balance);

    expect(simnet.callPublicFn(AGGREGATOR, 'collect-protocol-fees', [token], deployer).result)
      .toEqual(Cl.error(Cl.uint(ERR_AGGREGATOR_FEE_CUSTODY_UNAVAILABLE)));
    expect(simnet.callPublicFn(AGGREGATOR, 'collect-protocol-fees', [token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(ERR_AGGREGATOR_FEE_CUSTODY_UNAVAILABLE)));

    expect(trackedPrincipals.map(balance)).toEqual(balancesBefore);
  });

  it('stops fiscal orchestration before downstream BME minting', () => {
    expect(simnet.callPublicFn(FINANCE_METRICS, 'set-mock-gcr', [Cl.uint(140)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(BME, 'register-fee-activity', [Cl.principal(wallet1), Cl.uint(1_000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(144);

    const statsBefore = simnet.callReadOnlyFn(BME, 'get-bme-stats', [], deployer).result;
    const targetBalanceBefore = balance(wallet1);

    const result = simnet.callPublicFn(
      FISCAL_ORCHESTRATOR,
      'run-fiscal-strategy',
      [
        Cl.list([Cl.principal(wallet1)]),
        token,
        Cl.contractPrincipal(deployer, FINANCE_METRICS),
      ],
      deployer,
    );

    expect(result.result).toEqual(Cl.error(Cl.uint(ERR_FISCAL_EXECUTION_FAILED)));
    expect(simnet.callReadOnlyFn(BME, 'get-bme-stats', [], deployer).result).toEqual(statsBefore);
    expect(balance(wallet1)).toEqual(targetBalanceBefore);
  });
});
