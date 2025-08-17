import { initSimnet } from '@hirosystems/clarinet-sdk';
import { describe, it, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';

// Minimal types to satisfy existing legacy tests
export const types = {
  uint: (v: number | bigint) => Cl.uint(v),
  int: (v: number | bigint) => Cl.int(v),
  bool: (v: boolean) => Cl.bool(v),
  principal: (p: string) => Cl.principal(p),
  some: (x: any) => Cl.some(x),
  none: () => Cl.none(),
  tuple: (t: Record<string, any>) => Cl.tuple(t),
  list: (l: any[]) => Cl.list(l as any),
  ascii: (s: string) => Cl.stringAscii(s),
  utf8: (s: string) => Cl.stringUtf8(s),
};

function wrapExpect(result: any) {
  return {
    expectOk() { if (result.type !== 'ok') throw new Error(`Expected ok, got ${result.type}`); return wrapExpect(result.value); },
    expectErr() { if (result.type !== 'err') throw new Error(`Expected err, got ${result.type}`); return wrapExpect(result.value); },
    expectUint(v: number | bigint) { if (!(result.type === 'uint' && result.value === BigInt(v))) throw new Error(`Expected uint ${v}, got ${JSON.stringify(result)}`); },
    expectBool(b: boolean) { if (!(result.type === 'bool' && result.value === b)) throw new Error(`Expected bool ${b}, got ${JSON.stringify(result)}`); },
  };
}

class TxBuilder {
  contractCall(contract: string, fn: string, args: any[], sender: string) {
    return { type: 'contract_call', contract, fn, args, sender };
  }
}

export const Tx = new TxBuilder();

class ChainWrapper {
  simnet: any;
  constructor(simnet: any) { this.simnet = simnet; }
  mineBlock(txs: any[]) {
    const receipts = txs.map(tx => {
      const { result } = this.simnet.callPublicFn(tx.contract, tx.fn, tx.args, tx.sender);
      return { result: wrapExpect(result) };
    });
    return { receipts };
  }
  callReadOnlyFn(contract: string, fn: string, args: any[], sender: string) {
    const ro = this.simnet.callReadOnlyFn(contract, fn, args, sender);
    return { result: wrapExpect(ro.result) };
  }
  mineEmptyBlock(n: number) { for (let i=0;i<n;i++) { /* no-op advance */ } }
}

export const Clarinet = {
  test({ name, fn }: { name: string, fn: (chain: any, accounts: Map<string, any>) => Promise<void> | void }) {
    describe(name, () => {
      let simnet: any; let accounts: Map<string, any>; let chain: any;
      beforeEach(async () => { simnet = await initSimnet(); accounts = simnet.getAccounts(); chain = new ChainWrapper(simnet); });
      it(name, async () => { await fn(chain, accounts); });
    });
  }
};
