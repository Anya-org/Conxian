import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

// Helper to unwrap ok bool
function ok(result: any) { expect(result.type).toBe('ok'); }

describe('Financial Ledger Feature Flag & Period Finalization', () => {
  let simnet: any; let accounts: Map<string,string>; let deployer: string; let wallet1: string;

  beforeEach(async () => { simnet = await initSimnet(); accounts = simnet.getAccounts(); deployer = accounts.get('deployer')!; wallet1 = accounts.get('wallet_1')!; });

  it('enables ledger, records fees & expenses, finalizes period with adjusted EBITDA', () => {
    // Initially disabled
    let enabled = simnet.callReadOnlyFn('enhanced-analytics','get-financial-ledger-enabled',[],deployer);
    expect(enabled.result).toStrictEqual({ type: 'bool', value: false });

    // Enable (admin = deployer)
    let resp = simnet.callPublicFn('enhanced-analytics','set-financial-ledger-enabled',[Cl.bool(true)], deployer);
    ok(resp.result);

    // Record: deposit fee 100, performance fee 50, rebate 10, op-ex 20, extraordinary +30, buyback 15, distribution 5
    resp = simnet.callPublicFn('enhanced-analytics','record-fee',[Cl.uint(0), Cl.uint(100)], deployer); ok(resp.result);
    resp = simnet.callPublicFn('enhanced-analytics','record-fee',[Cl.uint(2), Cl.uint(50)], deployer); ok(resp.result);
    resp = simnet.callPublicFn('enhanced-analytics','record-rebate',[Cl.uint(10)], deployer); ok(resp.result);
    resp = simnet.callPublicFn('enhanced-analytics','record-operating-expense',[Cl.uint(20)], deployer); ok(resp.result);
    resp = simnet.callPublicFn('enhanced-analytics','record-extraordinary-item',[Cl.uint(30)], deployer); ok(resp.result);
    resp = simnet.callPublicFn('enhanced-analytics','record-buyback',[Cl.uint(15)], deployer); ok(resp.result);
    resp = simnet.callPublicFn('enhanced-analytics','record-distribution',[Cl.uint(5)], deployer); ok(resp.result);

    // Finalize period (type epoch=0, id=1)
    resp = simnet.callPublicFn('enhanced-analytics','finalize-financial-period',[Cl.uint(0), Cl.uint(1), Cl.bool(true), Cl.stringAscii('hash')], deployer);
    ok(resp.result);

    // Fetch stored period
    const period = simnet.callReadOnlyFn('enhanced-analytics','get-financial-period',[Cl.uint(0), Cl.uint(1)], deployer);
    expect(period.result.type).toBe('some');
    const tuple = period.result.value;

    // gross = 150, rebates=10 -> net=140, opx=20 -> ebitda=120, +extra 30 => base 150, -buyback15 =>135, -distribution5 =>130
    function getUint(t:any, k:string){ return Number(t.value[k].value); }
    expect(getUint(tuple,'gross-revenue')).toBe(150);
    expect(getUint(tuple,'rebates')).toBe(10);
    expect(getUint(tuple,'net-revenue')).toBe(140);
    expect(getUint(tuple,'operating-expenses')).toBe(20);
    expect(getUint(tuple,'extraordinary-items')).toBe(30);
    expect(getUint(tuple,'buybacks')).toBe(15);
    expect(getUint(tuple,'distributions')).toBe(5);
    expect(getUint(tuple,'adjusted-ebitda')).toBe(130);

    // Accumulators reset after finalize (attempt second finalize same id should err u802)
    const repeat = simnet.callPublicFn('enhanced-analytics','finalize-financial-period',[Cl.uint(0), Cl.uint(1), Cl.bool(true), Cl.stringAscii('dup')], deployer);
    expect(repeat.result).toStrictEqual({ type: 'err', value: { type: 'uint', value: 802n }});
  });

  it('rejects recording while disabled', () => {
    const attempt = simnet.callPublicFn('enhanced-analytics','record-fee',[Cl.uint(0), Cl.uint(1)], wallet1);
    expect(attempt.result).toStrictEqual({ type: 'err', value: { type: 'uint', value: 800n }});
  });
});
