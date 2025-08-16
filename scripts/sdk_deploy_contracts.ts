#!/usr/bin/env ts-node
/**
 * Sequentially deploy all AutoVault contracts to Stacks testnet.
 * Environment variables required:
 *   DEPLOYER_PRIVKEY  - Hex private key for deployer (testnet)
 *   NETWORK (optional, default: testnet)
 * Optional:
 *   CONTRACT_FILTER   - Comma-separated list of contract names to deploy (subset)
 * Output:
 *   deployment-registry-testnet.json updated/created with deployed txids + block heights (polled).
 */
import { makeContractDeploy, broadcastTransaction, AnchorMode, getAddressFromPrivateKey } from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';
import fs from 'fs';
import path from 'path';
import fetch from 'node-fetch';
import 'dotenv/config';

interface DeployedMeta { txid: string; contractId?: string; height?: number; status?: string }

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STACKS_DIR = path.join(PROJECT_ROOT, 'stacks');
const CONTRACTS_DIR = path.join(STACKS_DIR, 'contracts');

const ORDER = [
  'sip-010-trait',
  'strategy-trait',
  'vault-admin-trait',
  'vault-trait',
  'mock-ft',
  'gov-token',
  'treasury',
  'vault',
  'timelock',
  'dao',
  'dao-governance',
  'analytics',
  'registry',
  'bounty-system',
  'creator-token',
  // Newly added previously omitted deployable contracts
  'dao-automation',
  'avg-token',
  'avlp-token'
];

async function pollTx(txid: string, network: any, timeoutMs = 120000): Promise<{height?: number; status: string}> {
  const base = (network.coreApiUrl as string).replace(/\/$/, '');
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const r = await fetch(`${base}/extended/v1/tx/${txid}`);
      if (r.ok) {
        const j: any = await r.json();
        if (j.tx_status === 'success' || j.tx_status === 'abort_by_response') {
          return { height: j.block_height, status: j.tx_status };
        }
        if (j.tx_status === 'pending') {
          await new Promise(r => setTimeout(r, 3000));
          continue;
        }
        return { height: j.block_height, status: j.tx_status };
      }
    } catch (_) {}
    await new Promise(r => setTimeout(r, 3000));
  }
  return { status: 'timeout' };
}

async function deployOne(name: string, privKey: string, network: any) {
  const file = path.join(CONTRACTS_DIR, `${name}.clar`);
  if (!fs.existsSync(file)) throw new Error(`Missing contract file for ${name}`);
  const source = fs.readFileSync(file, 'utf8');
  const tx = await makeContractDeploy({
    codeBody: source,
    contractName: name,
    senderKey: privKey,
    network,
    anchorMode: AnchorMode.Any,
  });
  const res: any = await broadcastTransaction(tx, network);
  const txid = res.txid || res.transaction_hash;
  if (!txid) throw new Error(`No txid returned for ${name}: ${JSON.stringify(res)}`);
  console.log(`[broadcast] ${name} -> ${txid}`);
  const polled = await pollTx(txid, network);
  console.log(`[status] ${name} -> ${polled.status} height=${polled.height ?? '-'} `);
  return { txid, status: polled.status, height: polled.height } as DeployedMeta;
}

async function main() {
  const priv = process.env.DEPLOYER_PRIVKEY;
  if (!priv) throw new Error('DEPLOYER_PRIVKEY env required');
  const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
  const network = networkName === 'mainnet' ? new StacksMainnet() : new StacksTestnet();
  // Preflight: derive address & check balance
  const deployerAddress = getAddressFromPrivateKey(priv, networkName === 'mainnet' ? 'mainnet' : 'testnet');
  console.log(`[preflight] Deployer address: ${deployerAddress}`);
  const balanceOk = await checkBalance(network, deployerAddress, 200000); // 0.0002 STX minimum (adjust as needed)
  if (!balanceOk) {
    console.error('[abort] Insufficient STX balance for deployment. Fund address then re-run.');
    process.exit(1);
  }

  const filterRaw = process.env.CONTRACT_FILTER;
  let list = ORDER;
  if (filterRaw) {
    const allowed = new Set(filterRaw.split(',').map(s => s.trim()));
    list = ORDER.filter(n => allowed.has(n));
  }

  console.log(`Deploying ${list.length} contracts to ${networkName}...`);
  const registryPath = path.join(PROJECT_ROOT, 'deployment-registry-testnet.json');
  let registry: any = fs.existsSync(registryPath) ? JSON.parse(fs.readFileSync(registryPath, 'utf8')) : {};

  // Preserve existing structured fields if present
  registry.network = registry.network || networkName;
  registry.deployment_order = registry.deployment_order || ORDER;
  registry.contracts = registry.contracts || {};

  for (const name of list) {
    if (registry.contracts?.[name]?.txid) {
      console.log(`[skip] ${name} already recorded. Use CONTRACT_FILTER to force redeploy.`);
      continue;
    }
    const meta = await deployOne(name, priv, network);
    registry.contracts[name] = { ...(registry.contracts[name] || {}), ...meta };
    registry.timestamp_last_deploy = new Date().toISOString();
    fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2));
  }
  console.log('Deployment complete. Registry saved at deployment-registry-testnet.json');
}

async function checkBalance(network: any, address: string, minMicroStx: number): Promise<boolean> {
  const base = (network.coreApiUrl as string).replace(/\/$/, '');
  try {
    const r = await fetch(`${base}/extended/v1/address/${address}/balances`);
    if (!r.ok) {
      console.warn(`[warn] Balance query failed status=${r.status}`);
      return false;
    }
    const j: any = await r.json();
    const bal = Number(j.stx?.balance || 0);
    console.log(`[preflight] STX balance: ${bal} microstx`);
    return bal >= minMicroStx;
  } catch (e) {
    console.warn('[warn] Balance check error:', (e as Error).message);
    return false;
  }
}

main().catch(e => { console.error(e); process.exit(1); });
