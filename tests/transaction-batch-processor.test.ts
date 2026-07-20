import { beforeAll, describe, expect, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Transaction Batch Processor', () => {
  let simnet: any;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  const batchCall = (calls: ReturnType<typeof Cl.list>) =>
    simnet.callPublicFn('batch-processor', 'batch-call', [calls], deployer);

  const targetCall = (target: string, payload: string) =>
    Cl.tuple({
      target: Cl.principal(target),
      payload: Cl.bufferFromUtf8(payload),
    });

  it('returns zero for an empty batch', () => {
    const { result } = batchCall(Cl.list([]));

    expect(result).toEqual(Cl.ok(Cl.uint(0)));
  });

  it('returns one for a one-item batch', () => {
    const calls = Cl.list([targetCall(wallet1, 'call-1')]);
    const { result } = batchCall(calls);

    expect(result).toEqual(Cl.ok(Cl.uint(1)));
  });

  it('returns the exact number of calls for a multiple-item batch', () => {
    const calls = Cl.list([
      targetCall(wallet1, 'call-1'),
      targetCall(wallet2, 'call-2'),
      targetCall(deployer, 'call-3'),
    ]);
    const { result } = batchCall(calls);

    expect(result).toEqual(Cl.ok(Cl.uint(3)));
  });

  it('accepts the maximum batch size of ten calls', () => {
    const calls = Cl.list(
      Array.from({ length: 10 }, (_, index) => targetCall(wallet1, `call-${index + 1}`))
    );
    const { result } = batchCall(calls);

    expect(result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('rejects an eleven-item batch at the contract list boundary', () => {
    const calls = Cl.list(
      Array.from({ length: 11 }, (_, index) => targetCall(wallet1, `call-${index + 1}`))
    );

    expect(() => batchCall(calls)).toThrow(/batch-processor::batch-call/);
  });
});
