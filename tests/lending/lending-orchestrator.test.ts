import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('lending-orchestrator canonical protocol fees', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let orchestrator: string;
  let collector: string;
  let mockToken: string;

  const streamId = 538;
  const scheduledStreamId = 539;
  const sourceTrait = () => Cl.contractPrincipal(deployer, 'lending-orchestrator');
  const tokenTrait = () => Cl.contractPrincipal(deployer, 'mock-token');

  const balance = (token: string, principal: string): bigint => {
    const result: any = simnet.callReadOnlyFn(
      token,
      'get-balance',
      [Cl.principal(principal)],
      deployer,
    ).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  const reserve = (asset = tokenTrait()): any => {
    const result: any = simnet.callReadOnlyFn(
      'lending-orchestrator',
      'get-reserve-data',
      [asset],
      deployer,
    ).result;
    expect(result.type).toBe('some');
    return result.value.value;
  };

  const nonce = (): bigint => {
    const result: any = simnet.callReadOnlyFn(
      'lending-orchestrator',
      'get-protocol-fee-nonce',
      [],
      deployer,
    ).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  const collectorSchedule = (): any => {
    const result: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-schedule',
      [],
      deployer,
    ).result;
    expect(result.type).toBe('ok');
    return result.value.value;
  };

  const eventNamed = (receipt: any, name: string): any | undefined => receipt.events.find(
    (event: any) => event.event === 'print_event'
      && event.data?.value?.value?.event?.value === name,
  );

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
    orchestrator = `${deployer}.lending-orchestrator`;
    collector = `${deployer}.protocol-fee-collector`;
    mockToken = `${deployer}.mock-token`;

    for (const wallet of [wallet1, wallet2, wallet3]) {
      simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1_000_000), Cl.principal(wallet)], deployer);
    }

    expect(simnet.callPublicFn(
      'protocol-fee-collector',
      'set-authorized-source',
      [Cl.principal(orchestrator), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-fixed-100-bps-stream',
      [Cl.principal(orchestrator), Cl.uint(streamId), Cl.principal(mockToken), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'set-protocol-fee-stream',
      [Cl.principal(mockToken), Cl.uint(streamId)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(streamId)));
  });

  it('rejects scheduled stream binding without writing the local asset mapping', () => {
    const otherAsset = `${deployer}.cxvg-token`;
    expect(simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(orchestrator), Cl.uint(scheduledStreamId), Cl.principal(otherAsset), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'set-protocol-fee-stream',
      [Cl.principal(otherAsset), Cl.uint(scheduledStreamId)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(5024)));
    expect(simnet.callReadOnlyFn(
      'lending-orchestrator',
      'get-protocol-fee-stream',
      [Cl.principal(otherAsset)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));
  });

  it('settles only the interest base, credits net reserves, and rejects replay without legacy revenue', () => {
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'deposit',
      [tokenTrait(), Cl.uint(2_000)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'borrow',
      [tokenTrait(), Cl.uint(1_000)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const before = reserve();
    const payerBefore = balance('mock-token', wallet1);
    const orchestratorBefore = balance('mock-token', orchestrator);
    const collectorBefore = balance('mock-token', collector);
    const legacyBefore = balance('mock-token', `${deployer}.revenue-distributor`);
    const nonceBefore = nonce();
    const receipt: any = simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [tokenTrait(), Cl.uint(1_000), sourceTrait()],
      wallet1,
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));

    const collectorEvent: any = eventNamed(receipt, 'protocol-fee-collected');
    expect(collectorEvent).toBeDefined();
    const eventValue = collectorEvent.data.value.value;
    expect(eventValue['eligible-fee-base']).toEqual(Cl.uint(100));
    expect(eventValue['assessed-amount']).toEqual(Cl.uint(1));
    expect(eventValue['settled-amount']).toEqual(Cl.uint(1));
    expect(eventValue['rate-policy']).toEqual(Cl.uint(2));
    expect(eventValue['rate-bps']).toEqual(Cl.uint(100));
    expect(eventValue.phase).toEqual(Cl.uint(4));
    expect(eventValue.source).toEqual(Cl.principal(orchestrator));
    expect(eventValue.recipient).toEqual(Cl.principal(collector));
    const callbackDebit = receipt.events.find((event: any) =>
      event.event === 'ft_transfer_event'
      && event.data?.sender === orchestrator
      && event.data?.recipient === collector);
    expect(callbackDebit).toBeDefined();
    expect(BigInt(callbackDebit.data.amount)).toBe(1n);
    expect(eventNamed(receipt, 'revenue-collected')).toBeUndefined();
    expect(eventNamed(receipt, 'lending-fee-processed')).toBeUndefined();

    const after = reserve();
    expect(BigInt(after['total-borrows'].value)).toBe(BigInt(before['total-borrows'].value) - 900n);
    expect(BigInt(after['total-reserves'].value)).toBe(BigInt(before['total-reserves'].value) + 99n);
    expect(balance('mock-token', wallet1)).toBe(payerBefore - 1_000n);
    expect(balance('mock-token', orchestrator)).toBe(orchestratorBefore + 999n);
    expect(balance('mock-token', collector)).toBe(collectorBefore + 1n);
    expect(balance('mock-token', `${deployer}.revenue-distributor`)).toBe(legacyBefore);
    expect(nonce()).toBe(nonceBefore + 1n);
    expect(simnet.callReadOnlyFn(
      'lending-orchestrator',
      'get-pending-protocol-fee',
      [Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));

    const orchestratorEvent: any = eventNamed(receipt, 'lending-protocol-fee-processed');
    expect(orchestratorEvent).toBeDefined();
    const orchestratorEvidence = orchestratorEvent.data.value.value;
    expect(orchestratorEvidence['stream-id']).toEqual(Cl.uint(streamId));
    expect(orchestratorEvidence['settlement-id']).toEqual(eventValue['settlement-id']);
    expect(orchestratorEvidence['rate-policy']).toEqual(eventValue['rate-policy']);
    expect(orchestratorEvidence['rate-bps']).toEqual(eventValue['rate-bps']);
    expect(orchestratorEvidence.phase).toEqual(eventValue.phase);
    expect(orchestratorEvidence['eligible-interest-base']).toEqual(eventValue['eligible-fee-base']);
    expect(orchestratorEvidence['protocol-fee']).toEqual(eventValue['assessed-amount']);
    expect(orchestratorEvidence['settled-amount']).toEqual(eventValue['settled-amount']);
    expect(orchestratorEvidence['net-interest-reserves']).toEqual(Cl.uint(99));

    const settlementId = eventValue['settlement-id'];
    const replayBefore = balance('mock-token', collector);
    expect(simnet.callPublicFn(
      'test-c4-helper',
      'collector-settle-source-ft',
      [sourceTrait(), tokenTrait(), Cl.uint(streamId), Cl.uint(100), settlementId],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(4110)));
    expect(balance('mock-token', collector)).toBe(replayBefore);
  });

  it('keeps repayments fixed at 100 bps across scheduled growth, mature, and post-mature boundaries', () => {
    const schedule = collectorSchedule();
    const matureBoundary = BigInt(schedule['mature-boundary-inclusive'].value);
    const targetHeights = [
      BigInt(schedule['growth-boundary-inclusive'].value),
      matureBoundary,
      matureBoundary + 1n,
    ];

    for (const targetHeight of targetHeights) {
      const currentHeight = BigInt(simnet.mineEmptyBlocks(0));
      if (targetHeight > currentHeight) {
        simnet.mineEmptyBlocks(Number(targetHeight - currentHeight));
      }

      const receipt: any = simnet.callPublicFn(
        'lending-orchestrator',
        'repay',
        [tokenTrait(), Cl.uint(1_000), sourceTrait()],
        wallet2,
      );
      expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));

      const collectorEvent: any = eventNamed(receipt, 'protocol-fee-collected');
      const orchestratorEvent: any = eventNamed(receipt, 'lending-protocol-fee-processed');
      expect(collectorEvent).toBeDefined();
      expect(orchestratorEvent).toBeDefined();
      const collectorEvidence = collectorEvent.data.value.value;
      const orchestratorEvidence = orchestratorEvent.data.value.value;
      expect(collectorEvidence['eligible-fee-base']).toEqual(Cl.uint(100));
      expect(collectorEvidence['assessed-amount']).toEqual(Cl.uint(1));
      expect(collectorEvidence['rate-policy']).toEqual(Cl.uint(2));
      expect(collectorEvidence['rate-bps']).toEqual(Cl.uint(100));
      expect(collectorEvidence.phase).toEqual(Cl.uint(4));
      expect(orchestratorEvidence['settlement-id']).toEqual(collectorEvidence['settlement-id']);
      expect(orchestratorEvidence['rate-policy']).toEqual(collectorEvidence['rate-policy']);
      expect(orchestratorEvidence['rate-bps']).toEqual(collectorEvidence['rate-bps']);
      expect(orchestratorEvidence.phase).toEqual(collectorEvidence.phase);
      expect(orchestratorEvidence['settled-amount']).toEqual(collectorEvidence['settled-amount']);
    }
  });

  it('fails before lasting custody or accounting for a wrong source and missing asset binding', () => {
    const beforeReserve = reserve();
    const userBefore = balance('mock-token', wallet2);
    const orchestratorBefore = balance('mock-token', orchestrator);
    const collectorBefore = balance('mock-token', collector);
    const nonceBefore = nonce();
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [tokenTrait(), Cl.uint(1_000), Cl.contractPrincipal(deployer, 'mock-fee-source')],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(5017)));
    expect(reserve()).toEqual(beforeReserve);
    expect(balance('mock-token', wallet2)).toBe(userBefore);
    expect(balance('mock-token', orchestrator)).toBe(orchestratorBefore);
    expect(balance('mock-token', collector)).toBe(collectorBefore);
    expect(nonce()).toBe(nonceBefore);

    const otherAsset = Cl.contractPrincipal(deployer, 'cxvg-token');
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'configure-asset-collateral',
      [otherAsset, Cl.uint(7_500), Cl.uint(8_000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn('cxvg-token', 'mint', [Cl.uint(1_000), Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const otherUserBefore = balance('cxvg-token', wallet2);
    const otherOrchestratorBefore = balance('cxvg-token', orchestrator);
    const otherReserveBefore = reserve(otherAsset);
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [otherAsset, Cl.uint(1_000), sourceTrait()],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(5010)));
    expect(balance('cxvg-token', wallet2)).toBe(otherUserBefore);
    expect(balance('cxvg-token', orchestrator)).toBe(otherOrchestratorBefore);
    expect(reserve(otherAsset)).toEqual(otherReserveBefore);
    expect(nonce()).toBe(nonceBefore);
  });

  it('rejects a direct unauthorized callback without exposing preparable custody', () => {
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'prepay-ft-fee',
      [tokenTrait(), Cl.uint(1), Cl.principal(collector)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(5012)));
  });

  it('rolls back repayment custody, accounting, pending state, and nonce when settlement is paused', () => {
    const beforeReserve = reserve();
    const userBefore = balance('mock-token', wallet3);
    const orchestratorBefore = balance('mock-token', orchestrator);
    const collectorBefore = balance('mock-token', collector);
    const nonceBefore = nonce();
    expect(simnet.callPublicFn('protocol-fee-collector', 'pause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [tokenTrait(), Cl.uint(1_000), sourceTrait()],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(4101)));
    expect(simnet.callPublicFn('protocol-fee-collector', 'unpause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(reserve()).toEqual(beforeReserve);
    expect(balance('mock-token', wallet3)).toBe(userBefore);
    expect(balance('mock-token', orchestrator)).toBe(orchestratorBefore);
    expect(balance('mock-token', collector)).toBe(collectorBefore);
    expect(nonce()).toBe(nonceBefore);
    expect(simnet.callReadOnlyFn(
      'lending-orchestrator',
      'get-pending-protocol-fee',
      [Cl.principal(wallet3)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));
  });

  it('rolls back the whole repayment when the authenticated callback transfer fails', () => {
    const beforeReserve = reserve();
    const userBefore = balance('mock-token', wallet3);
    const orchestratorBefore = balance('mock-token', orchestrator);
    const collectorBefore = balance('mock-token', collector);
    const nonceBefore = nonce();
    expect(simnet.callPublicFn(
      'mock-token',
      'set-fail-transfer-from',
      [Cl.some(Cl.principal(orchestrator))],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [tokenTrait(), Cl.uint(1_000), sourceTrait()],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(2)));
    expect(simnet.callPublicFn(
      'mock-token',
      'set-fail-transfer-from',
      [Cl.none()],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(reserve()).toEqual(beforeReserve);
    expect(balance('mock-token', wallet3)).toBe(userBefore);
    expect(balance('mock-token', orchestrator)).toBe(orchestratorBefore);
    expect(balance('mock-token', collector)).toBe(collectorBefore);
    expect(nonce()).toBe(nonceBefore);
    expect(simnet.callReadOnlyFn(
      'lending-orchestrator',
      'get-pending-protocol-fee',
      [Cl.principal(wallet3)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));
  });

  it('records a zero-fee interest settlement without a zero-value transfer', () => {
    const before = reserve();
    const collectorBefore = balance('mock-token', collector);
    const nonceBefore = nonce();
    const receipt: any = simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [tokenTrait(), Cl.uint(10), sourceTrait()],
      wallet3,
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));
    const feeEvent: any = eventNamed(receipt, 'protocol-fee-collected');
    expect(feeEvent).toBeDefined();
    expect(feeEvent.data.value.value['eligible-fee-base']).toEqual(Cl.uint(1));
    expect(feeEvent.data.value.value['assessed-amount']).toEqual(Cl.uint(0));
    const zeroCollectorTransfers = receipt.events.filter((event: any) =>
      event.event === 'ft_transfer_event'
      && event.data?.sender === orchestrator
      && event.data?.recipient === collector
      && BigInt(event.data?.amount ?? 0) === 0n);
    expect(zeroCollectorTransfers).toHaveLength(0);
    const payerTransfers = receipt.events.filter((event: any) =>
      event.event === 'ft_transfer_event'
      && event.data?.sender === wallet3
      && event.data?.recipient === orchestrator);
    expect(payerTransfers.length).toBeGreaterThan(0);
    expect(balance('mock-token', collector)).toBe(collectorBefore);
    expect(BigInt(reserve()['total-reserves'].value)).toBe(BigInt(before['total-reserves'].value) + 1n);
    expect(nonce()).toBe(nonceBefore + 1n);
  });

  it('rejects repayment arithmetic overflow before balances, state, or nonce can change', () => {
    const maxUint = 340282366920938463463374607431768211455n;
    const beforeReserve = reserve();
    const userBefore = balance('mock-token', wallet3);
    const orchestratorBefore = balance('mock-token', orchestrator);
    const collectorBefore = balance('mock-token', collector);
    const nonceBefore = nonce();
    expect(simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [tokenTrait(), Cl.uint(maxUint), sourceTrait()],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(5021)));
    expect(reserve()).toEqual(beforeReserve);
    expect(balance('mock-token', wallet3)).toBe(userBefore);
    expect(balance('mock-token', orchestrator)).toBe(orchestratorBefore);
    expect(balance('mock-token', collector)).toBe(collectorBefore);
    expect(nonce()).toBe(nonceBefore);
  });
});
