// scripts/register-sbcs.ts
// Codifies core Sovereign Business Cells (SBC) in fiscal-intelligence.clar
import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  stringAsciiCV,
} from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

const network = new StacksTestnet();
const privateKey = 'YOUR_PRIVATE_KEY'; // To be sourced from BOS Secrets

const sbcs = ["Conxian-Core", "Nexus-Labs", "Fiscal-Auth", "Sovereign-Ops"];

async function registerSBCs() {
  for (const sbc of sbcs) {
    const txOptions = {
      contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
      contractName: 'fiscal-intelligence',
      functionName: 'codify-sbc',
      functionArgs: [stringAsciiCV(sbc)],
      senderKey: privateKey,
      validateWithPostConditions: true,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    console.log(`Registering SBC: ${sbc} - TX ID: ${broadcastResponse.txid}`);
  }
}

registerSBCs().catch(console.error);
