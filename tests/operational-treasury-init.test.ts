import { beforeAll, describe, expect, it } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

const TREASURY = 'operational-treasury';
const ERR_UNAUTHORIZED = 1000;
const ERR_TREASURY_NOT_INITIALIZED = 4118;

describe('Operational treasury initialization custody', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let treasuryPrincipal: string;

  const stxBalance = (principal: string): bigint =>
    simnet.getAssetsMap().get('STX')?.get(principal) ?? 0n;

  const mockTokenBalance = (principal: string): bigint => {
    const result: any = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(principal)],
      deployer,
    ).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    wallet2 = simnet.getAccounts().get('wallet_2')!;
    treasuryPrincipal = `${deployer}.${TREASURY}`;
  });

  it('rejects an unauthorized first initializer before ownership can be captured', () => {
    expect(simnet.callPublicFn(
      TREASURY,
      'initialize',
      [Cl.principal(wallet2)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));

    expect(simnet.callReadOnlyFn(TREASURY, 'get-contract-owner', [], deployer).result)
      .toEqual(Cl.principal(deployer));
    expect(simnet.callReadOnlyFn(TREASURY, 'is-initialized', [], deployer).result)
      .toEqual(Cl.bool(false));
    expect(simnet.callPublicFn(
      'protocol-fee-collector',
      'route-stx',
      [Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_TREASURY_NOT_INITIALIZED)));
  });

  it('allows the publish-time owner to initialize and preserves withdrawal custody', () => {
    expect(simnet.callPublicFn(
      TREASURY,
      'initialize',
      [Cl.principal(wallet2)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(TREASURY, 'get-contract-owner', [], deployer).result)
      .toEqual(Cl.principal(wallet2));
    expect(simnet.callReadOnlyFn(TREASURY, 'is-initialized', [], deployer).result)
      .toEqual(Cl.bool(true));

    simnet.mintSTX(wallet1, 1_000n);
    expect(simnet.callPublicFn(
      TREASURY,
      'deposit-stx',
      [Cl.uint(1_000)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const wallet1Before = stxBalance(wallet1);
    expect(simnet.callPublicFn(
      TREASURY,
      'withdraw-stx',
      [Cl.uint(100), Cl.principal(wallet1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callPublicFn(
      TREASURY,
      'withdraw-stx',
      [Cl.uint(100), Cl.principal(wallet1)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(stxBalance(wallet1)).toBe(wallet1Before + 100n);

    expect(simnet.callPublicFn(
      'mock-token',
      'mint',
      [Cl.uint(500), Cl.principal(treasuryPrincipal)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const tokenBefore = mockTokenBalance(wallet1);
    expect(simnet.callPublicFn(
      TREASURY,
      'withdraw-token',
      [
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(125),
        Cl.principal(wallet1),
      ],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(mockTokenBalance(wallet1)).toBe(tokenBefore + 125n);
  });
});
