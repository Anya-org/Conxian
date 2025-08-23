import { Cl } from '@stacks/transactions';
import type { Simnet } from '@hirosystems/clarinet-sdk';

export class RouterSDK {
  constructor(private simnet: Simnet, private deployer: string) {}

  // Resolve pool principal from dex-factory for a token pair (order-insensitive)
  resolvePool(tokenX: string, tokenY: string): string | null {
    const res1 = this.simnet.callReadOnlyFn('dex-factory', 'get-pool', [
      Cl.principal(tokenX),
      Cl.principal(tokenY)
    ], this.deployer);
    if (res1.type === 'some') return res1.value.value as string;

    const res2 = this.simnet.callReadOnlyFn('dex-factory', 'get-pool', [
      Cl.principal(tokenY),
      Cl.principal(tokenX)
    ], this.deployer);
    if (res2.type === 'some') return res2.value.value as string;

    return null;
  }

  // Add liquidity via router direct API
  addLiquidity(pool: string, dx: bigint, dy: bigint, minShares: bigint, deadline: bigint, sender?: string) {
    return this.simnet.callPublicFn('dex-router', 'add-liquidity-direct', [
      toContractPrincipal(pool),
      Cl.uint(dx),
      Cl.uint(dy),
      Cl.uint(minShares),
      Cl.uint(deadline)
    ], sender ?? this.deployer);
  }

  // Swap exact-in via router direct API
  swapExactIn(pool: string, amountIn: bigint, minOut: bigint, xToY: boolean, deadline: bigint, sender?: string) {
    return this.simnet.callPublicFn('dex-router', 'swap-exact-in-direct', [
      toContractPrincipal(pool),
      Cl.uint(amountIn),
      Cl.uint(minOut),
      Cl.bool(xToY),
      Cl.uint(deadline)
    ], sender ?? this.deployer);
  }

  // Quote via router direct API
  getAmountOut(pool: string, amountIn: bigint, xToY: boolean) {
    return this.simnet.callPublicFn('dex-router', 'get-amount-out-direct', [
      toContractPrincipal(pool),
      Cl.uint(amountIn),
      Cl.bool(xToY)
    ], this.deployer);
  }
}

function toContractPrincipal(qualified: string) {
  const [addr, name] = qualified.split('.');
  return Cl.contractPrincipal(addr, name);
}
