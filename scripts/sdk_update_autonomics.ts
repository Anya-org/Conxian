#!/usr/bin/env ts-node
/**
 * Broadcast an update-autonomics call to the vault on Stacks testnet.
 * Requires environment variables:
 *  STACKS_PRIVKEY  (hex private key for the caller)
 *  VAULT_CONTRACT  (e.g. SPXXXXXXX.vault)
 *  NETWORK (optional, default testnet)
 */
import { makeContractCall, broadcastTransaction, standardPrincipalCV, uintCV, AnchorMode } from '@stacks/transactions';
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

  const res = await broadcastTransaction(tx, network);
  console.log(JSON.stringify(res, null, 2));
}

main().catch(e => { console.error(e); process.exit(1); });
