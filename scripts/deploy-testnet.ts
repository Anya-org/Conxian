/**
* ConxianCSF Testnet Broadcast Helper
* Broadcasts contracts in dependency order; it never proves deployment.
*/
import "dotenv/config";
import {
  AddressVersion,
  broadcastTransaction,
  createAddress,
  makeContractDeploy,
  validateStacksAddress,
} from "@stacks/transactions";
import { STACKS_TESTNET } from "@stacks/network";
import { readFileSync } from "fs";
import { join } from "path";

const DEPLOYER_PRIVKEY = process.env.DEPLOYER_PRIVKEY!;
const CORE_API_URL = (process.env.CORE_API_URL || "https://api.testnet.hiro.so").replace(/\/+$/, "");
const HIRO_API_KEY = process.env.HIRO_API_KEY;
const SYSTEM_ADDRESS = process.env.SYSTEM_ADDRESS;
const REQUEST_TIMEOUT_MS = 15_000;
const JSON_OUTPUT = process.argv.includes("--json");

type BroadcastStatus = "broadcast-complete" | "broadcast-partial" | "broadcast-failed" | "broadcast-noop";

interface BroadcastResult {
  status: BroadcastStatus;
  verification: "pending";
  network: "testnet";
  deployer?: string;
  transactionIds: Record<string, string>;
  failedContracts: string[];
}

function humanLog(message: string): void {
  if (!JSON_OUTPUT) console.log(message);
}

function humanError(message: string): void {
  if (!JSON_OUTPUT) console.error(message);
}

function emitResult(result: BroadcastResult): void {
  if (JSON_OUTPUT) {
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } else {
    console.log(`Broadcast result: ${JSON.stringify(result)}`);
  }
}

function isCanonicalTestnetAddress(value: string | undefined): value is string {
  if (!value || !value.startsWith("ST") || !validateStacksAddress(value)) return false;
  try {
    const address = createAddress(value);
    return (
      (address.version === AddressVersion.TestnetSingleSig ||
        address.version === AddressVersion.TestnetMultiSig) &&
      address.hash160.length === 40
    );
  } catch {
    return false;
  }
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

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
  const response = await fetchWithTimeout(`${CORE_API_URL}/v2/accounts/${address}?proof=0`, {
    headers: apiHeaders,
  });
  if (!response.ok) {
    throw new Error("Hiro account lookup failed");
  }
  const data = await response.json() as { nonce?: unknown };
  if (typeof data.nonce !== "number" || !Number.isInteger(data.nonce) || data.nonce < 0) {
    throw new Error("Hiro account response omitted a valid nonce");
  }
  return data.nonce;
}

async function checkContractExists(address: string, contractName: string): Promise<boolean> {
  const response = await fetchWithTimeout(
    `${CORE_API_URL}/v2/contracts/interface/${address}/${contractName}`,
    { headers: apiHeaders },
  );
  if (response.status === 404) return false;
  if (!response.ok) {
    throw new Error("Hiro contract lookup failed");
  }
  return true;
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
  
  humanLog(`Broadcasting ${contractName} (nonce: ${nonce})...`);
  
  const broadcastResponse = await broadcastTransaction({ transaction: tx, network });
  
  if ("error" in broadcastResponse) {
    humanError(`  ✗ Broadcast rejected for ${contractName}`);
    return null;
  }
  
  humanLog(`  ✓ Txid: ${broadcastResponse.txid}`);
  return broadcastResponse.txid;
}

async function main() {
  if (!DEPLOYER_PRIVKEY || !isCanonicalTestnetAddress(SYSTEM_ADDRESS)) {
    throw new Error("testnet deployment configuration is incomplete or not canonical");
  }
  if (CORE_API_URL !== "https://api.testnet.hiro.so") {
    throw new Error("testnet broadcast helper requires the canonical Hiro testnet API URL");
  }

  humanLog("=== ConxianCSF Testnet Broadcast ===");
  humanLog(`Network: ${CORE_API_URL}`);
  humanLog(`Deployer: ${SYSTEM_ADDRESS}`);
  humanLog("");
  
  // Get starting nonce
  const deployerAddress = SYSTEM_ADDRESS;
  let nonce = await getAccountNonce(deployerAddress);
  humanLog(`Starting nonce: ${nonce}\n`);
  
  const results: Record<string, string> = {};
  const failed: string[] = [];
  
  for (const contract of DEPLOYMENT_SEQUENCE) {
    // Check if already deployed
    const exists = await checkContractExists(deployerAddress, contract.name);
    if (exists) {
      humanLog(`  ↩ ${contract.name} - already deployed, skipping`);
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
      humanError(`  ⚠ Skipping ${contract.name} due to broadcast error`);
    }
  }
  
  humanLog("\n=== Broadcast Summary ===");
  humanLog(`Broadcast: ${Object.keys(results).length} contracts`);
  humanLog(`Failed: ${failed.length} contracts`);
  
  if (failed.length > 0) {
    humanError("\nFailed contracts:");
    failed.forEach(name => humanError(`  - ${name}`));
  }
  
  if (Object.keys(results).length > 0) {
    humanLog("\nBroadcast transaction IDs:");
    Object.entries(results).forEach(([name, txid]) => {
      humanLog(`  ${name}: https://explorer.hiro.so/txid/${txid}?chain=testnet`);
    });
  }

  const result: BroadcastResult = {
    status:
      failed.length > 0
        ? Object.keys(results).length > 0
          ? "broadcast-partial"
          : "broadcast-failed"
        : Object.keys(results).length > 0
          ? "broadcast-complete"
          : "broadcast-noop",
    verification: "pending",
    network: "testnet",
    deployer: deployerAddress,
    transactionIds: results,
    failedContracts: failed,
  };
  emitResult(result);

  if (failed.length > 0) {
    humanError("No deployment is verified. Capture confirmed receipt evidence before reporting success.");
    process.exitCode = 1;
    return;
  }

  humanLog("\nBroadcast complete; verification remains pending.");
  humanLog("Run scripts/verify-deployment-evidence.ts with a confirmed evidence manifest before reporting success.");
  process.exitCode = 0;
}

main().catch(() => {
  emitResult({
    status: "broadcast-failed",
    verification: "pending",
    network: "testnet",
    transactionIds: {},
    failedContracts: [],
  });
  humanError("Deployment broadcast failed; no deployment is verified.");
  process.exitCode = 1;
});
