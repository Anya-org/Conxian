#!/usr/bin/env ts-node
/** Post-deploy verification: read-only assertions across key contracts. */
import { callReadOnlyFunction, cvToValue } from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';
import 'dotenv/config';

const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
const network = networkName === 'mainnet' ? new StacksMainnet() : new StacksTestnet();

const DEPLOYER = process.env.DEPLOYER_ADDR || 'SP000000000000000000002Q6VF78'; // placeholder
const CONTRACTS = {
  vault: `${DEPLOYER}.vault`,
  timelock: `${DEPLOYER}.timelock`,
  dao: `${DEPLOYER}.dao`,
  gov: `${DEPLOYER}.CXVG`,
};

async function ro(addr: string, name: string, fn: string) {
  const [contractAddress, contractName] = addr.split('.');
  const resp = await callReadOnlyFunction({
    contractAddress,
    contractName,
    functionName: fn,
    functionArgs: [],
    network,
    senderAddress: contractAddress,
  });
  return cvToValue(resp); // simple conversion
}

async function main() {
  const results: any = {};
  results.vault_admin = await ro(CONTRACTS.vault, 'vault', 'get-admin');
  results.vault_fees = await ro(CONTRACTS.vault, 'vault', 'get-fees');
  results.treasury = await ro(CONTRACTS.vault, 'vault', 'get-treasury');
  // Simple checks
  const assertions: string[] = [];
  if (!results.vault_admin.ok) assertions.push('vault admin missing ok');
  console.log(JSON.stringify({ results, assertions }, null, 2));
  if (assertions.length) process.exit(1);
}

main().catch(e => { console.error(e); process.exit(1); });
