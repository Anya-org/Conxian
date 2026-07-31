import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const CONTRACT = 'partner-policy-registry';

describe('Dormant partner policy registry', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let integrationCounter = 0;

  const hash = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));
  const principal = (value: string) => Cl.principal(value);
  const integration = () => `${deployer}.partner-${++integrationCounter}`;
  const reporter = () => `${deployer}.partner-reporter`;
  const alternateBeneficiary = () => `${deployer}.partner-beneficiary-2`;
  const currentBurnHeight = () => BigInt(simnet.burnBlockHeight);

  const createPolicy = (
    policyId: number,
    version: number,
    start: bigint,
    end: bigint,
    overrides: Partial<{
      asset: number;
      billingMode: number;
      feeBase: number;
      correctionMode: number;
      lifecycleMode: number;
      sender: string;
      hashFill: number;
    }> = {},
  ) => simnet.callPublicFn(
    CONTRACT,
    'create-policy',
    [
      Cl.uint(policyId),
      Cl.uint(version),
      hash(overrides.hashFill ?? policyId),
      Cl.uint(overrides.asset ?? 1),
      Cl.uint(overrides.billingMode ?? 1),
      Cl.uint(overrides.feeBase ?? 1),
      Cl.uint(overrides.correctionMode ?? 1),
      Cl.uint(overrides.lifecycleMode ?? 1),
      Cl.uint(start),
      Cl.uint(end),
    ],
    overrides.sender ?? deployer,
  );

  const activatePolicy = (policyId: number, version: number, sender = deployer) =>
    simnet.callPublicFn(
      CONTRACT,
      'activate-policy',
      [Cl.uint(policyId), Cl.uint(version)],
      sender,
    );

  const registerPartner = (
    integrationPrincipal: string,
    policyId: number,
    policyVersion: number,
    overrides: Partial<{
      owner: string;
      payer: string;
      beneficiary: string;
      reporter: string;
      sender: string;
    }> = {},
  ) => simnet.callPublicFn(
    CONTRACT,
    'register-partner',
    [
      principal(integrationPrincipal),
      principal(overrides.owner ?? wallet1),
      principal(overrides.payer ?? wallet2),
      principal(overrides.beneficiary ?? wallet3),
      principal(overrides.reporter ?? reporter()),
      Cl.uint(policyId),
      Cl.uint(policyVersion),
    ],
    overrides.sender ?? deployer,
  );

  const activatePartner = (integrationPrincipal: string, sender = deployer) =>
    simnet.callPublicFn(
      CONTRACT,
      'activate-partner',
      [principal(integrationPrincipal)],
      sender,
    );

  const readSomeTuple = (result: any): Record<string, any> => {
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('some');
    expect(result.value.value.type).toBe('tuple');
    return result.value.value.value;
  };

  const expectPrintEvent = (receipt: any, eventName: string) => {
    expect(receipt.events.some((event: any) => event.event === 'print_event')).toBe(true);
    expect(JSON.stringify(receipt.events)).toContain(eventName);
  };

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
  });

  it('publishes exact dormant v1 constants and floor/remainder split semantics', () => {
    const defaults: any = simnet.callReadOnlyFn(
      CONTRACT,
      'get-v1-defaults',
      [],
      deployer,
    ).result;
    expect(defaults).toEqual(Cl.ok(Cl.tuple({
      asset: Cl.uint(1),
      'billing-mode': Cl.uint(1),
      'fee-base': Cl.uint(1),
      'correction-mode': Cl.uint(1),
      'lifecycle-mode': Cl.uint(1),
      'partner-split-bps': Cl.uint(5000),
      'protocol-split-bps': Cl.uint(5000),
      'bps-denominator': Cl.uint(10000),
      'period-length': Cl.uint(4320),
    })));

    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'preview-v1-split',
      [Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({
      'partner-amount': Cl.uint(0),
      'protocol-amount': Cl.uint(1),
    })));
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'preview-v1-split',
      [Cl.uint(101)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({
      'partner-amount': Cl.uint(50),
      'protocol-amount': Cl.uint(51),
    })));
  });

  it('rejects unauthorized mutation and unsupported policy fields', () => {
    const now = currentBurnHeight();
    expect(createPolicy(10, 1, now, now + 100n, { sender: wallet3 }).result)
      .toEqual(Cl.error(Cl.uint(3000)));
    expect(createPolicy(0, 1, now, now + 100n).result)
      .toEqual(Cl.error(Cl.uint(3001)));
    expect(createPolicy(11, 0, now, now + 100n).result)
      .toEqual(Cl.error(Cl.uint(3002)));
    expect(createPolicy(12, 2, now, now + 100n).result)
      .toEqual(Cl.error(Cl.uint(3002)));
    expect(createPolicy(13, 1, now, now).result)
      .toEqual(Cl.error(Cl.uint(3005)));
    expect(createPolicy(14, 1, now, now + 100n, { asset: 2 }).result)
      .toEqual(Cl.error(Cl.uint(3006)));
    expect(createPolicy(15, 1, now, now + 100n, { billingMode: 2 }).result)
      .toEqual(Cl.error(Cl.uint(3007)));
    expect(createPolicy(16, 1, now, now + 100n, { feeBase: 2 }).result)
      .toEqual(Cl.error(Cl.uint(3008)));
    expect(createPolicy(17, 1, now, now + 100n, { correctionMode: 2 }).result)
      .toEqual(Cl.error(Cl.uint(3008)));
    expect(createPolicy(18, 1, now, now + 100n, { lifecycleMode: 2 }).result)
      .toEqual(Cl.error(Cl.uint(3008)));
  });

  it('creates auditable immutable policy versions and rejects overlap or backward periods', () => {
    const now = currentBurnHeight();
    const createdV1 = createPolicy(20, 1, now, now + 100n, { hashFill: 20 });
    expect(createdV1.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(createdV1, 'partner-policy-created');

    expect(createPolicy(20, 1, now, now + 100n, { hashFill: 21 }).result)
      .toEqual(Cl.error(Cl.uint(3003)));
    expect(createPolicy(20, 3, now + 100n, now + 200n).result)
      .toEqual(Cl.error(Cl.uint(3002)));
    expect(createPolicy(20, 2, now + 99n, now + 200n).result)
      .toEqual(Cl.error(Cl.uint(3005)));

    const createdV2 = createPolicy(20, 2, now + 100n, now + 200n, { hashFill: 22 });
    expect(createdV2.result).toEqual(Cl.ok(Cl.bool(true)));

    const v1 = readSomeTuple(simnet.callReadOnlyFn(
      CONTRACT,
      'get-policy',
      [Cl.uint(20), Cl.uint(1)],
      deployer,
    ).result);
    const v2 = readSomeTuple(simnet.callReadOnlyFn(
      CONTRACT,
      'get-policy',
      [Cl.uint(20), Cl.uint(2)],
      deployer,
    ).result);
    expect(v1['policy-hash']).toEqual(hash(20));
    expect(v1['effective-start']).toEqual(Cl.uint(now));
    expect(v1['effective-end']).toEqual(Cl.uint(now + 100n));
    expect(v1.status).toEqual(Cl.uint(1));
    expect(v2['policy-hash']).toEqual(hash(22));
    expect(v2['effective-start']).toEqual(Cl.uint(now + 100n));

    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'get-effective-period',
      [Cl.uint(20), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.some(Cl.tuple({
      'effective-start': Cl.uint(now),
      'effective-end': Cl.uint(now + 100n),
      'period-length': Cl.uint(4320),
      status: Cl.uint(1),
    }))));
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'get-policy-asset',
      [Cl.uint(20), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.some(Cl.uint(1))));
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'get-policy-billing-mode',
      [Cl.uint(20), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.some(Cl.uint(1))));
  });

  it('uses registered dynamic authorization routes and can permanently finalize bootstrap access', () => {
    expect(simnet.callPublicFn(
      CONTRACT,
      'finalize-bootstrap-authorization',
      [],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(3019)));

    expect(simnet.callPublicFn(
      'operational-treasury',
      'set-protocol-principal',
      [Cl.stringAscii('partner-policy-admin'), principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'operational-treasury',
      'set-protocol-principal',
      [Cl.stringAscii('partner-policy-registrar'), principal(wallet2)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const state: any = simnet.callReadOnlyFn(
      CONTRACT,
      'get-authorization-state',
      [principal(wallet1)],
      deployer,
    ).result;
    expect(state.value.value['actor-is-admin']).toEqual(Cl.bool(true));
    expect(state.value.value['actor-is-registrar']).toEqual(Cl.bool(true));

    expect(simnet.callPublicFn(
      CONTRACT,
      'finalize-bootstrap-authorization',
      [],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(3000)));
    const finalized = simnet.callPublicFn(
      CONTRACT,
      'finalize-bootstrap-authorization',
      [],
      deployer,
    );
    expect(finalized.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(finalized, 'partner-policy-bootstrap-finalized');
    expect(simnet.callPublicFn(
      CONTRACT,
      'finalize-bootstrap-authorization',
      [],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(3018)));

    const now = currentBurnHeight();
    expect(createPolicy(21, 1, now, now + 100n).result)
      .toEqual(Cl.error(Cl.uint(3000)));
    expect(createPolicy(21, 1, now, now + 100n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it('enforces policy activation/effectiveness and partner role constraints', () => {
    const now = currentBurnHeight();
    expect(createPolicy(30, 1, now, now + 1000n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    const draftPartner = integration();
    expect(registerPartner(draftPartner, 30, 1, { sender: wallet2 }).result)
      .toEqual(Cl.error(Cl.uint(3009)));

    const activated = activatePolicy(30, 1, wallet1);
    expect(activated.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(activated, 'partner-policy-activated');
    expect(activatePolicy(30, 1, wallet1).result)
      .toEqual(Cl.error(Cl.uint(3015)));

    const badRoles = integration();
    const invalidRoleOverrides = [
      { owner: wallet1, payer: wallet1 },
      { owner: wallet1, beneficiary: wallet1 },
      { payer: wallet2, beneficiary: wallet2 },
      { owner: reporter(), reporter: reporter() },
      { payer: reporter(), reporter: reporter() },
      { beneficiary: reporter(), reporter: reporter() },
      { owner: badRoles },
      { payer: badRoles },
      { beneficiary: badRoles },
      { reporter: badRoles },
    ];
    for (const overrides of invalidRoleOverrides) {
      expect(registerPartner(badRoles, 30, 1, {
        ...overrides,
        sender: wallet2,
      }).result).toEqual(Cl.error(Cl.uint(3014)));
    }

    const goodPartner = integration();
    expect(registerPartner(goodPartner, 30, 1, { sender: wallet3 }).result)
      .toEqual(Cl.error(Cl.uint(3000)));
    const registered = registerPartner(goodPartner, 30, 1, { sender: wallet2 });
    expect(registered.result).toEqual(Cl.ok(Cl.uint(1)));
    expectPrintEvent(registered, 'partner-integration-registered');
    expect(registerPartner(goodPartner, 30, 1, { sender: wallet2 }).result)
      .toEqual(Cl.error(Cl.uint(3012)));

    const partnerActivated = activatePartner(goodPartner, wallet2);
    expect(partnerActivated.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(partnerActivated, 'partner-integration-activated');
    expect(activatePartner(goodPartner, wallet2).result)
      .toEqual(Cl.error(Cl.uint(3015)));

    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'validate-partner-policy',
      [principal(goodPartner), Cl.uint(30), Cl.uint(1), hash(30)],
      deployer,
    ).result.type).toBe('ok');
  });

  it('fails closed for missing, future, stale, mismatched, and revoked policies', () => {
    const now = currentBurnHeight();
    const missingPartner = integration();
    expect(registerPartner(missingPartner, 999, 1, { sender: wallet2 }).result)
      .toEqual(Cl.error(Cl.uint(3004)));

    expect(createPolicy(40, 1, now + 5n, now + 50n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePolicy(40, 1, wallet1).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(registerPartner(integration(), 40, 1, { sender: wallet2 }).result)
      .toEqual(Cl.error(Cl.uint(3010)));

    expect(createPolicy(41, 1, now, now + 2n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePolicy(41, 1, wallet1).result).toEqual(Cl.ok(Cl.bool(true)));
    const stalePartner = integration();
    expect(registerPartner(stalePartner, 41, 1, { sender: wallet2 }).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(activatePartner(stalePartner, wallet2).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'validate-partner-policy',
      [principal(stalePartner), Cl.uint(41), Cl.uint(1), hash(99)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(3016)));
    simnet.mineEmptyBurnBlocks(2);
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'validate-partner-policy',
      [principal(stalePartner), Cl.uint(41), Cl.uint(1), hash(41)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(3010)));

    const nowAfterMining = currentBurnHeight();
    expect(createPolicy(42, 1, nowAfterMining, nowAfterMining + 100n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePolicy(42, 1, wallet1).result).toEqual(Cl.ok(Cl.bool(true)));
    const revokedPartner = integration();
    expect(registerPartner(revokedPartner, 42, 1, { sender: wallet2 }).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(activatePartner(revokedPartner, wallet2).result).toEqual(Cl.ok(Cl.bool(true)));
    const revoked = simnet.callPublicFn(
      CONTRACT,
      'revoke-policy',
      [Cl.uint(42), Cl.uint(1), hash(242)],
      wallet1,
    );
    expect(revoked.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(revoked, 'partner-policy-revoked');
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'validate-partner-policy',
      [principal(revokedPartner), Cl.uint(42), Cl.uint(1), hash(42)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(3011)));
    expect(activatePolicy(42, 1, wallet1).result)
      .toEqual(Cl.error(Cl.uint(3015)));
  });

  it('versions beneficiary changes and preserves historical partner records', () => {
    const now = currentBurnHeight();
    expect(createPolicy(50, 1, now, now + 1000n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePolicy(50, 1, wallet1).result).toEqual(Cl.ok(Cl.bool(true)));
    const partner = integration();
    expect(registerPartner(partner, 50, 1, { sender: wallet2 }).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(activatePartner(partner, wallet2).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      CONTRACT,
      'change-beneficiary',
      [principal(partner), principal(alternateBeneficiary())],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(3000)));
    expect(simnet.callPublicFn(
      CONTRACT,
      'change-beneficiary',
      [principal(partner), principal(wallet1)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(3014)));
    expect(simnet.callPublicFn(
      CONTRACT,
      'change-beneficiary',
      [principal(partner), principal(wallet2)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(3014)));
    expect(simnet.callPublicFn(
      CONTRACT,
      'change-beneficiary',
      [principal(partner), principal(reporter())],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(3014)));

    const changed = simnet.callPublicFn(
      CONTRACT,
      'change-beneficiary',
      [principal(partner), principal(alternateBeneficiary())],
      wallet2,
    );
    expect(changed.result).toEqual(Cl.ok(Cl.uint(2)));
    expectPrintEvent(changed, 'partner-beneficiary-changed');

    const historical = readSomeTuple(simnet.callReadOnlyFn(
      CONTRACT,
      'get-partner-version',
      [principal(partner), Cl.uint(1)],
      deployer,
    ).result);
    const current = readSomeTuple(simnet.callReadOnlyFn(
      CONTRACT,
      'get-partner',
      [principal(partner)],
      deployer,
    ).result);
    expect(historical.beneficiary).toEqual(principal(wallet3));
    expect(historical.status).toEqual(Cl.uint(3));
    expect(current.beneficiary).toEqual(principal(alternateBeneficiary()));
    expect(current.status).toEqual(Cl.uint(2));
    expect(current['policy-hash']).toEqual(historical['policy-hash']);
  });

  it('makes partner deactivation and revocation terminal for each historical record', () => {
    const now = currentBurnHeight();
    expect(createPolicy(60, 1, now, now + 1000n, { sender: wallet1 }).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePolicy(60, 1, wallet1).result).toEqual(Cl.ok(Cl.bool(true)));

    const deactivatedPartner = integration();
    expect(registerPartner(deactivatedPartner, 60, 1, { sender: wallet2 }).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(activatePartner(deactivatedPartner, wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const deactivated = simnet.callPublicFn(
      CONTRACT,
      'deactivate-partner',
      [principal(deactivatedPartner)],
      wallet2,
    );
    expect(deactivated.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(deactivated, 'partner-integration-deactivated');
    expect(activatePartner(deactivatedPartner, wallet2).result)
      .toEqual(Cl.error(Cl.uint(3015)));
    expect(simnet.callReadOnlyFn(
      CONTRACT,
      'validate-partner-policy',
      [principal(deactivatedPartner), Cl.uint(60), Cl.uint(1), hash(60)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(3017)));

    const revokedPartner = integration();
    expect(registerPartner(revokedPartner, 60, 1, { sender: wallet2 }).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    const revoked = simnet.callPublicFn(
      CONTRACT,
      'revoke-partner',
      [principal(revokedPartner)],
      wallet1,
    );
    expect(revoked.result).toEqual(Cl.ok(Cl.bool(true)));
    expectPrintEvent(revoked, 'partner-integration-revoked');
    expect(activatePartner(revokedPartner, wallet2).result)
      .toEqual(Cl.error(Cl.uint(3015)));
  });

  it('preserves the legacy 100%-protocol collector contract and period defaults', () => {
    expect(simnet.callReadOnlyFn(
      'integration-fee-collector',
      'get-monthly-period-burn-blocks',
      [],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(4320)));
    const collectorSource = simnet.getContractSource('integration-fee-collector')!;
    expect(collectorSource).toContain('.revenue-distributor distribute-stx amount');
    expect(collectorSource).not.toContain('partner-policy-registry');
  });
});
