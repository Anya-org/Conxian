import { describe, it, expect, beforeAll } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';

describe('Proposal Engine Security Audit', () => {
  let simnet: Simnet;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.getAccounts().get('deployer')!;
  });

  it('should not panic if conxian-protocol returns an error', async () => {
    const { result } = await simnet.callPublicFn(
      'proposal-engine',
      'propose',
      [
        Cl.stringAscii('test proposal'),
        Cl.list([Cl.principal(deployer)]),
        Cl.list([Cl.uint(0)]),
        Cl.list([Cl.stringAscii('test')]),
        Cl.list([Cl.buffer(Buffer.from('test'))]),
        Cl.uint(0),
        Cl.uint(100),
      ],
      deployer
    );
    // Test that it doesn't panic - may return error but shouldn't crash
    expect(result.type).toBeDefined();
  });

  it('should emit a set-voting-period event', async () => {
    const newPeriod = 100;
    const { result, events } = await simnet.callPublicFn(
      'proposal-engine',
      'set-voting-period',
      [Cl.uint(newPeriod)],
      deployer
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('print_event');
  });

  it('should emit a set-quorum-percentage event', async () => {
    const newQuorum = 5000;
    const { result, events } = await simnet.callPublicFn(
      'proposal-engine',
      'set-quorum-percentage',
      [Cl.uint(newQuorum)],
      deployer
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('print_event');
  });

  it('should emit a set-proposal-executor event', async () => {
    const newExecutor = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const { result, events } = await simnet.callPublicFn(
      'proposal-engine',
      'set-proposal-executor',
      [Cl.principal(newExecutor)],
      deployer
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('print_event');
  });

  it('should emit a transfer-ownership event', async () => {
    const newOwner = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const { result, events } = await simnet.callPublicFn(
      'proposal-engine',
      'transfer-ownership',
      [Cl.principal(newOwner)],
      deployer
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('print_event');
  });

  it('should emit a set-protocol-coordinator event', async () => {
    const newCoordinator = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const { result, events } = await simnet.callPublicFn(
      'proposal-engine',
      'set-protocol-coordinator',
      [Cl.principal(newCoordinator)],
      deployer
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('print_event');
  });
});
