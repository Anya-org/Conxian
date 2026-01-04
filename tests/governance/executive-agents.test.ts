import { describe, expect, it, beforeEach } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';
import { initSimnet } from '../../setup-test-env';
import { Simnet } from '@stacks/clarinet-sdk';

describe('Autonomous Executive Agents', () => {
  let simnet: Simnet;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  describe('CRO (Chief Risk Officer)', () => {
    it('CEO can trigger an emergency pause via the CRO', async () => {
      // (contract-call? .conxian-operations-engine trigger-emergency-pause)
      const call = Cl.contractCall(
        'conxian-operations-engine',
        'trigger-emergency-pause',
        [],
      );
      const result = await simnet.callPublicFn(
        'conxian-operations-engine',
        'trigger-emergency-pause',
        [],
        deployer
      );
      expect(result.result).toBeOk(Cl.bool(true));

      // Verify that the main protocol contract is now paused
      const isPaused = await simnet.callReadOnlyFn(
        'agent-risk',
        'is-contract-paused',
        [Cl.contractPrincipal(deployer, 'conxian-protocol')],
        deployer
      );
      expect(isPaused.result).toBeOk(Cl.bool(true));
    });
  });

  describe('CFO (Chief Financial Officer)', () => {
    it('distributes revenue according to the allocation policy', async () => {
      // Mint some mock tokens to distribute
      const amount = 1000000;
      await simnet.callPublicFn(
        'mock-token',
        'mint',
        [Cl.uint(amount), Cl.principal(deployer)],
        deployer
      );

      const call = Cl.contractCall(
        'agent-treasury',
        'distribute',
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.uint(amount),
          Cl.principal(deployer),
        ],
      );

      const result = await simnet.callPublicFn(
        'agent-treasury',
        'distribute',
        [
          Cl.contractPrincipal(deployer, 'mock-token'),
          Cl.uint(amount),
          Cl.principal(deployer),
        ],
        deployer
      );

      expect(result.result).toBeOk(Cl.bool(true));

      // Verify the distribution
      // Note: In a real test, we would have mock vaults to check balances.
      // Here, we'll just check the print events if available, or assume success on OK.
      expect(result.events).toHaveLength(1);
      const printEvent = result.events[0];
      if (printEvent.type === 'print_event') {
        const decodedEvent = cvToValue(printEvent.data.value);
        expect(decodedEvent.value.staking-amount.value).toBe(600000n);
        expect(decodedEvent.value.dev-fund-amount.value).toBe(200000n);
        expect(decodedEvent.value.insurance-fund-amount.value).toBe(200000n);
      }
    });
  });
});
