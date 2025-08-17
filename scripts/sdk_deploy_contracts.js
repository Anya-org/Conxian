#!/usr/bin/env node
/**
 * Sequential deployment of AutoVault contracts (JS version).
 * Env:
 *   DEPLOYER_PRIVKEY   (hex) required unless DRY_RUN
 *   NETWORK=testnet|mainnet (default testnet)
 *   CONTRACT_FILTER=comma,list (subset optional)
 *   DRY_RUN=1 (simulate: build tx objects but no broadcast)
 */
const path = require('path');
const fs = require('fs');

let stacksTx, stacksNet;
try {
  stacksTx = require('@stacks/transactions');
  stacksNet = require('@stacks/network');
} catch (e) {
  const altBase = path.resolve(__dirname, '../stacks/node_modules/@stacks');
  try {
    stacksTx = require(path.join(altBase, 'transactions'));
    stacksNet = require(path.join(altBase, 'network'));
  } catch (e2) {
    console.error('Failed to load @stacks modules. Install dependencies first.');
    process.exit(1);
  }
}
const { makeContractDeploy, broadcastTransaction, AnchorMode, getAddressFromPrivateKey } = stacksTx;
const { networkFromName } = stacksNet;

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STACKS_DIR = path.join(PROJECT_ROOT, 'stacks');
const CONTRACTS_DIR = path.join(STACKS_DIR, 'contracts');

const ORDER = [
  'sip-010-trait','strategy-trait','vault-admin-trait','vault-trait','mock-ft','gov-token','treasury','vault','timelock','dao','dao-governance','analytics','registry','bounty-system','creator-token','dao-automation','avg-token','avlp-token'
];

async function sleep(ms){return new Promise(r=>setTimeout(r,ms));}

function getCoreApiBase(network){
  // Support multiple library shapes: legacy network.coreApiUrl or v7 network.client.baseUrl
  const url = network.coreApiUrl || network.client?.baseUrl || process.env.CORE_API_URL;
  if(!url) throw new Error('Unable to determine core API URL (set CORE_API_URL env)');
  return url.replace(/\/$/,'');
}

async function pollTx(txid, network, timeoutMs=120000){
  const base = getCoreApiBase(network);
  const start = Date.now();
  while(Date.now()-start < timeoutMs){
    try {
      const r = await fetch(`${base}/extended/v1/tx/${txid}`);
      if (r.ok){
        const j = await r.json();
        if (j.tx_status === 'success' || j.tx_status === 'abort_by_response') return {height:j.block_height,status:j.tx_status};
        if (j.tx_status === 'pending'){ await sleep(3000); continue; }
        return {height:j.block_height,status:j.tx_status};
      }
    } catch {}
    await sleep(3000);
  }
  return {status:'timeout'};
}

async function deployOne(name, privKey, network, dryRun){
  let file = path.join(CONTRACTS_DIR, `${name}.clar`);
  if (!fs.existsSync(file)) {
    // try traits subdir
    const alt = path.join(CONTRACTS_DIR, 'traits', `${name}.clar`);
    if (fs.existsSync(alt)) file = alt; else throw new Error(`Missing contract file for ${name}`);
  }
  const source = fs.readFileSync(file,'utf8');
  const tx = await makeContractDeploy({ codeBody: source, contractName: name, senderKey: privKey, network, anchorMode: AnchorMode.Any });
  if (dryRun){ console.log(`[dry-run] built ${name}`); return {txid:'dry-run',status:'dry-run'}; }
  const res = await broadcastTransaction(tx, network);
  const txid = res.txid || res.transaction_hash;
  if(!txid) throw new Error(`No txid returned for ${name}: ${JSON.stringify(res)}`);
  console.log(`[broadcast] ${name} -> ${txid}`);
  const polled = await pollTx(txid, network);
  console.log(`[status] ${name} -> ${polled.status} height=${polled.height ?? '-'}`);
  return { txid, status: polled.status, height: polled.height };
}

async function checkBalance(network,address,minMicro){
  const base = getCoreApiBase(network);
  try {
    const r = await fetch(`${base}/extended/v1/address/${address}/balances`);
    if(!r.ok){ console.warn(`[warn] balance query failed status=${r.status}`); return false; }
    const j = await r.json();
    const bal = Number(j.stx?.balance || 0);
    console.log(`[preflight] STX balance: ${bal} microstx`);
    return bal >= minMicro;
  } catch(e){ console.warn('[warn] balance check error:', e.message); return false; }
}

async function main(){
  const dryRun = !!process.env.DRY_RUN;
  const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
  const network = networkFromName(networkName);
  let priv = process.env.DEPLOYER_PRIVKEY;
  if(!priv){ if(dryRun){ priv = '00'.repeat(32);} else { throw new Error('DEPLOYER_PRIVKEY required'); } }
  const deployerAddress = getAddressFromPrivateKey(priv, networkName==='mainnet' ? 'mainnet':'testnet');
  console.log(`[preflight] deployer address: ${deployerAddress}`);
  if(!dryRun){ const ok = await checkBalance(network,deployerAddress,200000); if(!ok){ console.error('[abort] insufficient STX balance'); process.exit(1);} } else { console.log('[dry-run] skipping balance check'); }

  const filterRaw = process.env.CONTRACT_FILTER;
  let list = ORDER;
  if(filterRaw){ const allowed = new Set(filterRaw.split(',').map(s=>s.trim())); list = ORDER.filter(n=>allowed.has(n)); }

  console.log(`Deploying ${list.length} contracts to ${networkName}${dryRun?' (dry-run)':''}`);
  const registryPath = path.join(PROJECT_ROOT,'deployment-registry-testnet.json');
  let registry = fs.existsSync(registryPath) ? JSON.parse(fs.readFileSync(registryPath,'utf8')) : {};
  registry.network = registry.network || networkName;
  registry.deployment_order = registry.deployment_order || ORDER;
  registry.contracts = registry.contracts || {};

  registry.deployer_address = deployerAddress;
  for (const name of list){
    const existing = registry.contracts?.[name];
    const existingTx = existing?.txid;
    if (!dryRun && existingTx && existingTx !== 'dry-run' && existingTx !== '<pending>') {
      console.log(`[skip] ${name} already deployed (txid=${existingTx})`);
      continue;
    }
    const meta = await deployOne(name, priv, network, dryRun);
    registry.contracts[name] = { ...(existing||{}), ...meta, contract_id: `${deployerAddress}.${name}` };
    registry.timestamp_last_deploy = new Date().toISOString();
    fs.writeFileSync(registryPath, JSON.stringify(registry,null,2));
  }
  console.log('Deployment complete. Registry saved at deployment-registry-testnet.json');
}

main().catch(e=>{ console.error(e); process.exit(1); });
