/**
 * ConxianCSF Testnet Deployment Script
 * Deploys all CSF contracts to Stacks testnet in the correct dependency order
 */
import "dotenv/config";
import { makeContractDeploy, broadcastTransaction } from "@stacks/transactions";
import { STACKS_TESTNET } from "@stacks/network";
import { readFileSync } from "fs";
import { join } from "path";

const DEPLOYER_PRIVKEY = process.env.DEPLOYER_PRIVKEY!;
const CORE_API_URL = process.env.CORE_API_URL || "https://api.testnet.hiro.so";
const HIRO_API_KEY = process.env.HIRO_API_KEY;

const network = { ...STACKS_TESTNET, coreApiUrl: CORE_API_URL };
const apiHeaders: Record<string, string> = {};
if (HIRO_API_KEY) apiHeaders["x-hiro-api-key"] = HIRO_API_KEY;

// CSF Deployment sequence: traits → core → oracle → tokens → security → dex → agents
const DEPLOYMENT_SEQUENCE = [
  // Phase 1: Traits
  { name: "sip-standards", path: "contracts/traits/sip-standards.clar" },
  { name: "core-traits", path: "contracts/traits/core-traits.clar" },
  { name: "security-monitoring", path: "contracts/traits/security-monitoring.clar" },
  { name: "automation-traits", path: "contracts/traits/automation-traits.clar" },
  { name: "conxian-service-trait", path: "contracts/traits/conxian-service-trait.clar" },
  { name: "defi-traits", path: "contracts/traits/defi-traits.clar" },
  { name: "conxian-csf-trait", path: "contracts/traits/conxian-csf-trait.clar" },
  { name: "conxian-intent-trait", path: "contracts/traits/conxian-intent-trait.clar" },
  // Phase 2: Core Access & Protocol
  { name: "conxian-access", path: "contracts/core/conxian-access.clar" },
  { name: "conxian-protocol", path: "contracts/core/conxian-protocol.clar" },
  // Phase 3: Oracle
  { name: "oracle-aggregator", path: "contracts/oracle/oracle-aggregator.clar" },
  // Phase 4: Tokens
  { name: "cxd-token", path: "contracts/tokens/cxd-token.clar" },
  // Phase 5: BME Engine
  { name: "bme-engine", path: "contracts/core/bme-engine.clar" },
  // Phase 6: Treasury
  { name: "cxd-treasury", path: "contracts/treasury/cxd-treasury.clar" },
  // Phase 7: Security
  { name: "mev-protector", path: "contracts/security/mev-protector.clar" },
  { name: "enhanced-circuit-breaker", path: "contracts/security/enhanced-circuit-breaker.clar" },
  // Phase 8: DEX Core
  { name: "concentrated-liquidity-pool", path: "contracts/dex/concentrated-liquidity-pool.clar" },
  { name: "swap-router", path: "contracts/dex/swap-router.clar" },
  { name: "dex-factory", path: "contracts/dex/dex-factory.clar" },
  // Phase 9: Revenue
  { name: "revenue-distributor", path: "contracts/treasury/revenue-distributor.clar" },
  // Phase 10: Agents
  { name: "agent-risk", path: "contracts/agents/agent-risk.clar" },
  { name: "agent-treasury", path: "contracts/agents/agent-treasury.clar" },
  // Phase 11: Ops
  { name: "ops-engine", path: "contracts/core/ops-engine.clar" },
  // Phase 12: Gateway
  { name: "intent-solver-gateway", path: "contracts/gateway/intent-solver-gateway.clar" },
  { name: "revenue-automation", path: "contracts/revenue-automation.clar" },
];

async function getAccountNonce(address: string): Promise<number> {
  const headers: Record<string, string> = {};
  if (HIRO_API_KEY) headers["x-hiro-api-key"] = HIRO_API_KEY;
  
  const response = await fetch(`${CORE_API_URL}/v2/accounts/${address}?proof=0`, { headers });
  const data = await response.json() as any;
  return data.nonce || 0;
}

async function checkContractExists(address: string, contractName: string): Promise<boolean> {
  const headers: Record<string, string> = {};
  if (HIRO_API_KEY) headers["x-hiro-api-key"] = HIRO_API_KEY;
  
  const response = await fetch(`${CORE_API_URL}/v2/contracts/interface/${address}/${contractName}`, { headers });
  return response.status === 200;
}

async function deployContract(
  contractName: string, 
  contractPath: string, 
  nonce: number
): Promise<string | null> {
  const contractCode = readFileSync(join(process.cwd(), contractPath), "utf8");
  
  const txOptions = {
    contractName,
    codeBody: contractCode,
    senderKey: DEPLOYER_PRIVKEY,
    network,
    nonce: BigInt(nonce),
    anchorMode: 3, // AnchorMode.Any
    postConditionMode: 1, // PostConditionMode.Allow
    fee: BigInt(500000), // 0.5 STX - sufficient for large contracts
  };
  
  const tx = await makeContractDeploy(txOptions);
  
  console.log(`Broadcasting ${contractName} (nonce: ${nonce})...`);
  
  const broadcastResponse = await broadcastTransaction({ transaction: tx, network });
  
  if ("error" in broadcastResponse) {
    console.error(`  ✗ Error: ${broadcastResponse.error} - ${broadcastResponse.reason}`);
    return null;
  }
  
  console.log(`  ✓ Txid: ${broadcastResponse.txid}`);
  return broadcastResponse.txid;
}

async function main() {
  console.log("=== ConxianCSF Testnet Deployment ===");
  console.log(`Network: ${CORE_API_URL}`);
  console.log(`Deployer: ${process.env.SYSTEM_ADDRESS || "derived from key"}`);
  console.log("");
  
  // Get starting nonce
  const deployerAddress = process.env.SYSTEM_ADDRESS!;
  let nonce = await getAccountNonce(deployerAddress);
  console.log(`Starting nonce: ${nonce}\n`);
  
  const results: Record<string, string> = {};
  const failed: string[] = [];
  
  for (const contract of DEPLOYMENT_SEQUENCE) {
    // Check if already deployed
    const exists = await checkContractExists(deployerAddress, contract.name);
    if (exists) {
      console.log(`  ↩ ${contract.name} - already deployed, skipping`);
      continue;
    }
    
    const txid = await deployContract(contract.name, contract.path, nonce);
    
    if (txid) {
      results[contract.name] = txid;
      nonce++;
      // Small delay between transactions
      await new Promise(resolve => setTimeout(resolve, 500));
    } else {
      failed.push(contract.name);
      console.log(`  ⚠ Skipping ${contract.name} due to error`);
    }
  }
  
  console.log("\n=== Deployment Summary ===");
  console.log(`Deployed: ${Object.keys(results).length} contracts`);
  console.log(`Failed: ${failed.length} contracts`);
  
  if (failed.length > 0) {
    console.log("\nFailed contracts:");
    failed.forEach(name => console.log(`  - ${name}`));
  }
  
  if (Object.keys(results).length > 0) {
    console.log("\nDeployed transaction IDs:");
    Object.entries(results).forEach(([name, txid]) => {
      console.log(`  ${name}: https://explorer.hiro.so/txid/${txid}?chain=testnet`);
    });
  }
  
  console.log("\nDeployment complete!");
}

main().catch(console.error);
