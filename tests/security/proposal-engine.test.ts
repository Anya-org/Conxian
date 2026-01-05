
import { describe, it, expect, beforeEach } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';
import { NativeClarityBinProvider, TestProvider } from '@stacks/clarinet-sdk/vitest';

describe('Proposal Engine Security Audit', () => {
  let provider: NativeClarityBinProvider;
  let testProvider: TestProvider;
  let deployer: string;
  let contractAddress: string;

  beforeEach(async () => {
    provider = await NativeClarityBinProvider.create();
    testProvider = await TestProvider.fromProvider(provider);
    deployer = (await provider.getAccounts())[0];
    contractAddress = `${deployer}.proposal-engine`;
  });

  it('should not panic if conxian-protocol returns an error', async () => {
    await testProvider.deployContract(
      'conxian-protocol',
      `
      (define-public (is-protocol-paused)
        (err u500)
      )
    `,
      [],
      deployer,
    );

    const { result } = await testProvider.tx(
      {
        contractAddress,
        sender: deployer,
        functionName: 'propose',
        args: [
          Cl.stringAscii('test proposal'),
          Cl.list([Cl.principal(deployer)]),
          Cl.list([Cl.uint(0)]),
          Cl.list([Cl.stringAscii('test')]),
          Cl.list([Cl.buffer(Buffer.from('test'))]),
          Cl.uint(0),
          Cl.uint(100),
        ],
      },
      'proposal-engine',
    );
    expect(result).toBeErr(Cl.uint(5001));
  });

  it('should emit a set-voting-period event', async () => {
    const newPeriod = 100;
    const { events } = await testProvider.tx(
      {
        contractAddress,
        sender: deployer,
        functionName: 'set-voting-period',
        args: [Cl.uint(newPeriod)],
      },
      'proposal-engine',
    );
    expect(events).toHaveLength(1);
    expect(events[0].eventName).toBe('set-voting-period');
  });

  it('should emit a set-quorum-percentage event', async () => {
    const newQuorum = 5000;
    const { events } = await testProvider.tx(
      {
        contractAddress,
        sender: deployer,
        functionName: 'set-quorum-percentage',
        args: [Cl.uint(newQuorum)],
      },
      'proposal-engine',
    );
    expect(events).toHaveLength(1);
    expect(events[0].eventName).toBe('set-quorum-percentage');
  });

  it('should emit a set-proposal-executor event', async () => {
    const newExecutor = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const { events } = await testProvider.tx(
      {
        contractAddress,
        sender: deployer,
        functionName: 'set-proposal-executor',
        args: [Cl.principal(newExecutor)],
      },
      'proposal-engine',
    );
    expect(events).toHaveLength(1);
    expect(events[0].eventName).toBe('set-proposal-executor');
  });

  it('should emit a transfer-ownership event', async () => {
    const newOwner = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const { events } = await testProvider.tx(
      {
        contractAddress,
        sender: deployer,
        functionName: 'transfer-ownership',
        args: [Cl.principal(newOwner)],
      },
      'proposal-engine',
    );
    expect(events).toHaveLength(1);
    expect(events[0].eventName).toBe('transfer-ownership');
  });

  it('should emit a set-protocol-coordinator event', async () => {
    const newCoordinator = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const { events } = await testProvider.tx(
      {
        contractAddress,
        sender: deployer,
        functionName: 'set-protocol-coordinator',
        args: [Cl.principal(newCoordinator)],
      },
      'proposal-engine',
    );
    expect(events).toHaveLength(1);
    expect(events[0].eventName).toBe('set-protocol-coordinator');
  });
});
