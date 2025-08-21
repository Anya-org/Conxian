import { describe, it, beforeEach, expect } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { getUintValue } from '../utils/clarity-helpers';

describe('Automation Trigger (SDK) - PRD AUTONOMICS alignment', () => {
  let simnet: any; let accounts: Map<string, any>; let deployer: string; let wallet1: string;
  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    simnet.callPublicFn('automation-trigger','set-test-mode',[Cl.bool(true)], deployer);
    simnet.callPublicFn('automation-trigger','init-dao',[Cl.principal(`${deployer}.dao-governance`)], deployer);
  });

  it('PRD AUTO-AUTH + PARTICIPATION SNAPSHOT: authorized trigger updates snapshot & history', () => {
    const rateBefore = simnet.callReadOnlyFn('avg-token','get-realloc-rate-bps',[], deployer);
    expect(rateBefore.result.type).toBe('uint');
  // Debug shapes
  // eslint-disable-next-line no-console
  console.log('DBG rateBefore', JSON.stringify(rateBefore.result));
  const baseRate = parseInt(rateBefore.result.value,10);
  const snapBefore = simnet.callReadOnlyFn('automation-trigger','get-status',[], deployer);
  const countBefore = getUintValue(snapBefore.result.value['update-count']);

    // Low participation -> should increase rate via automation triggers (threshold 55%)
    const low = Cl.uint(3000);
    const trig1 = simnet.callPublicFn('automation-trigger','trigger-adaptive-reallocation',[low], deployer);
    expect(trig1.result.type).toBe('ok');
    const trig2 = simnet.callPublicFn('automation-trigger','trigger-adaptive-reallocation',[low], deployer);
    expect(trig2.result.type).toBe('ok');

    // Read updated rate (no direct unauthorized call)
    const rateAfter = simnet.callReadOnlyFn('avg-token','get-realloc-rate-bps',[], deployer);
    expect(rateAfter.result.type).toBe('uint');
  // eslint-disable-next-line no-console
  console.log('DBG rateAfter', JSON.stringify(rateAfter.result));
  const newRate = parseInt(rateAfter.result.value,10);
    expect(newRate).toBeGreaterThanOrEqual(baseRate); // should be >= baseline
    // If baseline below cap path (<400) low participation should increment by 50 bps at least once
    if (baseRate < 400) {
      expect(newRate).toBeGreaterThan(baseRate);
    }

    const snapAfter = simnet.callReadOnlyFn('automation-trigger','get-status',[], deployer);
  const countAfter = getUintValue(snapAfter.result.value['update-count']);
    expect(countAfter).toBeGreaterThanOrEqual(countBefore + 2); // two triggers added
  const lastBps = getUintValue(snapAfter.result.value['last-participation-bps']);
    expect(lastBps).toBe(3000); // last participation value supplied
    // Participation history last index should equal last participation value
  const hist = simnet.callReadOnlyFn('automation-trigger','get-participation',[Cl.uint(countAfter)], deployer);
  expect(hist.result.type).toBe('uint');
  expect(getUintValue(hist.result)).toBe(3000);
  });

  it('PRD AUTO-EPOCH: epoch advance attempt returns ok or block threshold error u307 or auth (u100)', () => {
    const seq = simnet.callPublicFn('automation-trigger','advance-and-reallocate',[Cl.uint(5600)], deployer);
  // eslint-disable-next-line no-console
  console.log('DBG seq.result', JSON.stringify(seq.result));
    if (seq.result.type === 'err') {
  expect([307,100]).toContain(getUintValue(seq.result.value));
    } else {
      expect(seq.result.type).toBe('ok');
    }
  });

  it('PRD AUTO-ENABLE: disabling blocks triggers with u901 then re-enables', () => {
    const disable = simnet.callPublicFn('automation-trigger','set-enabled',[Cl.bool(false)], deployer);
    expect(disable.result.type).toBe('ok');
    const blocked = simnet.callPublicFn('automation-trigger','trigger-adaptive-reallocation',[Cl.uint(4000)], deployer);
  // eslint-disable-next-line no-console
  console.log('DBG blocked.result', JSON.stringify(blocked.result));
    expect(blocked.result.type).toBe('err');
  expect(getUintValue(blocked.result.value)).toBe(901);
    const enable = simnet.callPublicFn('automation-trigger','set-enabled',[Cl.bool(true)], deployer);
    expect(enable.result.type).toBe('ok');
  });
});
