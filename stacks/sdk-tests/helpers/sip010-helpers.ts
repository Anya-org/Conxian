import { Cl } from '@stacks/transactions';
import type { Simnet, Account } from '@hirosystems/clarinet-sdk';

// SIP-010 helpers for Vault tests
export function principals(simnet: Simnet) {
  const accounts = simnet.getAccounts();
  const deployer = accounts.get('deployer')!;
  return {
    deployer,
    vault: `${deployer}.vault`,
    timelock: `${deployer}.timelock`,
    mockFt: `${deployer}.mock-ft`,
    avg: `${deployer}.avg-token`,
  };
}

export function contract(token: string, deployer: Account) {
  return Cl.contractPrincipal(deployer, token);
}

export function mine(simnet: Simnet, blocks = 1) {
  for (let i = 0; i < blocks; i++) simnet.mineBlock([]);
}

export function mintMock(simnet: Simnet, to: string, amount: number | bigint, admin: Account) {
  return simnet.callPublicFn('mock-ft', 'mint', [Cl.principal(to), Cl.uint(amount)], admin);
}

export function approve(simnet: Simnet, tokenName: 'mock-ft' | 'avg-token', owner: Account, spender: string, amount: number | bigint) {
  return simnet.callPublicFn(tokenName, 'approve', [Cl.principal(spender), Cl.uint(amount)], owner);
}

export function queueSetPaused(simnet: Simnet, paused: boolean, admin: Account) {
  return simnet.callPublicFn('timelock', 'queue-set-paused', [Cl.bool(paused)], admin);
}

export function executeSetPaused(simnet: Simnet, id: bigint | number, admin: Account) {
  return simnet.callPublicFn('timelock', 'execute-set-paused', [Cl.uint(id)], admin);
}

export function queueSetToken(simnet: Simnet, tokenPrincipal: string, admin: Account) {
  return simnet.callPublicFn('timelock', 'queue-set-token', [Cl.principal(tokenPrincipal)], admin);
}

export function executeSetToken(simnet: Simnet, id: bigint | number, admin: Account) {
  return simnet.callPublicFn('timelock', 'execute-set-token', [Cl.uint(id)], admin);
}

export function getMinDelay(simnet: Simnet) {
  return simnet.callReadOnlyFn('timelock', 'get-min-delay', [], simnet.getAccounts().get('deployer')!);
}

export function getVaultTotals(simnet: Simnet, caller?: Account) {
  const who = caller ?? simnet.getAccounts().get('deployer')!;
  const tb = simnet.callReadOnlyFn('vault', 'get-total-balance', [], who);
  const ts = simnet.callReadOnlyFn('vault', 'get-total-shares', [], who);
  return { tb, ts };
}

export function getVaultShare(simnet: Simnet, whoP: string, caller?: Account) {
  const who = caller ?? simnet.getAccounts().get('deployer')!;
  return simnet.callReadOnlyFn('vault', 'get-shares', [Cl.principal(whoP)], who);
}

export function getVaultReserves(simnet: Simnet, caller?: Account) {
  const who = caller ?? simnet.getAccounts().get('deployer')!;
  const tres = simnet.callReadOnlyFn('vault', 'get-treasury-reserve', [], who);
  const pres = simnet.callReadOnlyFn('vault', 'get-protocol-reserve', [], who);
  return { tres, pres };
}

export function setVaultTokenViaTimelock(simnet: Simnet, tokenPrincipal: string) {
  const { deployer } = principals(simnet);
  const qPause = queueSetPaused(simnet, true, deployer);
  // Clarinet SDK 3.5.0 exposes results as { type, value }
  const idPause = (qPause.result as any).value.value;
  const delay = (getMinDelay(simnet).result as any).value as bigint;
  mine(simnet, Number(delay));
  executeSetPaused(simnet, idPause, deployer);

  const qTok = queueSetToken(simnet, tokenPrincipal, deployer);
  const idTok = (qTok.result as any).value.value;
  mine(simnet, Number(delay));
  executeSetToken(simnet, idTok, deployer);

  const qUnpause = queueSetPaused(simnet, false, deployer);
  const idUnpause = (qUnpause.result as any).value.value;
  mine(simnet, Number(delay));
  executeSetPaused(simnet, idUnpause, deployer);
}
