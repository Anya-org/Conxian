#!/usr/bin/env ts-node
/**
 * Broadcast an update-autonomics call to the vault on Stacks testnet.
 * Requires environment variables:
 *  STACKS_PRIVKEY  (hex private key for the caller)
 *  VAULT_CONTRACT  (e.g. SPXXXXXXX.vault)
 *  NETWORK (optional, default testnet)
 */
import { makeContractCall, broadcastTransaction, AnchorMode } from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';
import 'dotenv/config';

async function main() {
  const privKey = process.env.STACKS_PRIVKEY;
  const vault = process.env.VAULT_CONTRACT; // SP....vault
  if (!privKey) throw new Error('STACKS_PRIVKEY required');
  if (!vault) throw new Error('VAULT_CONTRACT required');
  const [contractAddress, contractName] = vault.split('.');
  if (!contractAddress || !contractName) throw new Error('VAULT_CONTRACT malformed');

  const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
  const network = networkName === 'mainnet' ? new StacksMainnet() : new StacksTestnet();

  const tx = await makeContractCall({
    contractAddress,
    contractName,
    functionName: 'update-autonomics',
    functionArgs: [],
    senderKey: privKey,
    validateWithAbi: false,
    network,
    anchorMode: AnchorMode.Any,
  });
  const serialized = tx.serialize().toString('hex');

  let attempt = 0; let lastErr: any = null; let result: any = null;
  while (attempt < 3) {
    try {
      result = await broadcastTransaction(tx, network);
      break;
    } catch (e) {
      lastErr = e;
      attempt++;
      await new Promise(r => setTimeout(r, 1000 * attempt));
    }
  }
  if (!result) {
    throw new Error(`Broadcast failed after retries: ${lastErr}`);
  }
  const txid = (result as any).txid || (result as any).transaction_hash || 'unknown';
  console.log(JSON.stringify({
    txid,
    contract: vault,
    attempts: attempt + 1,
    raw_tx: serialized,
    network: networkName,
    response: result,
  }, null, 2));
}

main().catch(e => { console.error(e); process.exit(1); });
