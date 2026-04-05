// scripts/protocol-fee-sweep.ts
// Plans (and optionally executes) protocol-fee sweeps by swapping SIP-010 balances via ALEX swap-helper.
//
// Usage (plan-only):
//   bun scripts/protocol-fee-sweep.ts --network mainnet --fee-vault SP... --target SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wxbtc-v2
//
// Usage (execute):
//   STX_PRIVATE_KEY=... bun scripts/protocol-fee-sweep.ts --network mainnet --fee-vault SP... --target SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wxbtc-v2 --execute

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  AnchorMode,
  ClarityType,
  type ClarityValue,
  contractPrincipalCV,
  someCV,
  uintCV,
  makeContractCall,
  broadcastTransaction,
  PostConditionMode,
  fetchCallReadOnlyFunction,
} from '@stacks/transactions';
import { networkFromName } from '@stacks/network';

type NetworkName = 'mainnet' | 'testnet';

type StacksNetwork = ReturnType<typeof networkFromName>;

type FungibleTokenBalancesResponse = {
  stx: unknown;
  fungible_tokens?: Record<
    string,
    {
      balance: string;
    }
  >;
};

type PrincipalParts = {
  address: string;
  contractName: string;
};

type SweepPlanItem = {
  token: string;
  dx: string;
  quotedDy: string;
  minDy: string;
};

type SkippedSweepItem = {
  token: string;
  dx: string;
  reason: string;
};

const modulePath = fileURLToPath(import.meta.url);

const DEFAULT_SWAP_HELPER = 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.swap-helper-v1-03';

const STACKS_NETWORK_PREFIXES: Record<NetworkName, readonly string[]> = {
  mainnet: ['SP', 'SM'],
  testnet: ['ST', 'SN'],
};

function parsePrincipal(principal: string): PrincipalParts {
  const trimmed = principal.trim();
  const dot = trimmed.indexOf('.');
  if (dot === -1 || dot === 0 || dot === trimmed.length - 1) {
    throw new Error(`Invalid principal: ${principal}`);
  }

  const address = trimmed.slice(0, dot);
  const contractName = trimmed.slice(dot + 1);
  return { address, contractName };
}

function parseUInt(argName: string, value: string): bigint {
  const trimmed = value.trim();
  if (!/^[0-9]+$/u.test(trimmed)) {
    throw new Error(`${argName} must be an integer (got: ${value})`);
  }
  return BigInt(trimmed);
}

function loadDotEnvIfPresent() {
  const moduleDir = dirname(modulePath);
  const searchDirs = [resolve(moduleDir, '..'), moduleDir, process.cwd()];

  const envPath = searchDirs
    .map((dir) => resolve(dir, '.env'))
    .find((candidate) => existsSync(candidate));

  if (!envPath) return;

  const fileText = readFileSync(envPath, 'utf8');
  for (const rawLine of fileText.split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;

    const eqIndex = line.indexOf('=');
    if (eqIndex === -1) continue;

    const key = line.slice(0, eqIndex).trim();
    if (!key) continue;

    let value = line.slice(eqIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

function requirePrivateKey(): string {
  const privateKey = process.env.STX_PRIVATE_KEY?.trim();

  if (
    !privateKey ||
    privateKey === 'CHANGEME' ||
    privateKey === 'your_private_key_here' ||
    privateKey === 'YOUR_PRIVATE_KEY' ||
    privateKey === '<your_stacks_private_key_here>'
  ) {
    throw new Error(
      'STX_PRIVATE_KEY is missing or still set to a placeholder value; please provide a real private key'
    );
  }

  return privateKey;
}

function usageAndExit(message?: string, exitCode: number = 1): never {
  if (message) {
    console.error(message);
    console.error('');
  }

  console.error(
    [
      'Usage:',
      '  bun scripts/protocol-fee-sweep.ts --network mainnet|testnet --fee-vault <standard-principal> --target <contract-principal> [options]',
      '',
      'Options:',
      '  --target <principal>        Target token contract (principal must be address.contract-name)',
      `  --swap-helper <principal>   Override swap-helper contract (principal must be address.contract-name; mainnet default: ${DEFAULT_SWAP_HELPER}; required on testnet)`,
      '  --allow <principal>         Repeatable. Only sweep these token contracts.',
      '  --min-dx <uint>             Skip balances below this (default: 0)',
      '  --max-dx <uint>             Cap per-token swap size (default: unlimited)',
      '  --slippage-bps <uint>       Slippage guard in basis points (default: 200)',
      '  --execute                   Broadcast swaps (requires STX_PRIVATE_KEY)',
      '',
      'Examples:',
      '  bun scripts/protocol-fee-sweep.ts --network mainnet --fee-vault SP... --target SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wxbtc-v2',
      '  STX_PRIVATE_KEY=... bun scripts/protocol-fee-sweep.ts --network mainnet --fee-vault SP... --target SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wxbtc-v2 --execute',
    ].join('\n')
  );

  process.exit(exitCode);
}

function assertStacksNetworkPrefix(networkName: NetworkName, flagName: string, principal: string) {
  const normalized = principal.trim();
  const prefixes: readonly string[] = STACKS_NETWORK_PREFIXES[networkName];
  if (!prefixes.some((prefix) => normalized.startsWith(prefix))) {
    usageAndExit(`On ${networkName}, ${flagName} must start with ${prefixes.join(' or ')}`);
  }
}

function createNetwork(networkName: NetworkName): StacksNetwork {
  return networkFromName(networkName);
}

function createApiBase(networkName: NetworkName): string {
  return networkName === 'mainnet' ? 'https://api.mainnet.hiro.so' : 'https://api.testnet.hiro.so';
}

function uintToBigInt(value: ClarityValue): bigint {
  if (value.type !== ClarityType.UInt) {
    throw new Error(`Expected uint, got ClarityType=${value.type}`);
  }
  return (value as { value: bigint }).value;
}

function responseUintToBigInt(value: ClarityValue): { ok: bigint } | { err: bigint } {
  if (value.type === ClarityType.ResponseOk) {
    const ok = (value as { value: ClarityValue }).value;
    return { ok: uintToBigInt(ok) };
  }

  if (value.type === ClarityType.ResponseErr) {
    const err = (value as { value: ClarityValue }).value;
    return { err: uintToBigInt(err) };
  }

  throw new Error(`Expected (response uint uint), got ClarityType=${value.type}`);
}

async function fetchFungibleTokenBalances(
  apiBase: string,
  feeVaultAddress: string
): Promise<Record<string, bigint>> {
  const res = await fetch(`${apiBase}/extended/v1/address/${feeVaultAddress}/balances`);

  if (!res.ok) {
    throw new Error(
      `Failed to fetch balances for ${feeVaultAddress}: ${res.status} ${res.statusText}`
    );
  }

  const json = (await res.json()) as FungibleTokenBalancesResponse;
  const fts = json.fungible_tokens ?? {};

  const out: Record<string, bigint> = {};
  for (const [assetIdentifier, token] of Object.entries(fts)) {
    const balance = token?.balance?.trim();
    if (!balance || balance === '0') continue;
    out[assetIdentifier] = BigInt(balance);
  }
  return out;
}

function assetIdentifierToTokenPrincipal(assetIdentifier: string): string {
  const parts = assetIdentifier.split('::');
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw new Error(`Unsupported asset identifier: ${assetIdentifier}`);
  }
  return parts[0];
}

async function quoteDy(
  network: StacksNetwork,
  swapHelper: PrincipalParts,
  feeVaultAddress: string,
  tokenX: PrincipalParts,
  tokenY: PrincipalParts,
  dx: bigint
): Promise<{ ok: bigint } | { err: bigint }> {
  const cv = await fetchCallReadOnlyFunction({
    contractAddress: swapHelper.address,
    contractName: swapHelper.contractName,
    functionName: 'get-helper',
    functionArgs: [
      contractPrincipalCV(tokenX.address, tokenX.contractName),
      contractPrincipalCV(tokenY.address, tokenY.contractName),
      uintCV(dx),
    ],
    senderAddress: feeVaultAddress,
    network,
  });

  return responseUintToBigInt(cv);
}

function computeMinDy(quotedDy: bigint, slippageBps: bigint): bigint {
  return (quotedDy * (10_000n - slippageBps)) / 10_000n;
}

async function buildSweepPlan(params: {
  apiBase: string;
  network: StacksNetwork;
  feeVaultAddress: string;
  swapHelper: PrincipalParts;
  target: PrincipalParts;
  allowlist: Set<string>;
  minDx: bigint;
  maxDx: bigint | null;
  slippageBps: bigint;
}): Promise<{ plan: SweepPlanItem[]; skipped: SkippedSweepItem[] }> {
  const balances = await fetchFungibleTokenBalances(params.apiBase, params.feeVaultAddress);

  const plan: SweepPlanItem[] = [];
  const skipped: SkippedSweepItem[] = [];
  const targetPrincipal = `${params.target.address}.${params.target.contractName}`;

  for (const [assetIdentifier, balance] of Object.entries(balances)) {
    const tokenPrincipal = assetIdentifierToTokenPrincipal(assetIdentifier);
    if (tokenPrincipal === targetPrincipal) continue;

    if (params.allowlist.size > 0 && !params.allowlist.has(tokenPrincipal)) continue;
    if (balance < params.minDx) continue;

    const dx = params.maxDx === null ? balance : balance < params.maxDx ? balance : params.maxDx;
    if (dx <= 0n) continue;

    const tokenX = parsePrincipal(tokenPrincipal);
    let quote: { ok: bigint } | { err: bigint };
    try {
      quote = await quoteDy(
        params.network,
        params.swapHelper,
        params.feeVaultAddress,
        tokenX,
        params.target,
        dx
      );
    } catch (err) {
      skipped.push({
        token: tokenPrincipal,
        dx: dx.toString(),
        reason: err instanceof Error ? err.message : String(err),
      });
      continue;
    }

    if ('err' in quote) {
      skipped.push({
        token: tokenPrincipal,
        dx: dx.toString(),
        reason: `swap-helper get-helper returned err=${quote.err.toString()}`,
      });
      continue;
    }

    if (quote.ok === 0n) {
      skipped.push({
        token: tokenPrincipal,
        dx: dx.toString(),
        reason: 'quoted dy is 0',
      });
      continue;
    }

    const minDy = computeMinDy(quote.ok, params.slippageBps);

    if (minDy <= 0n) {
      skipped.push({
        token: tokenPrincipal,
        dx: dx.toString(),
        reason: `minDy=${minDy.toString()} computed to a non-positive value; refusing to build swap`,
      });
      continue;
    }

    plan.push({
      token: tokenPrincipal,
      dx: dx.toString(),
      quotedDy: quote.ok.toString(),
      minDy: minDy.toString(),
    });
  }

  plan.sort((a, b) => a.token.localeCompare(b.token));
  skipped.sort((a, b) => a.token.localeCompare(b.token));
  return { plan, skipped };
}

async function executeSweepPlan(params: {
  network: StacksNetwork;
  feeVaultAddress: string;
  privateKey: string;
  swapHelper: PrincipalParts;
  target: PrincipalParts;
  plan: SweepPlanItem[];
}): Promise<void> {
  for (const item of params.plan) {
    const tokenX = parsePrincipal(item.token);
    const dx = BigInt(item.dx);
    const minDy = BigInt(item.minDy);

    if (minDy <= 0n) {
      throw new Error(
        `Refusing to execute swap with non-positive minDy for token ${item.token} (minDy=${item.minDy})`
      );
    }

    const txOptions = {
      contractAddress: params.swapHelper.address,
      contractName: params.swapHelper.contractName,
      functionName: 'swap-helper',
      functionArgs: [
        contractPrincipalCV(tokenX.address, tokenX.contractName),
        contractPrincipalCV(params.target.address, params.target.contractName),
        uintCV(dx),
        someCV(uintCV(minDy)),
      ],
      senderKey: params.privateKey,
      validateWithPostConditions: true,
      network: params.network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction({ transaction, network: params.network });

    console.log(
      JSON.stringify(
        {
          token: item.token,
          dx: item.dx,
          minDy: item.minDy,
          txid: broadcastResponse.txid,
          error: broadcastResponse.error,
          reason: broadcastResponse.reason,
        },
        null,
        2
      )
    );

    if ('error' in broadcastResponse) {
      throw new Error(
        `Transaction broadcast failed for token ${item.token}: ${broadcastResponse.error} (${broadcastResponse.reason})`
      );
    }
  }
}

async function main() {
  loadDotEnvIfPresent();

  const allowlist: Set<string> = new Set();
  let networkName: NetworkName | null = null;
  let feeVaultAddress: string | null = null;
  let targetPrincipal: string | null = null;
  let swapHelperPrincipal: string | null = null;
  let minDx = 0n;
  let maxDx: bigint | null = null;
  let slippageBps = 200n;
  let execute = false;

  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === '--network') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --network');
      const trimmed = raw.trim();
      if (trimmed !== 'mainnet' && trimmed !== 'testnet') usageAndExit(`Invalid --network: ${raw}`);
      networkName = trimmed;
      continue;
    }

    if (arg === '--fee-vault') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --fee-vault');
      const trimmed = raw.trim();
      if (!trimmed) usageAndExit('Missing value for --fee-vault');
      feeVaultAddress = trimmed;
      continue;
    }

    if (arg === '--target') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --target');
      const trimmed = raw.trim();
      if (!trimmed) usageAndExit('Missing value for --target');
      targetPrincipal = trimmed;
      continue;
    }

    if (arg === '--swap-helper') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --swap-helper');
      const trimmed = raw.trim();
      if (!trimmed) usageAndExit('Missing value for --swap-helper');
      swapHelperPrincipal = trimmed;
      continue;
    }

    if (arg === '--allow') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --allow');
      allowlist.add(raw.trim());
      continue;
    }

    if (arg === '--min-dx') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --min-dx');
      minDx = parseUInt('--min-dx', raw);
      continue;
    }

    if (arg === '--max-dx') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --max-dx');
      maxDx = parseUInt('--max-dx', raw);
      continue;
    }

    if (arg === '--slippage-bps') {
      const raw = argv[++i];
      if (!raw) usageAndExit('Missing value for --slippage-bps');
      slippageBps = parseUInt('--slippage-bps', raw);
      continue;
    }

    if (arg === '--execute') {
      execute = true;
      continue;
    }

    if (arg === '--help' || arg === '-h') {
      usageAndExit(undefined, 0);
    }

    usageAndExit(`Unknown argument: ${arg}`);
  }

  if (!networkName) usageAndExit('Missing required --network');
  if (!feeVaultAddress) usageAndExit('Missing required --fee-vault');
  if (!targetPrincipal) usageAndExit('Missing required --target');

  if (slippageBps >= 10_000n) {
    usageAndExit(`Invalid --slippage-bps=${slippageBps.toString()}; expected 0..9999`);
  }

  if (!swapHelperPrincipal) {
    if (networkName === 'mainnet') {
      swapHelperPrincipal = DEFAULT_SWAP_HELPER;
    } else {
      usageAndExit('Missing required --swap-helper for testnet (no safe default configured)');
    }
  }

  if (!swapHelperPrincipal.includes('.')) {
    usageAndExit('--swap-helper must be a contract principal (address.contract-name)');
  }

  assertStacksNetworkPrefix(networkName, '--swap-helper', swapHelperPrincipal);
  if (feeVaultAddress.includes('.')) {
    usageAndExit('--fee-vault must be a standard principal (address only, no contract name)');
  }

  if (!targetPrincipal.includes('.')) {
    usageAndExit('--target must be a contract principal (address.contract-name)');
  }

  assertStacksNetworkPrefix(networkName, '--fee-vault', feeVaultAddress);
  assertStacksNetworkPrefix(networkName, '--target', targetPrincipal);

  for (const allowed of allowlist) {
    if (!allowed.includes('.')) {
      usageAndExit('--allow must be a contract principal (address.contract-name)');
    }
    assertStacksNetworkPrefix(networkName, '--allow', allowed);
  }

  const network = createNetwork(networkName);
  const apiBase = createApiBase(networkName);

  const swapHelper = parsePrincipal(swapHelperPrincipal);
  const target = parsePrincipal(targetPrincipal);

  const { plan, skipped } = await buildSweepPlan({
    apiBase,
    network,
    feeVaultAddress,
    swapHelper,
    target,
    allowlist,
    minDx,
    maxDx,
    slippageBps,
  });

  console.log(
    JSON.stringify(
      { network: networkName, feeVaultAddress, target: targetPrincipal, plan, skipped },
      null,
      2
    )
  );

  if (!execute) return;

  const privateKey = requirePrivateKey();
  await executeSweepPlan({
    network,
    feeVaultAddress,
    privateKey,
    swapHelper,
    target,
    plan,
  });
}

const isMain = process.argv.slice(1).some((arg) => resolve(arg) === modulePath);

if (isMain) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
